# frozen_string_literal: true

module EventSourcery
  module Postgres
    # Optimise poll interval with Postgres listen/notify
    class OptimisedEventPollWaiter
      ListenThreadDied = Class.new(StandardError)

      def initialize(db_connection:, timeout: 30, after_listen: proc {})
        @db_connection = db_connection
        @timeout = timeout
        @events_queue = QueueWithIntervalCallback.new
        @after_listen = after_listen
      end

      def poll(after_listen: proc {}, &block)
        @events_queue.callback = proc do
          ensure_listen_thread_alive!
          block.call
        end
        start_async(after_listen: after_listen)
        catch(:stop) do
          block.call
          loop do
            ensure_listen_thread_alive!
            wait_for_new_event_to_appear
            clear_new_event_queue
            block.call
          end
        end
      ensure
        shutdown!
      end

      private

      def shutdown!
        @listen_thread.kill if @listen_thread.alive?
      end

      def ensure_listen_thread_alive!
        raise ListenThreadDied unless @listen_thread.alive?
      end

      def wait_for_new_event_to_appear
        @events_queue.pop
      end

      def clear_new_event_queue
        @events_queue.clear
      end

      def start_async(after_listen: nil)
        after_listen_callback = if after_listen
                                  proc do
                                    after_listen.call
                                    @after_listen&.call
                                  end
                                else
                                  @after_listen
                                end
        @listen_thread = Thread.new do
          listen_for_new_events(loop: true,
                                after_listen: after_listen_callback,
                                timeout: @timeout)
        end
      end

      def listen_for_new_events(loop: true, after_listen: nil, timeout: 30)
        @db_connection.listen('new_event',
                              loop: loop,
                              after_listen: after_listen,
                              timeout: timeout) do |_channel, _pid, _payload|
          @events_queue.push(:new_event_arrived) if @events_queue.empty?
        end
      end
    end
  end
end
