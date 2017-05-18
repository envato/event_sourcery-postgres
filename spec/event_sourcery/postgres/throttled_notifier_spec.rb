RSpec.describe EventSourcery::Postgres::ThrottledNotifier do
  subject(:throttled_notifier) { described_class.new(connection, seconds_between_calls) }
  let(:processor_name) { 'pizza' }
  let(:seconds_between_calls) { 0.05 }

  before do
    allow(connection).to receive(:notify)
  end

  describe '#notify' do
    it 'notifies immediately on the first call' do
      throttled_notifier.notify(processor_name)
      expect(connection).to have_received(:notify).with('processor_update_pizza')
    end

    it 'does not allow subsequent notifications until the time period has passed' do
      3.times { throttled_notifier.notify(processor_name) }
      expect(connection).to have_received(:notify).with('processor_update_pizza').exactly(1).times

      sleep seconds_between_calls * 1.1
      expect(connection).to have_received(:notify).with('processor_update_pizza').exactly(2).times
      throttled_notifier.notify(processor_name)
      expect(connection).to have_received(:notify).with('processor_update_pizza').exactly(2).times

      sleep seconds_between_calls * 1.1
      expect(connection).to have_received(:notify).with('processor_update_pizza').exactly(3).times

      sleep seconds_between_calls * 1.1
      expect(connection).to have_received(:notify).with('processor_update_pizza').exactly(3).times
    end

    it 'throttles different processors independently' do
      throttled_notifier.notify(processor_name)
      throttled_notifier.notify('gelato')
      expect(connection).to have_received(:notify).with('processor_update_pizza')
      expect(connection).to have_received(:notify).with('processor_update_gelato')
    end
  end
end
