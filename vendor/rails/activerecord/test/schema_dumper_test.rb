require 'abstract_unit'
require "#{File.dirname(__FILE__)}/../lib/active_record/schema_dumper"
require 'stringio'

if ActiveRecord::Base.connection.respond_to?(:tables)

  class SchemaDumperTest < Test::Unit::TestCase
    def standard_dump
      stream = StringIO.new
      ActiveRecord::SchemaDumper.ignore_tables = []
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
      stream.string
    end
    
    def test_schema_dump
      output = standard_dump
      assert_match %r{create_table "accounts"}, output
      assert_match %r{create_table "authors"}, output
      assert_no_match %r{create_table "schema_info"}, output
    end
    
    def assert_line_up(lines, pattern, required = false)
      return assert(true) if lines.empty?
      matches = lines.map { |line| line.match(pattern) }
      assert matches.all? if required
      matches.compact!
      return assert(true) if matches.empty?
      assert_equal 1, matches.map{ |match| match.offset(0).first }.uniq.length
    end
    
    def test_arguments_line_up
      output  = standard_dump
      output.scan(/^( *)create_table.*?\n(.*?)^\1end/m).map{ |m| m.last.split(/\n/) }.each do |column_set|
        assert_line_up(column_set, /:(?:integer|decimal|float|datetime|timestamp|time|date|text|binary|string|boolean)/, true)
        assert_line_up(column_set, /:default => /)
        assert_line_up(column_set, /:limit => /)
        assert_line_up(column_set, /:null => /)
      end
    end
    
    def test_no_dump_errors
      output = standard_dump
      assert_no_match %r{\# Could not dump table}, output
    end
    
    def test_schema_dump_includes_not_null_columns
      stream = StringIO.new
      
      ActiveRecord::SchemaDumper.ignore_tables = [/^[^r]/]
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
      output = stream.string
      assert_match %r{:null => false}, output
    end

    def test_schema_dump_with_string_ignored_table
      stream = StringIO.new
      
      ActiveRecord::SchemaDumper.ignore_tables = ['accounts']      
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
      output = stream.string
      assert_no_match %r{create_table "accounts"}, output
      assert_match %r{create_table "authors"}, output
      assert_no_match %r{create_table "schema_info"}, output
    end


    def test_schema_dump_with_regexp_ignored_table
      stream = StringIO.new
      
      ActiveRecord::SchemaDumper.ignore_tables = [/^account/]      
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
      output = stream.string
      assert_no_match %r{create_table "accounts"}, output
      assert_match %r{create_table "authors"}, output
      assert_no_match %r{create_table "schema_info"}, output
    end


    def test_schema_dump_illegal_ignored_table_value
      stream = StringIO.new      
      ActiveRecord::SchemaDumper.ignore_tables = [5]      
      assert_raise(StandardError) do
        ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
      end
    end

    def test_schema_dump_includes_decimal_options
      stream = StringIO.new      
      ActiveRecord::SchemaDumper.ignore_tables = [/^[^n]/]
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
      output = stream.string
      assert_match %r{:precision => 3,[[:space:]]+:scale => 2,[[:space:]]+:default => 2.78}, output
    end
  end

end
