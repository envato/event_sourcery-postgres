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
            alias_method :projects_events, :processes_events
            alias_method :projector_name, :processor_name
          end
        end
      end

      module InstanceMethods
        def initialize(tracker: EventSourcery::Postgres.config.event_tracker,
                       db_connection: EventSourcery::Postgres.config.projections_database)
          @tracker = tracker
          @db_connection = db_connection
        end

        private

        def process_events(events, subscription_master)
          events.each do |event|
            subscription_master.shutdown_if_requested
            db_connection.transaction do
              process(event)
              tracker.processed_event(processor_name, event.id)
            end
            EventSourcery.logger.debug { "[#{processor_name}] Processed event: #{event.inspect}" }
          end
          EventSourcery.logger.info { "[#{processor_name}] Processed up to event id: #{events.last.id}" }
        end
      end
    end
  end
end
