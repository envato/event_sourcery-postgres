# frozen_string_literal: true

module EventSourcery
  module Postgres
    # Mixin providing table management capabilities for projectors and reactors.
    module TableOwner
      DefaultTableError = Class.new(StandardError)
      NoSuchTableError = Class.new(StandardError)

      def self.prepended(base)
        base.extend(ClassMethods)
      end

      # Class methods for defining and managing database tables.
      module ClassMethods
        # Hash of the tables and their corresponding blocks.
        #
        # @return [Hash] hash keyed by table names and block values
        def tables
          @tables ||= {}
        end

        # For the given table name assign to give block as the value.
        #
        # @param name the name of the table
        # @param block the block of code to assign for the table
        def table(name, &block)
          tables[name] = block
        end
      end

      # Create each table.
      def setup
        self.class.tables.each do |table_name, schema_block|
          prefixed_name = table_name_prefixed(table_name)
          @db_connection.create_table?(prefixed_name, &schema_block)
        end
        super if defined?(super)
      end

      # Reset by dropping each table.
      def reset
        self.class.tables.each_key do |table_name|
          prefixed_name = table_name_prefixed(table_name)
          @db_connection.drop_table(prefixed_name, cascade: true) if @db_connection.table_exists?(prefixed_name)
        end
        super if defined?(super)
        setup
      end

      # This will truncate all the tables and reset the tracker back to 0,
      # done as a transaction.
      def truncate
        self.class.tables.each_key do |table_name|
          @db_connection.transaction do
            prefixed_name = table_name_prefixed(table_name)
            @db_connection[prefixed_name].truncate
            tracker.reset_last_processed_event_id(self.class.processor_name)
          end
        end
      end

      private

      attr_reader :db_connection
      attr_accessor :table_prefix

      def table(name = nil)
        if name.nil? && self.class.tables.length != 1
          raise DefaultTableError, 'You must specify table name when when 0 or multiple tables are defined'
        end

        name ||= self.class.tables.keys.first

        unless self.class.tables[name.to_sym]
          raise NoSuchTableError, "There is no table with the name '#{name}' defined"
        end

        db_connection[table_name_prefixed(name)]
      end

      def table_name_prefixed(name)
        [table_prefix, name].compact.join('_').to_sym
      end
    end
  end
end
