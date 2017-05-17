require 'sequel'

Sequel.extension :pg_json
Sequel.default_timezone = :utc

require 'event_sourcery'
require 'event_sourcery/postgres/version'
require 'event_sourcery/postgres/config'
require 'event_sourcery/postgres/queue_with_interval_callback'
require 'event_sourcery/postgres/schema'
require 'event_sourcery/postgres/optimised_event_poll_waiter'
require 'event_sourcery/postgres/event_store'
require 'event_sourcery/postgres/table_owner'
require 'event_sourcery/postgres/projector'
require 'event_sourcery/postgres/reactor'
require 'event_sourcery/postgres/tracker'

module EventSourcery
  module Postgres
    def self.configure
      yield config
    end

    def self.config
      @config ||= Config.new
    end
  end
end
