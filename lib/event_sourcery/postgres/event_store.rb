module EventSourcery
  module Postgres
    class EventStore
      include EventSourcery::EventStore::EachByRange

      def initialize(db_connection,
                     events_table_name: EventSourcery::Postgres.config.events_table_name,
                     lock_table: EventSourcery::Postgres.config.lock_table_to_guarantee_linear_sequence_id_growth,
                     write_events_function_name: EventSourcery::Postgres.config.write_events_function_name,
                     event_builder: EventSourcery.config.event_builder,
                     on_events_recorded: EventSourcery::Postgres.config.on_events_recorded)
        @db_connection = db_connection
        @events_table_name = events_table_name
        @write_events_function_name = write_events_function_name
        @lock_table = lock_table
        @event_builder = event_builder
        @on_events_recorded = on_events_recorded
      end

      # Like water flowing into a sink eventually it will go down the drain
      # into the goodness of the plumbing system.
      # So to will the given events you put in this 'sink'. Except the plumbing
      # system is the data base events table.
      # This can raise db connection errors.
      #
      # @param event_or_events the event or events to save
      # @param expected_version the version to save with the event, default nil
      #
      # @raise [DatabaseError] if something goes wrong with the database
      # @raise [ConcurrencyError] if there was a concurrency conflict
      def sink(event_or_events, expected_version: nil)
        events = Array(event_or_events)
        aggregate_ids = events.map(&:aggregate_id).uniq
        raise AtomicWriteToMultipleAggregatesNotSupported unless aggregate_ids.count == 1
        sql = write_events_sql(aggregate_ids.first, events, expected_version)
        @db_connection.run(sql)
        log_events_saved(events)
        on_events_recorded.call(events)
        true
      rescue Sequel::DatabaseError => e
        if e.message =~ /Concurrency conflict/
          raise ConcurrencyError, "expected version was not #{expected_version}. Error: #{e.message}"
        else
          raise
        end
      end

      # Get the next set of events from the given event id. You can
      # specify event types and a limit.
      # Default limit is 1000 and the default event types will be all.
      #
      # @param id the event id to get next events from
      # @param event_types the event types to filter, default nil = all
      # @param limit the limit to the results, default 1000
      #
      # @return [Array] array of found events
      def get_next_from(id, event_types: nil, limit: 1000)
        query = events_table.
          order(:id).
          where(Sequel.lit('id >= ?', id)).
          limit(limit)
        query = query.where(type: event_types) if event_types
        query.map { |event_row| build_event(**event_row) }
      end

      # Get last event id for a given event types.
      #
      # @param event_types the type of event(s) to filter
      #
      # @return the latest event id
      def latest_event_id(event_types: nil)
        latest_event = events_table
        latest_event = latest_event.where(type: event_types) if event_types
        latest_event = latest_event.order(:id).last
        if latest_event
          latest_event[:id]
        else
          0
        end
      end

      # Get the events for a given aggregate id.
      #
      # @param aggregate_id the aggregate id to filter for
      #
      # @return [Array] of found events
      def get_events_for_aggregate_id(aggregate_id)
        events_table.where(aggregate_id: aggregate_id.to_str).order(:version).map do |event_hash|
          build_event(**event_hash)
        end
      end

      # Subscribe to events.
      #
      # @param from_id subscribe from a starting event id. default will be from the start.
      # @param event_types the event_types to subscribe to, default all.
      # @param after_listen the after listen call back block. default nil.
      # @param subscription_master the subscription master block
      def subscribe(from_id:, event_types: nil, after_listen: nil, subscription_master:, &block)
        poll_waiter = OptimisedEventPollWaiter.new(db_connection: @db_connection, after_listen: after_listen)
        args = {
          poll_waiter: poll_waiter,
          event_store: self,
          from_event_id: from_id,
          event_types: event_types,
          events_table_name: @events_table_name,
          subscription_master: subscription_master,
          on_new_events: block
        }
        EventSourcery::EventStore::Subscription.new(**args).tap(&:start)
      end

      private

      attr_reader :on_events_recorded

      def events_table
        @db_connection[@events_table_name]
      end

      def build_event(data)
        @event_builder.build(**data)
      end

      def write_events_sql(aggregate_id, events, expected_version)
        bodies = sql_literal_array(events, 'json', &:body)
        types = sql_literal_array(events, 'varchar', &:type)
        created_ats = sql_literal_array(events, 'timestamp without time zone', &:created_at)
        event_uuids = sql_literal_array(events, 'uuid', &:uuid)
        correlation_ids = sql_literal_array(events, 'uuid', &:correlation_id)
        causation_ids = sql_literal_array(events, 'uuid', &:causation_id)
        <<-SQL
          select #{@write_events_function_name}(
            #{sql_literal(aggregate_id.to_str, 'uuid')},
            #{types},
            #{sql_literal(expected_version, 'int')},
            #{bodies},
            #{created_ats},
            #{event_uuids},
            #{correlation_ids},
            #{causation_ids},
            #{sql_literal(@lock_table, 'boolean')}
          );
        SQL
      end

      def sql_literal_array(events, type, &block)
        sql_array = events.map do |event|
          to_sql_literal(block.call(event))
        end.join(', ')
        "array[#{sql_array}]::#{type}[]"
      end

      def sql_literal(value, type)
        "#{to_sql_literal(value)}::#{type}"
      end

      def to_sql_literal(value)
        return 'null' unless value
        wrapped_value = if Time === value
                          value.iso8601(6)
                        elsif Hash === value
                          Sequel.pg_json(value)
                        else
                          value
                        end
        @db_connection.literal(wrapped_value)
      end

      def log_events_saved(events)
        events.each do |event|
          EventSourcery.logger.debug { "Saved event: #{event.inspect}" }
        end
      end
    end
  end
end
