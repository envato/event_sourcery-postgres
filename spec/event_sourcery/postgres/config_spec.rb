# frozen_string_literal: true

RSpec.describe EventSourcery::Postgres::Config do
  subject(:config) { described_class.new }

  context 'when reading the event_store' do
    context 'and an event_store_database is set' do
      before do
        allow(db_connection).to receive(:extension).with(:pg_json)
        config.event_store_database = db_connection
      end

      it 'returns a EventSourcery::Postgres::EventStore' do
        expect(config.event_store).to be_instance_of(EventSourcery::Postgres::EventStore)
      end

      it 'loads pg_json extension on database' do
        expect(db_connection).to have_received(:extension).with(:pg_json)
      end
    end

    context 'and an event_store is set' do
      let(:event_store) { double(:event_store) }
      before do
        config.event_store = event_store
        config.event_store_database = nil
      end

      it 'returns the event_store' do
        expect(config.event_store).to eq(event_store)
      end
    end
  end

  context 'setting the projections database' do
    before do
      allow(db_connection).to receive(:extension).with(:pg_json)
      config.projections_database = db_connection
    end

    it 'sets the projections_database' do
      expect(config.projections_database).to eq db_connection
    end

    it 'sets the event_tracker' do
      expect(config.event_tracker).to be_instance_of(EventSourcery::Postgres::Tracker)
    end

    it 'loads pg_json extension on database' do
      expect(db_connection).to have_received(:extension).with(:pg_json)
    end
  end
end
