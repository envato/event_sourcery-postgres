# frozen_string_literal: true

module EventSourcery
  module Postgres
    # Mixin providing reactor capabilities for processing events and emitting new events in response.
    module Reactor
      UndeclaredEventEmissionError = Class.new(StandardError)

      def self.included(base)
        base.include(EventProcessing::EventStreamProcessor)
        base.extend(ClassMethods)
        base.prepend(TableOwner)
        base.include(InstanceMethods)
      end

      # Class methods for declaring and querying emitted event types.
      module ClassMethods
        # Assign the types of events this reactor can emit.
        #
        # @param event_types the types of events this reactor can emit
        def emits_events(*event_types)
          @emits_event_types = event_types
        end

        # @return [Array] an array of the types of events this reactor can emit
        def emit_events
          @emits_event_types ||= [] # rubocop:disable Naming/MemoizedInstanceVariableName
        end

        # This will tell you if this reactor emits any type of event.
        #
        # @return [true, false] true if this emits events, false if not
        def emits_events?
          !emit_events.empty?
        end

        # Will check if this reactor emits the given type of event.
        #
        # @param event_type the event type to check
        # @return [true, false] true if it does emit the given event false if not
        def emits_event?(event_type)
          emit_events.include?(event_type)
        end
      end

      # Instance methods for reactor initialisation and event emission.
      module InstanceMethods
        def initialize(tracker: EventSourcery::Postgres.config.event_tracker,
                       db_connection: EventSourcery::Postgres.config.projections_database,
                       event_source: EventSourcery::Postgres.config.event_source,
                       event_sink: EventSourcery::Postgres.config.event_sink)
          @tracker = tracker
          @event_source = event_source
          @event_sink = event_sink
          @db_connection = db_connection
          return unless self.class.emits_events?
          return unless event_sink.nil? || event_source.nil?

          raise ArgumentError, 'An event sink and source is required for processors that emit events'
        end
      end

      private

      attr_reader :event_sink, :event_source

      def emit_event(event_or_hash, &block)
        event = if event_or_hash.is_a?(Event)
                  event_or_hash
                else
                  Event.new(event_or_hash)
                end
        raise UndeclaredEventEmissionError unless self.class.emits_event?(event.class)

        event = event.with(causation_id: _event.uuid, correlation_id: _event.correlation_id)
        invoke_action_and_emit_event(event, block)
        EventSourcery.logger.debug { "[#{processor_name}] Emitted event: #{event.inspect}" }
      end

      def invoke_action_and_emit_event(event, action)
        action&.call(event.body)
        event_sink.sink(event)
      end
    end
  end
end
