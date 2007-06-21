require File.join(File.dirname(__FILE__), "..", "test_helper")
require 'method_definer'
require 'mocha/expectation'
require 'execution_point'
require 'deprecation_disabler'

class ExpectationTest < Test::Unit::TestCase
  
  include Mocha
  include DeprecationDisabler
  
  def new_expectation
    Expectation.new(nil, :expected_method)
  end
  
  def test_should_match_calls_to_same_method_with_any_parameters
    assert new_expectation.match?(:expected_method, 1, 2, 3)
  end
  
  def test_should_match_calls_to_same_method_with_exactly_zero_parameters
    expectation = new_expectation.with()
    assert expectation.match?(:expected_method)
  end
  
  def test_should_not_match_calls_to_same_method_with_more_than_zero_parameters
    expectation = new_expectation.with()
    assert !expectation.match?(:expected_method, 1, 2, 3)
  end
  
  def test_should_match_calls_to_same_method_with_expected_parameter_values
    expectation = new_expectation.with(1, 2, 3)
    assert expectation.match?(:expected_method, 1, 2, 3)
  end
  
  def test_should_match_calls_to_same_method_with_parameters_constrained_as_expected
    expectation = new_expectation.with() {|x, y, z| x + y == z}
    assert expectation.match?(:expected_method, 1, 2, 3)
  end
  
  def test_should_not_match_calls_to_different_method_with_parameters_constrained_as_expected
    expectation = new_expectation.with() {|x, y, z| x + y == z}
    assert !expectation.match?(:different_method, 1, 2, 3)
  end
  
  def test_should_not_match_calls_to_different_methods_with_no_parameters
    assert !new_expectation.match?(:unexpected_method)
  end
  
  def test_should_not_match_calls_to_same_method_with_too_few_parameters
    expectation = new_expectation.with(1, 2, 3)
    assert !expectation.match?(:unexpected_method, 1, 2)
  end
  
  def test_should_not_match_calls_to_same_method_with_too_many_parameters
    expectation = new_expectation.with(1, 2)
    assert !expectation.match?(:unexpected_method, 1, 2, 3)
  end
  
  def test_should_not_match_calls_to_same_method_with_unexpected_parameter_values
    expectation = new_expectation.with(1, 2, 3)
    assert !expectation.match?(:unexpected_method, 1, 0, 3)
  end
  
  def test_should_not_match_calls_to_same_method_with_parameters_not_constrained_as_expected
    expectation = new_expectation.with() {|x, y, z| x + y == z}
    assert !expectation.match?(:expected_method, 1, 0, 3)
  end
  
  def test_should_match_until_expected_invocation_count_is_one_and_actual_invocation_count_would_be_two
    expectation = new_expectation.times(1)
    assert expectation.match?(:expected_method)
    expectation.invoke
    assert !expectation.match?(:expected_method)
  end
  
  def test_should_match_until_expected_invocation_count_is_two_and_actual_invocation_count_would_be_three
    expectation = new_expectation.times(2)
    assert expectation.match?(:expected_method)
    expectation.invoke
    assert expectation.match?(:expected_method)
    expectation.invoke
    assert !expectation.match?(:expected_method)
  end
  
  def test_should_match_until_expected_invocation_count_is_a_range_from_two_to_three_and_actual_invocation_count_would_be_four
    expectation = new_expectation.times(2..3)
    assert expectation.match?(:expected_method)
    expectation.invoke
    assert expectation.match?(:expected_method)
    expectation.invoke
    assert expectation.match?(:expected_method)
    expectation.invoke
    assert !expectation.match?(:expected_method)
  end
  
  def test_should_store_provided_backtrace
    backtrace = Object.new
    expectation = Expectation.new(nil, :expected_method, backtrace)
    assert_equal backtrace, expectation.backtrace
  end
  
  def test_should_default_backtrace_to_caller
    execution_point = ExecutionPoint.current; expectation = Expectation.new(nil, :expected_method)
    assert_equal execution_point, ExecutionPoint.new(expectation.backtrace)
  end
  
  def test_should_not_yield
    yielded = false
    new_expectation.invoke() { yielded = true }
    assert_equal false, yielded
  end

  def test_should_yield_no_parameters
    expectation = new_expectation().yields()
    yielded_parameters = nil
    expectation.invoke() { |*parameters| yielded_parameters = parameters }
    assert_equal Array.new, yielded_parameters
  end

  def test_should_yield_with_specified_parameters
    expectation = new_expectation().yields(1, 2, 3)
    yielded_parameters = nil
    expectation.invoke() { |*parameters| yielded_parameters = parameters }
    assert_equal [1, 2, 3], yielded_parameters
  end

  def test_should_yield_different_parameters_on_consecutive_invocations
    expectation = new_expectation().yields(1, 2, 3).yields(4, 5)
    yielded_parameters = []
    expectation.invoke() { |*parameters| yielded_parameters << parameters }
    expectation.invoke() { |*parameters| yielded_parameters << parameters }
    assert_equal [[1, 2, 3], [4, 5]], yielded_parameters
  end
  
  def test_should_yield_multiple_times_for_single_invocation
    expectation = new_expectation().multiple_yields([1, 2, 3], [4, 5])
    yielded_parameters = []
    expectation.invoke() { |*parameters| yielded_parameters << parameters }
    assert_equal [[1, 2, 3], [4, 5]], yielded_parameters
  end

  def test_should_yield_multiple_times_for_first_invocation_and_once_for_second_invocation
    expectation = new_expectation().multiple_yields([1, 2, 3], [4, 5]).then.yields(6, 7)
    yielded_parameters = []
    expectation.invoke() { |*parameters| yielded_parameters << parameters }
    expectation.invoke() { |*parameters| yielded_parameters << parameters }
    assert_equal [[1, 2, 3], [4, 5], [6, 7]], yielded_parameters
  end

  def test_should_return_specified_value
    expectation = new_expectation.returns(99)
    assert_equal 99, expectation.invoke
  end
  
  def test_should_return_same_specified_value_multiple_times
    expectation = new_expectation.returns(99)
    assert_equal 99, expectation.invoke
    assert_equal 99, expectation.invoke
  end
  
  def test_should_return_specified_values_on_consecutive_calls
    expectation = new_expectation.returns(99, 100, 101)
    assert_equal 99, expectation.invoke
    assert_equal 100, expectation.invoke
    assert_equal 101, expectation.invoke
  end
  
  def test_should_return_specified_values_on_consecutive_calls_even_if_values_are_modified
    values = [99, 100, 101]
    expectation = new_expectation.returns(*values)
    values.shift
    assert_equal 99, expectation.invoke
    assert_equal 100, expectation.invoke
    assert_equal 101, expectation.invoke
  end
  
  def test_should_return_nil_by_default
    assert_nil new_expectation.invoke
  end
  
  def test_should_return_nil_if_no_value_specified
    expectation = new_expectation.returns()
    assert_nil expectation.invoke
  end
  
  def test_should_return_evaluated_proc
    proc = lambda { 99 }
    expectation = new_expectation.returns(proc)
    result = nil
    disable_deprecations { result = expectation.invoke }
    assert_equal 99, result
  end
  
  def test_should_return_evaluated_proc_without_using_is_a_method
    proc = lambda { 99 }
    proc.define_instance_accessor(:called)
    proc.called = false
    proc.replace_instance_method(:is_a?) { self.called = true; true}
    expectation = new_expectation.returns(proc)
    disable_deprecations { expectation.invoke }
    assert_equal false, proc.called
  end
  
  def test_should_raise_runtime_exception
    expectation = new_expectation.raises
    assert_raise(RuntimeError) { expectation.invoke }
  end
  
  def test_should_raise_custom_exception
    exception = Class.new(Exception)
    expectation = new_expectation.raises(exception)
    assert_raise(exception) { expectation.invoke }
  end
  
  def test_should_raise_same_instance_of_custom_exception
    exception_klass = Class.new(StandardError)
    expected_exception = exception_klass.new
    expectation = new_expectation.raises(expected_exception)
    actual_exception = assert_raise(exception_klass) { expectation.invoke }
    assert_same expected_exception, actual_exception
  end
  
  def test_should_use_the_default_exception_message
    expectation = new_expectation.raises(Exception)
    exception = assert_raise(Exception) { expectation.invoke }
    assert_equal Exception.new.message, exception.message
  end
  
  def test_should_raise_custom_exception_with_message
    exception_msg = "exception message"
    expectation = new_expectation.raises(Exception, exception_msg)
    exception = assert_raise(Exception) { expectation.invoke }
    assert_equal exception_msg, exception.message
  end
  
  def test_should_return_values_then_raise_exception
    expectation = new_expectation.returns(1, 2).then.raises()
    assert_equal 1, expectation.invoke
    assert_equal 2, expectation.invoke
    assert_raise(RuntimeError) { expectation.invoke }
  end
  
  def test_should_raise_exception_then_return_values
    expectation = new_expectation.raises().then.returns(1, 2)
    assert_raise(RuntimeError) { expectation.invoke }
    assert_equal 1, expectation.invoke
    assert_equal 2, expectation.invoke
  end
  
  def test_should_not_raise_error_on_verify_if_expected_call_was_made
    expectation = new_expectation
    expectation.invoke
    assert_nothing_raised(ExpectationError) {
      expectation.verify
    }
  end
  
  def test_should_raise_error_on_verify_if_call_expected_once_but_invoked_twice
    expectation = new_expectation.once
    expectation.invoke
    expectation.invoke
    assert_raises(ExpectationError) {
      expectation.verify
    }
  end

  def test_should_raise_error_on_verify_if_call_expected_once_but_not_invoked
    expectation = new_expectation.once
    assert_raises(ExpectationError) {
      expectation.verify
    }
  end

  def test_should_not_raise_error_on_verify_if_call_expected_once_and_invoked_once
    expectation = new_expectation.once
    expectation.invoke
    assert_nothing_raised(ExpectationError) {
      expectation.verify
    }
  end

  def test_should_not_raise_error_on_verify_if_expected_call_was_made_at_least_once
    expectation = new_expectation.at_least_once
    3.times {expectation.invoke}
    assert_nothing_raised(ExpectationError) {
      expectation.verify
    }
  end
  
  def test_should_raise_error_on_verify_if_expected_call_was_not_made_at_least_once
    expectation = new_expectation.with(1, 2, 3).at_least_once
    e = assert_raise(ExpectationError) {
      expectation.verify
    }
    assert_match(/expected calls: at least 1, actual calls: 0/i, e.message)
  end
  
  def test_should_not_raise_error_on_verify_if_expected_call_was_made_expected_number_of_times
    expectation = new_expectation.times(2)
    2.times {expectation.invoke}
    assert_nothing_raised(ExpectationError) {
      expectation.verify
    }
  end
  
  def test_should_expect_call_not_to_be_made
    expectation = new_expectation
    expectation.define_instance_accessor(:how_many_times)
    expectation.replace_instance_method(:times) { |how_many_times| self.how_many_times = how_many_times }
    expectation.never
    assert_equal 0, expectation.how_many_times
  end
  
  def test_should_raise_error_on_verify_if_expected_call_was_made_too_few_times
    expectation = new_expectation.times(2)
    1.times {expectation.invoke}
    e = assert_raise(ExpectationError) {
      expectation.verify
    }
    assert_match(/expected calls: 2, actual calls: 1/i, e.message)
  end
  
  def test_should_raise_error_on_verify_if_expected_call_was_made_too_many_times
    expectation = new_expectation.times(2)
    3.times {expectation.invoke}
    assert_raise(ExpectationError) {
      expectation.verify
    }
  end
  
  def test_should_yield_self_to_block
    expectation = new_expectation
    expectation.invoke
    yielded_expectation = nil
    expectation.verify { |x| yielded_expectation = x }
    assert_equal expectation, yielded_expectation
  end
  
  def test_should_yield_to_block_before_raising_exception
    yielded = false
    assert_raise(ExpectationError) {
      new_expectation.verify { |x| yielded = true }
    }
    assert yielded
  end
  
  def test_should_store_backtrace_from_point_where_expectation_was_created
    execution_point = ExecutionPoint.current; expectation = Expectation.new(nil, :expected_method)
    assert_equal execution_point, ExecutionPoint.new(expectation.backtrace)
  end
  
  def test_should_set_backtrace_on_assertion_failed_error_to_point_where_expectation_was_created
    execution_point = ExecutionPoint.current; expectation = Expectation.new(nil, :expected_method)
    error = assert_raise(ExpectationError) {  
      expectation.verify
    }
    assert_equal execution_point, ExecutionPoint.new(error.backtrace)
  end
  
  def test_should_display_expectation_message_in_exception_message
    options = [:a, :b, {:c => 1, :d => 2}]
    expectation = new_expectation.with(*options)
    exception = assert_raise(ExpectationError) {
      expectation.verify
    }
    assert exception.message.include?(expectation.method_signature)
  end
  
  def test_should_combine_method_name_and_pretty_parameters
    arguments = 1, 2, {'a' => true, :b => false}, [1, 2, 3]
    expectation = new_expectation.with(*arguments)
    assert_equal "expected_method(#{PrettyParameters.new(arguments).pretty})", expectation.method_signature
  end
  
  def test_should_not_include_parameters_in_message
    assert_equal "expected_method", new_expectation.method_signature
  end
  
  def test_should_raise_error_with_message_indicating_which_method_was_expected_to_be_called_on_which_mock_object
    mock = Class.new { def mocha_inspect; 'mock'; end }.new
    expectation = Expectation.new(mock, :expected_method)
    e = assert_raise(ExpectationError) { expectation.verify }
    assert_match "mock.expected_method", e.message
  end
  
  def test_should_exclude_mocha_locations_from_backtrace
    mocha_lib = "/username/workspace/mocha_wibble/lib/"
    backtrace = [ mocha_lib + 'exclude/me/1', mocha_lib + 'exclude/me/2', '/keep/me', mocha_lib + 'exclude/me/3']
    expectation = Expectation.new(nil, :expected_method, backtrace)
    expectation.define_instance_method(:mocha_lib_directory) { mocha_lib }
    assert_equal ['/keep/me'], expectation.filtered_backtrace
  end
  
  def test_should_determine_path_for_mocha_lib_directory
    expectation = new_expectation()
    assert_match Regexp.new("/lib/$"), expectation.mocha_lib_directory
  end
  
end
