module DBHelpers
  extend self

  def pg_connection
    $connection ||= new_connection
  end

  # TODO: switch references to connection to use pg_connection instead
  def connection
    @connection ||= pg_connection
  end

  module_function def new_connection
    Sequel.connect("#{postgres_url}event_sourcery_test")
  end

  module_function def postgres_url
    ENV.fetch('BOXEN_POSTGRESQL_URL', 'postgres://127.0.0.1:5432/')
  end

  def reset_database
    connection.execute('truncate table aggregates')
    %w(events events_without_optimistic_locking).each do |_|
      connection.execute('truncate table events')
      connection.execute('alter sequence events_id_seq restart with 1')
    end
  end

  def recreate_database
    pg_connection.execute('drop table if exists events')
    pg_connection.execute('drop table if exists aggregates')
    pg_connection.execute('drop table if exists projector_tracker')
    EventSourcery::Postgres::Schema.create_event_store(db: pg_connection)
    EventSourcery::Postgres::Schema.create_projector_tracker(db: pg_connection)
  end

  def release_advisory_locks(connection=pg_connection)
    connection.fetch('SELECT pg_advisory_unlock_all();').to_a
  end
end

RSpec.configure do |config|
  config.include(DBHelpers)
  config.before(:suite) { DBHelpers.recreate_database }
  config.before(:example) { DBHelpers.reset_database }
end
