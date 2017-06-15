RSpec.describe EventSourcery::Postgres::Projector do
  let(:projector_class) {
    Class.new do
      include EventSourcery::Postgres::Projector
      processor_name 'test_processor'

      table :profiles do
        column :user_uuid, 'UUID NOT NULL'
        column :terms_accepted, 'BOOLEAN DEFAULT FALSE'
      end

      process TermsAccepted do |event|
        @processed_event = event
        table.insert(user_uuid: event.aggregate_id,
                     terms_accepted: true)
      end

      attr_reader :processed_event
    end
  }
  let(:projector_name) { 'my_projector' }
  let(:tracker) { EventSourcery::Postgres::Tracker.new(pg_connection) }
  let(:events) { [] }

  def new_projector(&block)
    Class.new do
      include EventSourcery::Postgres::Projector
      processor_name 'test_processor'

      table :profiles do
        column :user_uuid, 'UUID NOT NULL'
        column :terms_accepted, 'BOOLEAN DEFAULT FALSE'
      end

      class_eval(&block) if block_given?

      attr_reader :processed_event
    end.new(tracker: tracker, db_connection: pg_connection)
  end

  subject(:projector) {
    projector_class.new(
      tracker: tracker,
      db_connection: connection
    )
  }
  let(:aggregate_id) { SecureRandom.uuid }

  after { release_advisory_locks }

  describe '.new' do
    let(:projections_database) { double }
    let(:event_tracker) { double }

    before do
      allow(EventSourcery::Postgres::Tracker).to receive(:new).with(projections_database).and_return(event_tracker)

      EventSourcery::Postgres.configure do |config|
        config.projections_database = projections_database
      end
    end

    subject(:projector) { projector_class.new }

    it 'uses the configured projections database by default' do
      expect(projector.instance_variable_get('@db_connection')).to eq projections_database
    end

    it 'uses the inferred event tracker database by default' do
      expect(projector.instance_variable_get('@tracker')).to eq event_tracker
    end
  end

  describe '.projector_name' do
    it 'delegates to processor_name' do
      expect(projector_class.projector_name).to eq 'test_processor'
    end
  end

  describe '#project' do
    let(:event) { TermsAccepted.new }

    it "processes events via project method" do
      projector = new_projector do
        def project(event)
          @processed_event = event
        end
      end
      projector.project(event)
      expect(projector.processed_event).to eq(event)
    end

    it 'processes events with custom classes' do
      projector = new_projector do
        project ItemAdded do |event|
          @processed_event = event
        end
      end
      event = ItemAdded.new
      projector.project(event)
      expect(projector.processed_event).to eq(event)
    end
  end

  describe '#process' do
    before { projector.reset }

    let(:event) { TermsAccepted.new(body: {}, aggregate_id: aggregate_id, id: 1) }

    it "processes events it's interested in" do
      projector.process(event)
      expect(projector.processed_event).to eq(event)
    end
  end

  describe '#subscribe_to' do
    let(:event_store) { double(:event_store) }
    let(:events) { [new_event(id: 1), new_event(id: 2)] }
    let(:subscription_master) { spy(EventSourcery::EventStore::SignalHandlingSubscriptionMaster) }
    let(:projector_class) {
      Class.new do
        include EventSourcery::Postgres::Projector
        processor_name 'test_processor'

        table :profiles do
          column :user_uuid, 'UUID NOT NULL'
          column :terms_accepted, 'BOOLEAN DEFAULT FALSE'
        end

        attr_accessor :raise_error

        def process(event)
          table.insert(user_uuid: event.aggregate_id,
                       terms_accepted: true)
          raise 'boo' if raise_error
        end
      end
    }

    before do
      allow(event_store).to receive(:subscribe).and_yield(events).once
      projector.reset
    end

    it 'marks the safe shutdown points' do
      projector.subscribe_to(event_store, subscription_master: subscription_master)
      expect(subscription_master).to have_received(:shutdown_if_requested).twice
    end

    context 'when an error occurs processing the event' do

      it "rolls back the projected changes" do
        projector.raise_error = true
        projector.subscribe_to(event_store, subscription_master: subscription_master) rescue nil
        expect(connection[:profiles].count).to eq 0
      end
    end

    context 'when an error occurs tracking the position' do
      before do
        projector.raise_error = false
        allow(tracker).to receive(:processed_event).and_raise(StandardError)
      end

      it "rolls back the projected changes" do
        projector.subscribe_to(event_store, subscription_master: subscription_master) rescue nil
        expect(connection[:profiles].count).to eq 0
      end
    end
  end
end
