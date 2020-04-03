# Usage:
#
# ❯ bundle exec ruby script/bench_reading_events.rb
# Creating 10000 events
# Took 42.35533199999918 to create events
# Took 4.9821800000027 to read all events
# ^ results from running on a 2016 MacBook

require 'benchmark'
require 'securerandom'
require 'sequel'
require 'event_sourcery/postgres'

pg_uri = ENV.fetch('POSTGRESQL_URL', 'postgres://127.0.0.1:5432/').dup
pg_uri << 'event_sourcery_test'
pg_connection = Sequel.connect(pg_uri)

EventSourcery.configure do |config|
  config.postgres.event_store_database = pg_connection
  config.postgres.projections_database = pg_connection
  config.logger.level = :fatal
end

def create_events_schema(pg_connection)
  pg_connection.execute 'drop table if exists events'
  pg_connection.execute 'drop table if exists aggregates'
  EventSourcery::Postgres::Schema.create_event_store(db: pg_connection)
end

event_store = EventSourcery::Postgres.config.event_store

EVENT_TYPES = %i[
  item_added
  item_removed
  item_starred
].freeze

def new_event(uuid)
  EventSourcery::Event.new(type: EVENT_TYPES.sample,
                           aggregate_id: uuid,
                           body: { 'something' => 'simple' })
end

create_events_schema(pg_connection)

NUM_EVENTS = 10_000
puts "Creating #{NUM_EVENTS} events"
time = Benchmark.realtime do
  uuid = SecureRandom.uuid
  NUM_EVENTS.times { event_store.sink(new_event(uuid)) }
end
puts "Took #{time} to create events"

seen_events_count = 0
time = Benchmark.realtime do
  event_store.subscribe(from_id: 0, subscription_master: EventSourcery::EventStore::SignalHandlingSubscriptionMaster.new) do |events|
    seen_events_count += events.count
    throw :stop if seen_events_count >= NUM_EVENTS
  end
end
puts "Took #{time} to read all events"
