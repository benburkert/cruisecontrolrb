require File.dirname(__FILE__) + '/../abstract_unit'

class FlashTest < Test::Unit::TestCase
  class TestController < ActionController::Base
    def set_flash
      flash["that"] = "hello"
      render :inline => "hello"
    end

    def set_flash_now
      flash.now["that"] = "hello"
      flash.now["foo"] ||= "bar"
      flash.now["foo"] ||= "err"
      @flashy = flash.now["that"]
      @flash_copy = {}.update flash
      render :inline => "hello"
    end

    def attempt_to_use_flash_now
      @flash_copy = {}.update flash
      @flashy = flash["that"]
      render :inline => "hello"
    end

    def use_flash
      @flash_copy = {}.update flash
      @flashy = flash["that"]
      render :inline => "hello"
    end

    def use_flash_and_keep_it
      @flash_copy = {}.update flash
      @flashy = flash["that"]
      silence_warnings { keep_flash }
      render :inline => "hello"
    end

    def use_flash_after_reset_session
      flash["that"] = "hello"
      @flashy_that = flash["that"]
      reset_session
      @flashy_that_reset = flash["that"]
      flash["this"] = "good-bye"
      @flashy_this = flash["this"]
      render :inline => "hello"
    end

    def rescue_action(e)
      raise unless ActionController::MissingTemplate === e
    end
  end

  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = TestController.new
  end

  def test_flash
    get :set_flash

    get :use_flash
    assert_equal "hello", @response.template.assigns["flash_copy"]["that"]
    assert_equal "hello", @response.template.assigns["flashy"]

    get :use_flash
    assert_nil @response.template.assigns["flash_copy"]["that"], "On second flash"
  end

  def test_keep_flash
    get :set_flash
    
    assert_deprecated(/keep_flash/) { get :use_flash_and_keep_it }
    assert_equal "hello", @response.template.assigns["flash_copy"]["that"]
    assert_equal "hello", @response.template.assigns["flashy"]

    get :use_flash
    assert_equal "hello", @response.template.assigns["flash_copy"]["that"], "On second flash"

    get :use_flash
    assert_nil @response.template.assigns["flash_copy"]["that"], "On third flash"
  end
  
  def test_flash_now
    get :set_flash_now
    assert_equal "hello", @response.template.assigns["flash_copy"]["that"]
    assert_equal "bar"  , @response.template.assigns["flash_copy"]["foo"]
    assert_equal "hello", @response.template.assigns["flashy"]

    get :attempt_to_use_flash_now
    assert_nil @response.template.assigns["flash_copy"]["that"]
    assert_nil @response.template.assigns["flash_copy"]["foo"]
    assert_nil @response.template.assigns["flashy"]
  end 
  
  def test_flash_after_reset_session
    get :use_flash_after_reset_session
    assert_equal "hello",    @response.template.assigns["flashy_that"]
    assert_equal "good-bye", @response.template.assigns["flashy_this"]
    assert_nil   @response.template.assigns["flashy_that_reset"]
  end 
end
