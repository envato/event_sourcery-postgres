module EventSourcery
  module Postgres
    module Reactor
      UndeclaredEventEmissionError = Class.new(StandardError)

      def self.included(base)
        base.include(EventProcessing::EventStreamProcessor)
        base.extend(ClassMethods)
        base.prepend(TableOwner)
        base.include(InstanceMethods)
      end

      module ClassMethods
        def emits_events(*event_types)
          @emits_event_types = event_types
        end

        def emit_events
          @emits_event_types ||= []
        end

        def emits_events?
          !emit_events.empty?
        end

        def emits_event?(event_type)
          emit_events.include?(event_type)
        end
      end

      module InstanceMethods
        def initialize(tracker: EventSourcery::Postgres.config.event_tracker,
                       db_connection: EventSourcery::Postgres.config.projections_database,
                       event_source: EventSourcery::Postgres.config.event_source,
                       event_sink: EventSourcery::Postgres.config.event_sink)
          @tracker = tracker
          @event_source = event_source
          @event_sink = event_sink
          @db_connection = db_connection
          if self.class.emits_events?
            if event_sink.nil? || event_source.nil?
              raise ArgumentError, 'An event sink and source is required for processors that emit events'
            end
          end
        end
      end

      private

      attr_reader :event_sink, :event_source

      def emit_event(event_or_hash, &block)
        event = if Event === event_or_hash
                  event_or_hash
                else
                  Event.new(event_or_hash)
                end
        raise UndeclaredEventEmissionError unless self.class.emits_event?(event.class)
        event = event.with(causation_id: _event.uuid, correlation_id: _event.correlation_id)
        invoke_action_and_emit_event(event, block)
        EventSourcery.logger.debug { "[#{self.processor_name}] Emitted event: #{event.inspect}" }
      end

      def invoke_action_and_emit_event(event, action)
        action.call(event.body) if action
        event_sink.sink(event)
      end
    end
  end
end
