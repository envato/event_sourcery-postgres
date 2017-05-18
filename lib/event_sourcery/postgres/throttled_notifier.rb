module EventSourcery
  module Postgres
    class ThrottledNotifier
      def initialize(connection, seconds_between_calls = 0.1)
        @connection = connection
        @seconds_between_calls = seconds_between_calls
        @throttled = {}
        @notify_after_throttle = {}
      end

      def notify(processor_name)
        if throttled[processor_name]
          notify_after_throttle[processor_name] = true
        else
          notify_unthrottled(processor_name)
          throttled[processor_name] = true
          unthrottle_after_time_period(processor_name)
        end
      end

      private

      attr_reader :connection, :seconds_between_calls, :throttled, :notify_after_throttle

      def notify_unthrottled(processor_name)
        connection.notify("processor_update_#{processor_name}")
      end

      def unthrottle_after_time_period(processor_name)
        Thread.new do
          sleep seconds_between_calls

          throttled[processor_name] = false

          if notify_after_throttle[processor_name]
            notify_after_throttle[processor_name] = false
            notify(processor_name)
          end
        end
      end
    end
  end
end
