require 'abstract_unit'

class CopyTableTest < Test::Unit::TestCase
  fixtures :companies, :comments
  
  def setup
    @connection = ActiveRecord::Base.connection
    class << @connection
      public :copy_table, :table_structure, :indexes
    end
  end
  
  def test_copy_table(from = 'companies', to = 'companies2', options = {})
    assert_nothing_raised {copy_table(from, to, options)}
    assert_equal row_count(from), row_count(to)
      
    if block_given?
      yield from, to, options
    else
      assert_equal column_names(from), column_names(to)
    end
    
    @connection.drop_table(to) rescue nil
  end
  
  def test_copy_table_renaming_column
    test_copy_table('companies', 'companies2', 
        :rename => {'client_of' => 'fan_of'}) do |from, to, options|
      assert_equal column_values(from, 'client_of').compact.sort, 
                   column_values(to, 'fan_of').compact.sort
    end
  end
  
  def test_copy_table_with_index
    test_copy_table('comments', 'comments_with_index') do
      @connection.add_index('comments_with_index', ['post_id', 'type'])
      test_copy_table('comments_with_index', 'comments_with_index2') do
        assert_equal table_indexes_without_name('comments_with_index'),
                     table_indexes_without_name('comments_with_index2')
      end
    end
  end
  
protected
  def copy_table(from, to, options = {})
    @connection.copy_table(from, to, {:temporary => true}.merge(options))
  end

  def column_names(table)
    @connection.table_structure(table).map {|column| column['name']}
  end
  
  def column_values(table, column)
    @connection.select_all("SELECT #{column} FROM #{table}").map {|row| row[column]}
  end

  def table_indexes_without_name(table)
    @connection.indexes('comments_with_index').delete(:name)
  end
  
  def row_count(table)
    @connection.select_one("SELECT COUNT(*) AS count FROM #{table}")['count']
  end
end
