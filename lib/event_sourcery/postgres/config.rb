module EventSourcery
  module Postgres
    class Config
      attr_accessor :event_store_database,
                    :lock_table_to_guarantee_linear_sequence_id_growth,
                    :write_events_function_name,
                    :events_table_name,
                    :aggregates_table_name,
                    :callback_interval_if_no_new_events,
                    :auto_create_projector_tracker,
                    :event_tracker,
                    :projections_database,
                    :event_store,
                    :event_source,
                    :event_sink

      def initialize
        @lock_table_to_guarantee_linear_sequence_id_growth = true
        @write_events_function_name = 'writeEvents'
        @events_table_name = :events
        @aggregates_table_name = :aggregates
        @callback_interval_if_no_new_events = 10
        @event_store_database = nil
        @auto_create_projector_tracker = true
      end

      def event_store
        @event_store ||= EventStore.new(event_store_database)
      end

      def event_source
        @event_source ||= ::EventSourcery::EventStore::EventSource.new(event_store)
      end

      def event_sink
        @event_sink ||= ::EventSourcery::EventStore::EventSink.new(event_store)
      end

      def projections_database=(sequel_connection)
        @projections_database = sequel_connection
        @event_tracker = Postgres::Tracker.new(sequel_connection)
      end
    end
  end

  Config.class_eval do
    attr_reader :postgres

    def postgres
      @postgres ||= Postgres::Config.new
    end
  end
end
