module ActiveRecord
  module Associations
    class HasAndBelongsToManyAssociation < AssociationCollection #:nodoc:
      def initialize(owner, reflection)
        super
        construct_sql
      end
 
      def build(attributes = {})
        load_target
        record = @reflection.klass.new(attributes)
        @target << record
        record
      end

      def create(attributes = {})
        # Can't use Base.create since the foreign key may be a protected attribute.
        if attributes.is_a?(Array)
          attributes.collect { |attr| create(attr) }
        else
          record = build(attributes)
          insert_record(record) unless @owner.new_record?
          record
        end
      end

      def find_first
        load_target.first
      end
      
      def find(*args)
        options = Base.send(:extract_options_from_args!, args)

        # If using a custom finder_sql, scan the entire collection.
        if @reflection.options[:finder_sql]
          expects_array = args.first.kind_of?(Array)
          ids = args.flatten.compact.uniq

          if ids.size == 1
            id = ids.first.to_i
            record = load_target.detect { |record| id == record.id }
            expects_array ? [record] : record
          else
            load_target.select { |record| ids.include?(record.id) }
          end
        else
          conditions = "#{@finder_sql}"

          if sanitized_conditions = sanitize_sql(options[:conditions])
            conditions << " AND (#{sanitized_conditions})"
          end

          options[:conditions] = conditions
          options[:joins]      = @join_sql
          options[:readonly]   = finding_with_ambigious_select?(options[:select])

          if options[:order] && @reflection.options[:order]
            options[:order] = "#{options[:order]}, #{@reflection.options[:order]}"
          elsif @reflection.options[:order]
            options[:order] = @reflection.options[:order]
          end

          merge_options_from_reflection!(options)

          # Pass through args exactly as we received them.
          args << options
          @reflection.klass.find(*args)
        end
      end      
      
      # Deprecated as of Rails 1.2.   If your associations require attributes
      # you should be using has_many :through
      def push_with_attributes(record, join_attributes = {})
        raise_on_type_mismatch(record)
        join_attributes.each { |key, value| record[key.to_s] = value }

        callback(:before_add, record)
        insert_record(record) unless @owner.new_record?
        @target << record
        callback(:after_add, record)

        self
      end
      deprecate :push_with_attributes => "consider using has_many :through instead"

      alias :concat_with_attributes :push_with_attributes

      protected
        def method_missing(method, *args, &block)
          if @target.respond_to?(method) || (!@reflection.klass.respond_to?(method) && Class.respond_to?(method))
            super
          else
            @reflection.klass.with_scope(:find => { :conditions => @finder_sql, :joins => @join_sql, :readonly => false }) do
              @reflection.klass.send(method, *args, &block)
            end
          end
        end

        def count_records
          load_target.size
        end

        def insert_record(record)
          if record.new_record?
            return false unless record.save
          end

          if @reflection.options[:insert_sql]
            @owner.connection.execute(interpolate_sql(@reflection.options[:insert_sql], record))
          else
            columns = @owner.connection.columns(@reflection.options[:join_table], "#{@reflection.options[:join_table]} Columns")

            attributes = columns.inject({}) do |attributes, column|
              case column.name
                when @reflection.primary_key_name
                  attributes[column.name] = @owner.quoted_id
                when @reflection.association_foreign_key
                  attributes[column.name] = record.quoted_id
                else
                  if record.attributes.has_key?(column.name)
                    value = @owner.send(:quote_value, record[column.name], column)
                    attributes[column.name] = value unless value.nil?
                  end
              end
              attributes
            end

            sql =
              "INSERT INTO #{@reflection.options[:join_table]} (#{@owner.send(:quoted_column_names, attributes).join(', ')}) " +
              "VALUES (#{attributes.values.join(', ')})"

            @owner.connection.execute(sql)
          end
          
          return true
        end
        
        def delete_records(records)
          if sql = @reflection.options[:delete_sql]
            records.each { |record| @owner.connection.execute(interpolate_sql(sql, record)) }
          else
            ids = quoted_record_ids(records)
            sql = "DELETE FROM #{@reflection.options[:join_table]} WHERE #{@reflection.primary_key_name} = #{@owner.quoted_id} AND #{@reflection.association_foreign_key} IN (#{ids})"
            @owner.connection.execute(sql)
          end
        end
        
        def construct_sql
          interpolate_sql_options!(@reflection.options, :finder_sql)

          if @reflection.options[:finder_sql]
            @finder_sql = @reflection.options[:finder_sql]
          else
            @finder_sql = "#{@reflection.options[:join_table]}.#{@reflection.primary_key_name} = #{@owner.quoted_id} "
            @finder_sql << " AND (#{conditions})" if conditions
          end

          @join_sql = "INNER JOIN #{@reflection.options[:join_table]} ON #{@reflection.klass.table_name}.#{@reflection.klass.primary_key} = #{@reflection.options[:join_table]}.#{@reflection.association_foreign_key}"
        end

        # Join tables with additional columns on top of the two foreign keys must be considered ambigious unless a select
        # clause has been explicitly defined. Otherwise you can get broken records back, if, say, the join column also has
        # and id column, which will then overwrite the id column of the records coming back.
        def finding_with_ambigious_select?(select_clause)
          !select_clause && @owner.connection.columns(@reflection.options[:join_table], "Join Table Columns").size != 2
        end
    end
  end
end
