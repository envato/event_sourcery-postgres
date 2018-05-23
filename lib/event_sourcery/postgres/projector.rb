module EventSourcery
  module Postgres
    module Projector
      def self.included(base)
        base.include(EventProcessing::EventStreamProcessor)
        base.prepend(TableOwner)
        base.include(InstanceMethods)
        base.class_eval do
          alias_method :project, :process

          class << self
            alias_method :project, :process
            alias_method :projector_name, :processor_name
          end
        end
      end

      module InstanceMethods
        def initialize(tracker: EventSourcery::Postgres.config.event_tracker,
                       db_connection: EventSourcery::Postgres.config.projections_database,
                       transaction_size: EventSourcery::Postgres.config.projector_transaction_size)
          @tracker = tracker
          @db_connection = db_connection
          @transaction_size = transaction_size
        end

        private

        attr_reader :transaction_size

        def process_events(events, subscription_master)
          events.each_slice(transaction_size) do |slice_of_events|
            subscription_master.shutdown_if_requested

            db_connection.transaction do
              slice_of_events.each do |event|
                process(event)
                EventSourcery.logger.debug { "[#{processor_name}] Processed event: #{event.inspect}" }
              end
              tracker.processed_event(processor_name, slice_of_events.last.id)
            end
          end

          EventSourcery.logger.info { "[#{processor_name}] Processed up to event id: #{events.last.id}" }
        end
      end
    end
  end
end
