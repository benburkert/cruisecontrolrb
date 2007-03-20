require 'abstract_unit'
require 'fixtures/person'
require 'fixtures/legacy_thing'

class LockWithoutDefault < ActiveRecord::Base; end

class LockWithCustomColumnWithoutDefault < ActiveRecord::Base
  set_table_name :lock_without_defaults_cust
  set_locking_column :custom_lock_version
end

class OptimisticLockingTest < Test::Unit::TestCase
  fixtures :people, :legacy_things

  def test_lock_existing
    p1 = Person.find(1)
    p2 = Person.find(1)
    assert_equal 0, p1.lock_version
    assert_equal 0, p2.lock_version

    p1.save!
    assert_equal 1, p1.lock_version
    assert_equal 0, p2.lock_version

    assert_raises(ActiveRecord::StaleObjectError) { p2.save! }
  end

  def test_lock_new
    p1 = Person.new(:first_name => 'anika')
    assert_equal 0, p1.lock_version

    p1.save!
    p2 = Person.find(p1.id)
    assert_equal 0, p1.lock_version
    assert_equal 0, p2.lock_version

    p1.save!
    assert_equal 1, p1.lock_version
    assert_equal 0, p2.lock_version

    assert_raises(ActiveRecord::StaleObjectError) { p2.save! }
  end

  def test_lock_column_name_existing
    t1 = LegacyThing.find(1)
    t2 = LegacyThing.find(1)
    assert_equal 0, t1.version
    assert_equal 0, t2.version

    t1.save!
    assert_equal 1, t1.version
    assert_equal 0, t2.version

    assert_raises(ActiveRecord::StaleObjectError) { t2.save! }
  end

  def test_lock_column_is_mass_assignable
    p1 = Person.create(:first_name => 'bianca')
    assert_equal 0, p1.lock_version
    assert_equal p1.lock_version, Person.new(p1.attributes).lock_version

    p1.save!
    assert_equal 1, p1.lock_version
    assert_equal p1.lock_version, Person.new(p1.attributes).lock_version
  end

  def test_lock_without_default_sets_version_to_zero
    t1 = LockWithoutDefault.new
    assert_equal 0, t1.lock_version
  end

  def test_lock_with_custom_column_without_default_sets_version_to_zero
    t1 = LockWithCustomColumnWithoutDefault.new
    assert_equal 0, t1.custom_lock_version
  end
end


# TODO: test against the generated SQL since testing locking behavior itself
# is so cumbersome. Will deadlock Ruby threads if the underlying db.execute
# blocks, so separate script called by Kernel#system is needed.
# (See exec vs. async_exec in the PostgreSQL adapter.)

# TODO: The SQL Server and Sybase adapters currently have no support for pessimistic locking

unless current_adapter?(:SQLServerAdapter, :SybaseAdapter)
  class PessimisticLockingTest < Test::Unit::TestCase
    self.use_transactional_fixtures = false
    fixtures :people, :readers

    def setup
      # Avoid introspection queries during tests.
      Person.columns; Reader.columns

      @allow_concurrency = ActiveRecord::Base.allow_concurrency
      ActiveRecord::Base.allow_concurrency = true
    end

    def teardown
      ActiveRecord::Base.allow_concurrency = @allow_concurrency
    end

    # Test typical find.
    def test_sane_find_with_lock
      assert_nothing_raised do
        Person.transaction do
          Person.find 1, :lock => true
        end
      end
    end

    # Test scoped lock.
    def test_sane_find_with_scoped_lock
      assert_nothing_raised do
        Person.transaction do
          Person.with_scope(:find => { :lock => true }) do
            Person.find 1
          end
        end
      end
    end

    # PostgreSQL protests SELECT ... FOR UPDATE on an outer join.
    unless current_adapter?(:PostgreSQLAdapter)
      # Test locked eager find.
      def test_eager_find_with_lock
        assert_nothing_raised do
          Person.transaction do
            Person.find 1, :include => :readers, :lock => true
          end
        end
      end
    end

    # Locking a record reloads it.
    def test_sane_lock_method
      assert_nothing_raised do
        Person.transaction do
          person = Person.find 1
          old, person.first_name = person.first_name, 'fooman'
          person.lock!
          assert_equal old, person.first_name
        end
      end
    end

    if current_adapter?(:PostgreSQLAdapter, :OracleAdapter)
      def test_no_locks_no_wait
        first, second = duel { Person.find 1 }
        assert first.end > second.end
      end

      def test_second_lock_waits
        assert [0.2, 1, 5].any? { |zzz|
          first, second = duel(zzz) { Person.find 1, :lock => true }
          second.end > first.end
        }
      end

      protected
        def duel(zzz = 5)
          t0, t1, t2, t3 = nil, nil, nil, nil

          a = Thread.new do
            t0 = Time.now
            Person.transaction do
              yield
              sleep zzz       # block thread 2 for zzz seconds
            end
            t1 = Time.now
          end

          b = Thread.new do
            sleep zzz / 2.0   # ensure thread 1 tx starts first
            t2 = Time.now
            Person.transaction { yield }
            t3 = Time.now
          end

          a.join
          b.join

          assert t1 > t0 + zzz
          assert t2 > t0
          assert t3 > t2
          [t0.to_f..t1.to_f, t2.to_f..t3.to_f]
        end
    end
  end
end
