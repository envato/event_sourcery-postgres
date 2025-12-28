module EventSourcery
  module Postgres
    # This will set up a persisted event id tracker for processors.
    class Tracker
      def initialize(db_connection = EventSourcery::Postgres.config.projections_database,
                     table_name: EventSourcery::Postgres.config.tracker_table_name,
                     obtain_processor_lock: true)
        @db_connection = db_connection
        @table_name = table_name.to_sym
        @obtain_processor_lock = obtain_processor_lock
      end

      # Set up the given processor.
      # This will create the projector tracker table if it does not exist.
      # If given a processor_name it will then attempt to get a lock on the db.
      #
      # @param processor_name the name of the processor
      def setup(processor_name = nil)
        create_table_if_not_exists if EventSourcery::Postgres.config.auto_create_projector_tracker

        raise UnableToLockProcessorError, 'Projector tracker table does not exist' unless tracker_table_exists?

        return unless processor_name

        create_track_entry_if_not_exists(processor_name)
        return unless @obtain_processor_lock

        obtain_global_lock_on_processor(processor_name)
      end

      # This will updated the tracker table to the given event id value
      # for the given processor name.
      #
      # @param processor_name the name of the processor to update
      # @param event_id the event id number to update to
      def processed_event(processor_name, event_id)
        table
          .where(name: processor_name.to_s)
          .update(last_processed_event_id: event_id)
        true
      end

      # This allows you to process an event and update the tracker table in
      # a single transaction. Will yield the given block first then update the
      # the tracker table to the give event id for the given processor name.
      #
      # @param processor_name the name of the processor to update
      # @param event_id the event id number to update to
      def processing_event(processor_name, event_id)
        @db_connection.transaction do
          yield
          processed_event(processor_name, event_id)
        end
      end

      # This will reset the tracker to the start (0) for the given processor name.
      #
      # @param processor_name the name of the processor to reset to 0
      def reset_last_processed_event_id(processor_name)
        table.where(name: processor_name.to_s).update(last_processed_event_id: 0)
      end

      # This will return the last processed event id for the given processor name.
      #
      # @param processor_name the name of the processor you want to look up
      # @return [Int, nil] the value of the last event_id processed
      def last_processed_event_id(processor_name)
        track_entry = table.where(name: processor_name.to_s).first
        track_entry[:last_processed_event_id] if track_entry
      end

      # Will return an array of all known tracked processors.
      #
      # @return [Array] array of all known tracked processors
      def tracked_processors
        table.select_map(:name)
      end

      private

      def obtain_global_lock_on_processor(processor_name)
        lock_obtained = @db_connection.fetch("select pg_try_advisory_lock(#{@track_entry_id})")
                                      .to_a.first[:pg_try_advisory_lock]
        return unless lock_obtained == false

        raise UnableToLockProcessorError, "Unable to get a lock on #{processor_name} #{@track_entry_id}"
      end

      def create_table_if_not_exists
        return if tracker_table_exists?

        EventSourcery.logger.info { "Projector tracker missing - attempting to create 'projector_tracker' table" }
        EventSourcery::Postgres::Schema.create_projector_tracker(db: @db_connection, table_name: @table_name)
      end

      def create_track_entry_if_not_exists(processor_name)
        track_entry = table.where(name: processor_name.to_s).first
        @track_entry_id = if track_entry
                            track_entry[:id]
                          else
                            table.insert(name: processor_name.to_s, last_processed_event_id: 0)
                          end
      end

      def table
        @db_connection[@table_name]
      end

      def tracker_table_exists?
        @db_connection.table_exists?(@table_name)
      end
    end
  end
end
