require File.dirname(__FILE__) + '/../abstract_unit'

Payment = Struct.new(:price)
class SummablePayment < Payment
  def +(p) self.class.new(price + p.price) end
end

class EnumerableTests < Test::Unit::TestCase
  def test_group_by
    names = %w(marcel sam david jeremy)
    klass = Class.new
    klass.send(:attr_accessor, :name)
    objects = (1..50).inject([]) do |people,|
      p = klass.new
      p.name = names.sort_by { rand }.first
      people << p
    end

    objects.group_by {|object| object.name}.each do |name, group|
      assert group.all? {|person| person.name == name}
    end
  end

  def test_sums
    assert_equal 30, [5, 15, 10].sum
    assert_equal 30, [5, 15, 10].sum { |i| i }

    assert_equal 'abc', %w(a b c).sum
    assert_equal 'abc', %w(a b c).sum { |i| i }

    payments = [ Payment.new(5), Payment.new(15), Payment.new(10) ]
    assert_equal 30, payments.sum(&:price)
    assert_equal 60, payments.sum { |p| p.price * 2 }

    payments = [ SummablePayment.new(5), SummablePayment.new(15) ]
    assert_equal SummablePayment.new(20), payments.sum
    assert_equal SummablePayment.new(20), payments.sum { |p| p }
  end

  def test_nil_sums
    assert_raise(TypeError) { [5, 15, nil].sum }

    payments = [ Payment.new(5), Payment.new(15), Payment.new(10), Payment.new(nil) ]
    assert_raise(TypeError) { payments.sum(&:price) }
    assert_equal 60, payments.sum { |p| p.price.to_i * 2 }
  end
  
  def test_empty_sums
    assert_equal 0, [].sum
    assert_equal 0, [].sum { |i| i }
    assert_equal Payment.new(0), [].sum(Payment.new(0))
  end
  
  def test_index_by
    payments = [ Payment.new(5), Payment.new(15), Payment.new(10) ]
    assert_equal(
      {5 => payments[0], 15 => payments[1], 10 => payments[2]},
      payments.index_by(&:price)
    )
  end
end
