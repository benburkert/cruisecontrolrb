require File.dirname(__FILE__) + '/../abstract_unit'

class BlankTest < Test::Unit::TestCase
  BLANK = [nil, false, '', '   ', "  \n\t  \r ", [], {}]
  NOT   = [true, 0, 1, 'a', [nil], { nil => 0 }]

  def test_blank
    BLANK.each { |v| assert v.blank?  }
    NOT.each   { |v| assert !v.blank? }
  end
end
