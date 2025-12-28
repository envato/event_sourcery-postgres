# frozen_string_literal: true

module EventSourcery
  module Postgres
    module Schema
      module_function

      # This will create the event store tables and functions
      # (event, aggregates, tracker and create or update functions)
      # for the given Postgres database.
      # The default will be the one specified in the config.
      #
      # @param db the Postgres database to use
      def create_event_store(db: EventSourcery::Postgres.config.event_store_database,
                             events_table_name: EventSourcery::Postgres.config.events_table_name,
                             aggregates_table_name: EventSourcery::Postgres.config.aggregates_table_name,
                             write_events_function_name: EventSourcery::Postgres.config.write_events_function_name)
        create_events(db: db, table_name: events_table_name)
        create_aggregates(db: db, table_name: aggregates_table_name)
        create_or_update_functions(
          db: db,
          events_table_name: events_table_name,
          function_name: write_events_function_name,
          aggregates_table_name: aggregates_table_name
        )
      end

      # Create the events table. Needs the database and the table name.
      # The defaults will be whats specified in config.
      #
      # @param db the Postgres database to use
      # @param table_name the name of the events table
      def create_events(db: EventSourcery::Postgres.config.event_store_database,
                        table_name: EventSourcery::Postgres.config.events_table_name)
        db.run 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp"'
        db.create_table(table_name) do
          primary_key :id, type: :Bignum
          column :uuid,           :uuid,    null: false, default: Sequel.lit('uuid_generate_v4()')
          column :aggregate_id,   :uuid,    null: false
          column :type,           :varchar, null: false, size: 255
          column :body,           :json,    null: false
          column :version,        :bigint,  null: false
          column :correlation_id, :uuid
          column :causation_id,   :uuid
          column :created_at,     :'timestamp without time zone', null: false,
                                                                  default: Sequel.lit("(now() at time zone 'utc')")
          index %i[aggregate_id version], unique: true
          index :uuid, unique: true
          index :type
          index :correlation_id
          index :causation_id
          index :created_at
        end
      end

      # Create the aggregates table. Needs the database and the table name.
      # The defaults will be whats specified in config.
      #
      # @param db the Postgres database to use
      # @param table_name the name of the aggregates table
      def create_aggregates(db: EventSourcery::Postgres.config.event_store_database,
                            table_name: EventSourcery::Postgres.config.aggregates_table_name)
        db.create_table(table_name) do
          uuid :aggregate_id, primary_key: true
          column :version, :bigint, default: 1
        end
      end

      # Create the 'create or update' functions.
      # Needs the database, table name, function name and aggregates table name.
      # The defaults will be whats specified in config.
      #
      # @param db the Postgres database to use
      # @param function_name the name of the write events function
      # @param events_table_name the name of the events table
      # @param aggregates_table_name the name of the aggregates table
      def create_or_update_functions(db: EventSourcery::Postgres.config.event_store_database,
                                     function_name: EventSourcery::Postgres.config.write_events_function_name,
                                     events_table_name: EventSourcery::Postgres.config.events_table_name,
                                     aggregates_table_name: EventSourcery::Postgres.config.aggregates_table_name)
        db.run <<~SQL
          create or replace function #{function_name}(_aggregateId uuid,
                                                      _eventTypes varchar[],
                                                      _expectedVersion int,
                                                      _bodies json[],
                                                      _createdAtTimes timestamp without time zone[],
                                                      _eventUUIDs uuid[],
                                                      _correlationIds uuid[],
                                                      _causationIds uuid[],
                                                      _lockTable boolean) returns void as $$
          declare
          currentVersion int;
          body json;
          eventVersion int;
          eventId text;
          index int;
          newVersion int;
          numEvents int;
          createdAt timestamp without time zone;
          begin
          numEvents := array_length(_bodies, 1);
          select version into currentVersion from #{aggregates_table_name} where aggregate_id = _aggregateId;
          if not found then
            -- when we have no existing version for this aggregate
            if _expectedVersion = 0 or _expectedVersion is null then
              -- set the version to 1 if expected version is null or 0
              insert into #{aggregates_table_name}(aggregate_id, version) values(_aggregateId, numEvents);
              currentVersion := 0;
            else
              raise 'Concurrency conflict. Current version: 0, expected version: %', _expectedVersion;
            end if;
          else
            if _expectedVersion is null then
              -- automatically increment the version
              update #{aggregates_table_name} set version = version + numEvents where aggregate_id = _aggregateId returning version into newVersion;
              currentVersion := newVersion - numEvents;
            else
              -- increment the version if it's at our expected version
              update #{aggregates_table_name} set version = version + numEvents where aggregate_id = _aggregateId and version = _expectedVersion;
              if not found then
                -- version was not at expected_version, raise an error.
                -- currentVersion may not equal what it did in the database when the
                -- above update statement is executed (it may have been incremented by another
                -- process)
                raise 'Concurrency conflict. Last known current version: %, expected version: %', currentVersion, _expectedVersion;
              end if;
            end if;
          end if;
          index := 1;
          eventVersion := currentVersion + 1;
          if _lockTable then
              -- Ensure this transaction is the only one writing events to guarantee
              -- linear growth of sequence IDs.
              -- Any value that won't conflict with other advisory locks will work.
              -- The Postgres tracker currently obtains an advisory lock using it's
              -- integer row ID, so values 1 to the number of ESP's in the system would
              -- be taken if the tracker is running in the same database as your
              -- projections.
              perform pg_advisory_xact_lock(-1);
          end if;
          foreach body IN ARRAY(_bodies)
          loop
            if _createdAtTimes[index] is not null then
              createdAt := _createdAtTimes[index];
            else
              createdAt := now() at time zone 'utc';
            end if;

            insert into #{events_table_name}
              (uuid, aggregate_id, type, body, version, correlation_id, causation_id, created_at)
            values
              (
                _eventUUIDs[index],
                _aggregateId,
                _eventTypes[index],
                body,
                eventVersion,
                _correlationIds[index],
                _causationIds[index],
                createdAt
              )
            returning id into eventId;

            eventVersion := eventVersion + 1;
            index := index + 1;
          end loop;
          perform pg_notify('new_event', eventId);
          end;
          $$ language plpgsql;
        SQL
      end

      # Create the projector tracker table. Needs the database and the table name.
      # The defaults will be whats specified in config.
      #
      # @param db the Postgres database to use
      # @param table_name the name of the aggregates table
      def create_projector_tracker(db: EventSourcery::Postgres.config.projections_database,
                                   table_name: EventSourcery::Postgres.config.tracker_table_name)
        db.create_table(table_name) do
          primary_key :id, type: :Bignum
          column :name, 'varchar(255) not null'
          column :last_processed_event_id, 'bigint not null default 0'
          index :name, unique: true
        end
      end
    end
  end
end
