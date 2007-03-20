require File.dirname(__FILE__) + '/../../abstract_unit'

class DeprecatedBaseMethodsTest < Test::Unit::TestCase
  class Target < ActionController::Base
    def deprecated_symbol_parameter_to_url_for
      redirect_to(url_for(:home_url, "superstars"))
    end
    
    def deprecated_render_parameters
      render "fun/games/hello_world"
    end
    
    def home_url(greeting)
      "http://example.com/#{greeting}"
    end

    def raises_name_error
      this_method_doesnt_exist
    end

    def rescue_action(e) raise e end
  end

  Target.template_root = File.dirname(__FILE__) + "/../../fixtures"

  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = Target.new
  end

  def test_deprecated_symbol_parameter_to_url_for
    assert_deprecated("url_for(:home_url)") do
      get :deprecated_symbol_parameter_to_url_for
    end

    assert_redirected_to "http://example.com/superstars"
  end
  
  def test_deprecated_render_parameters
    assert_deprecated("render('fun/games/hello_world')") do
      get :deprecated_render_parameters
    end

    assert_equal "Living in a nested world", @response.body
  end

  def test_log_error_silences_deprecation_warnings
    get :raises_name_error
  rescue => e
    assert_not_deprecated { @controller.send :log_error, e }
  end

  def test_assertion_failed_error_silences_deprecation_warnings
    get :raises_name_error
  rescue => e
    error = Test::Unit::Error.new('testing ur doodz', e)
    assert_not_deprecated { error.message }
  end
end
