module DBHelpers
  extend self

  def db_connection
    $db_connection ||= new_db_connection
  end

  module_function def new_db_connection
    Sequel.connect("#{postgres_url}event_sourcery_test").extension(:pg_json)
  end

  module_function def postgres_url
    ENV.fetch('POSTGRESQL_URL', 'postgres://127.0.0.1:5432/')
  end

  def reset_database
    db_connection.execute('truncate table aggregates')
    %w(events events_without_optimistic_locking).each do |_|
      db_connection.execute('truncate table events')
      db_connection.execute('alter sequence events_id_seq restart with 1')
    end
  end

  def recreate_database
    db_connection.execute('drop table if exists events')
    db_connection.execute('drop table if exists aggregates')
    db_connection.execute('drop table if exists projector_tracker')
    EventSourcery::Postgres::Schema.create_event_store(db: db_connection)
    EventSourcery::Postgres::Schema.create_projector_tracker(db: db_connection)
  end

  def release_advisory_locks(connection = db_connection)
    connection.fetch('SELECT pg_advisory_unlock_all();').to_a
  end
end

RSpec.configure do |config|
  config.include(DBHelpers)
  config.before(:suite) { DBHelpers.recreate_database }
  config.before(:example) { DBHelpers.reset_database }
end
