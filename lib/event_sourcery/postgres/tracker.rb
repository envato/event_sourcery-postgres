module EventSourcery
  module Postgres
    class Tracker
      def initialize(connection = EventSourcery::Postgres.config.projections_database,
                     table_name: EventSourcery::Postgres.config.tracker_table_name,
                     obtain_processor_lock: true)
        @connection = connection
        @table_name = table_name
        @obtain_processor_lock = obtain_processor_lock
      end

      def setup(processor_name = nil)
        create_table_if_not_exists if EventSourcery::Postgres.config.auto_create_projector_tracker

        unless tracker_table_exists?
          raise UnableToLockProcessorError, 'Projector tracker table does not exist'
        end

        if processor_name
          create_track_entry_if_not_exists(processor_name)
          obtain_global_lock_on_processor(processor_name) if @obtain_processor_lock
        end
      end

      def processed_event(processor_name, event_id)
        table.where(name: processor_name.to_s).update(last_processed_event_id: event_id)
        true
      end

      def processing_event(processor_name, event_id)
        @connection.transaction do
          yield
          processed_event(processor_name, event_id)
        end
      end

      def reset_last_processed_event_id(processor_name)
        table.where(name: processor_name.to_s).update(last_processed_event_id: 0)
      end

      def last_processed_event_id(processor_name)
        if track_entry = table.where(name: processor_name.to_s).first
          track_entry[:last_processed_event_id]
        end
      end

      def tracked_processors
        table.select_map(:name)
      end

      private

      def obtained_global_lock?(lock_id)
        @connection.fetch("select pg_try_advisory_lock(#{lock_id})").to_a.first[:pg_try_advisory_lock]
      end

      def release_global_lock(lock_id)
        @connection.execute("select pg_advisory_unlock(#{lock_id});")
      end

      def obtain_global_lock_on_processor(processor_name)
        unless obtained_global_lock?(@track_entry_id)
          raise UnableToLockProcessorError, "Unable to get a lock on #{processor_name} #{@track_entry_id}"
        end
      end

      def exclusive(lock_id=1, &block)
        if obtained_global_lock?(lock_id)
          begin
            yield
          ensure
            release_global_lock(lock_id)
          end
        end
      end

      def create_table_if_not_exists
        attempt = 1
        while !tracker_table_exists? && attempt < 5 do
          exclusive do
            EventSourcery.logger.info { "Projector tracker missing - attempting to create '#{@table_name}' table" }
            EventSourcery::Postgres::Schema.create_projector_tracker(db: @connection, table_name: @table_name)
          end
          attempt += 1
        end
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
        @connection[@table_name]
      end

      def tracker_table_exists?
        @connection.table_exists?(@table_name)
      end
    end
  end
end