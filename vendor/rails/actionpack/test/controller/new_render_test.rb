require File.dirname(__FILE__) + '/../abstract_unit'

silence_warnings { Customer = Struct.new("Customer", :name) }

module Fun
  class GamesController < ActionController::Base
    def hello_world
    end
  end
end

module NewRenderTestHelper
  def rjs_helper_method_from_module
    page.visual_effect :highlight
  end
end

class NewRenderTestController < ActionController::Base
  layout :determine_layout

  def self.controller_name; "test"; end
  def self.controller_path; "test"; end

  def hello_world
  end

  def render_hello_world
    render :template => "test/hello_world"
  end

  def render_hello_world_from_variable
    @person = "david"
    render :text => "hello #{@person}"
  end

  def render_action_hello_world
    render :action => "hello_world"
  end

  def render_action_hello_world_as_symbol
    render :action => :hello_world
  end
  
  def render_text_hello_world
    render :text => "hello world"
  end
 
  def render_text_hello_world_with_layout
    @variable_for_layout = ", I'm here!"
    render :text => "hello world", :layout => true
  end

  def hello_world_with_layout_false
    render :layout => false
  end

  def render_custom_code
    render :text => "hello world", :status => "404 Moved"
  end

  def render_file_with_instance_variables
    @secret = 'in the sauce'
    path = File.join(File.dirname(__FILE__), '../fixtures/test/render_file_with_ivar.rhtml')
    render :file => path
  end

  def render_file_with_locals
    path = File.join(File.dirname(__FILE__), '../fixtures/test/render_file_with_locals.rhtml')
    render :file => path, :locals => {:secret => 'in the sauce'} 
  end

  def render_file_not_using_full_path
    @secret = 'in the sauce'
    render :file => 'test/render_file_with_ivar', :use_full_path => true
  end
 
  def render_file_not_using_full_path_with_relative_path
    @secret = 'in the sauce'
    render :file => 'test/../test/render_file_with_ivar', :use_full_path => true
  end
  
  def render_file_not_using_full_path_with_dot_in_path
    @secret = 'in the sauce'
    render :file => 'test/dot.directory/render_file_with_ivar', :use_full_path => true
  end

  def render_xml_hello
    @name = "David"
    render :template => "test/hello"
  end

  def greeting
    # let's just rely on the template
  end

  def layout_test
    render :action => "hello_world"
  end

  def layout_test_with_different_layout
    render :action => "hello_world", :layout => "standard"
  end
  
  def rendering_without_layout
    render :action => "hello_world", :layout => false
  end

  def layout_overriding_layout
    render :action => "hello_world", :layout => "standard"
  end
  
  def rendering_nothing_on_layout
    render :nothing => true
  end
  
  def builder_layout_test
    render :action => "hello"
  end

  def partials_list
    @test_unchanged = 'hello'
    @customers = [ Customer.new("david"), Customer.new("mary") ]
    render :action => "list"
  end

  def partial_only
    render :partial => true
  end

  def partial_only_with_layout
    render :partial => "partial_only", :layout => true
  end
  
  def partial_with_locals
    render :partial => "customer", :locals => { :customer => Customer.new("david") } 
  end
  
  def partial_collection
    render :partial => "customer", :collection => [ Customer.new("david"), Customer.new("mary") ]
  end

  def partial_collection_with_locals
    render :partial => "customer_greeting", :collection => [ Customer.new("david"), Customer.new("mary") ], :locals => { :greeting => "Bonjour" }
  end

  def empty_partial_collection
    render :partial => "customer", :collection => []
  end
  
  def partial_with_hash_object
    render :partial => "hash_object", :object => {:first_name => "Sam"}
  end

  def partial_with_implicit_local_assignment
    @customer = Customer.new("Marcel")
    render :partial => "customer"
  end
  
  def hello_in_a_string
    @customers = [ Customer.new("david"), Customer.new("mary") ]
    render :text =>  "How's there? #{render_to_string("test/list")}"
  end
  
  def render_to_string_with_assigns
    @before = "i'm before the render"
    render_to_string :text => "foo"
    @after = "i'm after the render"
    render :action => "test/hello_world"
  end

 def render_to_string_with_partial
    @partial_only = render_to_string :partial => "partial_only"
    @partial_with_locals = render_to_string :partial => "customer", :locals => { :customer => Customer.new("david") }     
    render :action => "test/hello_world"  
  end  
  
  def render_to_string_with_exception
    render_to_string :file => "exception that will not be caught - this will certainly not work", :use_full_path => true
  end
  
  def render_to_string_with_caught_exception
    @before = "i'm before the render"
    begin
      render_to_string :file => "exception that will be caught- hope my future instance vars still work!", :use_full_path => true
    rescue
    end
    @after = "i'm after the render"
    render :action => "test/hello_world"
  end

  def accessing_params_in_template
    render :inline =>  "Hello: <%= params[:name] %>"
  end

  def accessing_params_in_template_with_layout
    render :layout => nil, :inline =>  "Hello: <%= params[:name] %>"
  end

  def render_with_explicit_template
    render "test/hello_world"
  end

  def double_render
    render :text => "hello"
    render :text => "world"
  end

  def double_redirect
    redirect_to :action => "double_render"
    redirect_to :action => "double_render"
  end

  def render_and_redirect
    render :text => "hello"
    redirect_to :action => "double_render"
  end
  
  def render_to_string_and_render
    @stuff = render_to_string :text => "here is some cached stuff"
    render :text => "Hi web users! #{@stuff}"
  end

  def rendering_with_conflicting_local_vars
    @name = "David"
    def @template.name() nil end
    render :action => "potential_conflicts"
  end

  def hello_world_from_rxml_using_action
    render :action => "hello_world.rxml"
  end

  def hello_world_from_rxml_using_template
    render :template => "test/hello_world.rxml"
  end

  def head_with_location_header
    head :location => "/foo"
  end

  def head_with_symbolic_status
    head :status => params[:status].intern
  end

  def head_with_integer_status
    head :status => params[:status].to_i
  end

  def head_with_string_status
    head :status => params[:status]
  end

  def head_with_custom_header
    head :x_custom_header => "something"
  end

  def head_with_status_code_first
    head :forbidden, :x_custom_header => "something"
  end

  helper NewRenderTestHelper
  helper do 
    def rjs_helper_method(value)
      page.visual_effect :highlight, value
    end
  end

  def enum_rjs_test
    render :update do |page|
      page.select('.product').each do |value|
        page.rjs_helper_method_from_module
        page.rjs_helper_method(value)
        page.sortable(value, :url => { :action => "order" })
        page.draggable(value)
      end
    end
  end

  def delete_with_js
    @project_id = 4
  end

  def render_js_with_explicit_template
    @project_id = 4
    render :template => 'test/delete_with_js'
  end

  def render_js_with_explicit_action_template
    @project_id = 4
    render :action => 'delete_with_js'
  end

  def update_page
    render :update do |page|
      page.replace_html 'balance', '$37,000,000.00'
      page.visual_effect :highlight, 'balance'
    end
  end
  
  def update_page_with_instance_variables
    @money = '$37,000,000.00'
    @div_id = 'balance'
    render :update do |page|
      page.replace_html @div_id, @money
      page.visual_effect :highlight, @div_id
    end
  end

  def action_talk_to_layout
    # Action template sets variable that's picked up by layout
  end

  def render_text_with_assigns
    @hello = "world"
    render :text => "foo"
  end

  def yield_content_for
    render :action => "content_for", :layout => "yield"
  end

  def render_content_type_from_body
    response.content_type = Mime::RSS
    render :text => "hello world!"
  end

  def rescue_action(e) raise end
    
  private
    def determine_layout
      case action_name 
        when "hello_world", "layout_test", "rendering_without_layout",
             "rendering_nothing_on_layout", "render_text_hello_world",
             "render_text_hello_world_with_layout",
             "hello_world_with_layout_false",
             "partial_only", "partial_only_with_layout",
             "accessing_params_in_template",
             "accessing_params_in_template_with_layout",
             "render_with_explicit_template",
             "render_js_with_explicit_template",
             "render_js_with_explicit_action_template",
             "delete_with_js", "update_page", "update_page_with_instance_variables"
    
          "layouts/standard"
        when "builder_layout_test"
          "layouts/builder"
        when "action_talk_to_layout", "layout_overriding_layout"
          "layouts/talk_from_action"
      end
    end
end

NewRenderTestController.template_root = File.dirname(__FILE__) + "/../fixtures/"
Fun::GamesController.template_root = File.dirname(__FILE__) + "/../fixtures/"

class NewRenderTest < Test::Unit::TestCase
  def setup
    @controller = NewRenderTestController.new

    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    @controller.logger = Logger.new(nil)

    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @request.host = "www.nextangle.com"
  end

  def test_simple_show
    get :hello_world
    assert_response :success
    assert_template "test/hello_world"
    assert_equal "<html>Hello world!</html>", @response.body
  end

  def test_do_with_render
    get :render_hello_world
    assert_template "test/hello_world"
  end

  def test_do_with_render_from_variable
    get :render_hello_world_from_variable
    assert_equal "hello david", @response.body
  end

  def test_do_with_render_action
    get :render_action_hello_world
    assert_template "test/hello_world"
  end

  def test_do_with_render_action_as_symbol
    get :render_action_hello_world_as_symbol
    assert_template "test/hello_world"
  end

  def test_do_with_render_text
    get :render_text_hello_world
    assert_equal "hello world", @response.body
  end

  def test_do_with_render_text_and_layout
    get :render_text_hello_world_with_layout
    assert_equal "<html>hello world, I'm here!</html>", @response.body
  end

  def test_do_with_render_action_and_layout_false
    get :hello_world_with_layout_false
    assert_equal 'Hello world!', @response.body
  end

  def test_do_with_render_custom_code
    get :render_custom_code
    assert_response :missing
  end

  def test_render_file_with_instance_variables
    get :render_file_with_instance_variables
    assert_equal "The secret is in the sauce\n", @response.body
  end

  def test_render_file_not_using_full_path
    get :render_file_not_using_full_path 
    assert_equal "The secret is in the sauce\n", @response.body
  end

  def test_render_file_not_using_full_path_with_relative_path
    get :render_file_not_using_full_path_with_relative_path
    assert_equal "The secret is in the sauce\n", @response.body
  end

  def test_render_file_not_using_full_path_with_dot_in_path
    get :render_file_not_using_full_path_with_dot_in_path
    assert_equal "The secret is in the sauce\n", @response.body
  end

  def test_render_file_with_locals
    get :render_file_with_locals
    assert_equal "The secret is in the sauce\n", @response.body
  end

  def test_attempt_to_access_object_method
    assert_raises(ActionController::UnknownAction, "No action responded to [clone]") { get :clone }
  end

  def test_private_methods
    assert_raises(ActionController::UnknownAction, "No action responded to [determine_layout]") { get :determine_layout }
  end

  def test_access_to_request_in_view
    view_internals_old_value = ActionController::Base.view_controller_internals

    ActionController::Base.view_controller_internals = false
    ActionController::Base.protected_variables_cache = nil

    get :hello_world
    assert !assigns.include?('request'), 'request should not be in assigns'

    ActionController::Base.view_controller_internals = true
    ActionController::Base.protected_variables_cache = nil

    get :hello_world
    assert assigns.include?('request'), 'request should be in assigns'
    assert_deprecated 'request' do
      assert_kind_of ActionController::AbstractRequest, assigns['request']
    end
    assert_not_deprecated do
      assert_kind_of ActionController::AbstractRequest, @response.template.request
      assert_kind_of ActionController::AbstractRequest, assigns['_request']
    end

  ensure
    ActionController::Base.view_controller_internals = view_internals_old_value
    ActionController::Base.protected_variables_cache = nil
  end

  def test_render_xml
    get :render_xml_hello
    assert_equal "<html>\n  <p>Hello David</p>\n<p>This is grand!</p>\n</html>\n", @response.body
  end

  def test_enum_rjs_test
    get :enum_rjs_test
    assert_equal <<-EOS.strip, @response.body
$$(".product").each(function(value, index) {
new Effect.Highlight(element,{});
new Effect.Highlight(value,{});
Sortable.create(value, {onUpdate:function(){new Ajax.Request('/test/order', {asynchronous:true, evalScripts:true, parameters:Sortable.serialize(value)})}});
new Draggable(value, {});
});
EOS
  end

  def test_render_xml_with_default
    get :greeting
    assert_equal "<p>This is grand!</p>\n", @response.body
  end

  def test_render_rjs_with_default
    get :delete_with_js
    assert_equal %!Element.remove("person");\nnew Effect.Highlight(\"project-4\",{});!, @response.body
  end

  def test_render_rjs_template_explicitly
    get :render_js_with_explicit_template
    assert_equal %!Element.remove("person");\nnew Effect.Highlight(\"project-4\",{});!, @response.body
  end

  def test_rendering_rjs_action_explicitly
    get :render_js_with_explicit_action_template
    assert_equal %!Element.remove("person");\nnew Effect.Highlight(\"project-4\",{});!, @response.body
  end

  def test_layout_rendering
    get :layout_test
    assert_equal "<html>Hello world!</html>", @response.body
  end

  def test_layout_test_with_different_layout
    get :layout_test_with_different_layout
    assert_equal "<html>Hello world!</html>", @response.body
  end

  def test_rendering_without_layout
    get :rendering_without_layout
    assert_equal "Hello world!", @response.body
  end

  def test_layout_overriding_layout
    get :layout_overriding_layout
    assert_no_match %r{<title>}, @response.body
  end

  def test_rendering_nothing_on_layout
    get :rendering_nothing_on_layout
    assert_equal " ", @response.body
  end

  def test_render_xml_with_layouts
    get :builder_layout_test
    assert_equal "<wrapper>\n<html>\n  <p>Hello </p>\n<p>This is grand!</p>\n</html>\n</wrapper>\n", @response.body
  end

  def test_partial_only
    get :partial_only
    assert_equal "only partial", @response.body
  end

  def test_partial_only_with_layout
    get :partial_only_with_layout
    assert_equal "<html>only partial</html>", @response.body
  end

  def test_render_to_string
    assert_not_deprecated { get :hello_in_a_string }
    assert_equal "How's there? goodbyeHello: davidHello: marygoodbye\n", @response.body
  end
  
  def test_render_to_string_doesnt_break_assigns
    get :render_to_string_with_assigns
    assert_equal "i'm before the render", assigns(:before)
    assert_equal "i'm after the render", assigns(:after)
  end

  def test_render_to_string_partial
    get :render_to_string_with_partial
    assert_equal "only partial", assigns(:partial_only)
    assert_equal "Hello: david", assigns(:partial_with_locals)
  end  

  def test_bad_render_to_string_still_throws_exception
    assert_raises(ActionController::MissingTemplate) { get :render_to_string_with_exception }
  end
  
  def test_render_to_string_that_throws_caught_exception_doesnt_break_assigns
    assert_nothing_raised { get :render_to_string_with_caught_exception }
    assert_equal "i'm before the render", assigns(:before)
    assert_equal "i'm after the render", assigns(:after)
  end

  def test_nested_rendering
    get :hello_world
    assert_equal "Living in a nested world", Fun::GamesController.process(@request, @response).body
  end

  def test_accessing_params_in_template
    get :accessing_params_in_template, :name => "David"
    assert_equal "Hello: David", @response.body
  end

  def test_accessing_params_in_template_with_layout
    get :accessing_params_in_template_with_layout, :name => "David"
    assert_equal "<html>Hello: David</html>", @response.body
  end

  def test_render_with_explicit_template
    assert_deprecated(/render/) { get :render_with_explicit_template }
    assert_response :success
  end

  def test_double_render
    assert_raises(ActionController::DoubleRenderError) { get :double_render }
  end

  def test_double_redirect
    assert_raises(ActionController::DoubleRenderError) { get :double_redirect }
  end

  def test_render_and_redirect
    assert_raises(ActionController::DoubleRenderError) { get :render_and_redirect }
  end
  
  # specify the one exception to double render rule - render_to_string followed by render
  def test_render_to_string_and_render
    get :render_to_string_and_render
    assert_equal("Hi web users! here is some cached stuff", @response.body)
  end

  def test_rendering_with_conflicting_local_vars
    get :rendering_with_conflicting_local_vars
    assert_equal("First: David\nSecond: Stephan\nThird: David\nFourth: David\nFifth: ", @response.body)
  end

  def test_action_talk_to_layout
    get :action_talk_to_layout
    assert_equal "<title>Talking to the layout</title>\nAction was here!", @response.body
  end

  def test_partials_list
    get :partials_list
    assert_equal "goodbyeHello: davidHello: marygoodbye\n", @response.body
  end
  
  def test_partial_with_locals
    get :partial_with_locals
    assert_equal "Hello: david", @response.body
  end

  def test_partial_collection
    get :partial_collection
    assert_equal "Hello: davidHello: mary", @response.body
  end

  def test_partial_collection_with_locals
    get :partial_collection_with_locals
    assert_equal "Bonjour: davidBonjour: mary", @response.body
  end

  def test_empty_partial_collection
    get :empty_partial_collection
    assert_equal " ", @response.body
  end

  def test_partial_with_hash_object
    get :partial_with_hash_object
    assert_equal "Sam", @response.body
  end

  def test_partial_with_implicit_local_assignment
    get :partial_with_implicit_local_assignment
    assert_equal "Hello: Marcel", @response.body
  end
  
  def test_render_text_with_assigns
    get :render_text_with_assigns
    assert_equal "world", assigns["hello"]
  end
  
  def test_update_page
    get :update_page
    assert_template nil
    assert_equal 'text/javascript; charset=utf-8', @response.headers['Content-Type']
    assert_equal 2, @response.body.split($/).length
  end
  
  def test_update_page_with_instance_variables
    get :update_page_with_instance_variables
    assert_template nil
    assert_equal 'text/javascript; charset=utf-8', @response.headers['Content-Type']
    assert_match /balance/, @response.body
    assert_match /\$37/, @response.body
  end
  
  def test_yield_content_for
    assert_not_deprecated { get :yield_content_for }
    assert_equal "<title>Putting stuff in the title!</title>\n\nGreat stuff!\n", @response.body
  end


  def test_overwritting_rendering_relative_file_with_extension
    get :hello_world_from_rxml_using_template
    assert_equal "<html>\n  <p>Hello</p>\n</html>\n", @response.body

    get :hello_world_from_rxml_using_action
    assert_equal "<html>\n  <p>Hello</p>\n</html>\n", @response.body
  end


  def test_head_with_location_header
    get :head_with_location_header
    assert @response.body.blank?
    assert_equal "/foo", @response.headers["Location"]
    assert_response :ok
  end

  def test_head_with_custom_header
    get :head_with_custom_header
    assert @response.body.blank?
    assert_equal "something", @response.headers["X-Custom-Header"]
    assert_response :ok
  end

  def test_head_with_symbolic_status
    get :head_with_symbolic_status, :status => "ok"
    assert_equal "200 OK", @response.headers["Status"]
    assert_response :ok

    get :head_with_symbolic_status, :status => "not_found"
    assert_equal "404 Not Found", @response.headers["Status"]
    assert_response :not_found

    ActionController::StatusCodes::SYMBOL_TO_STATUS_CODE.each do |status, code|
      get :head_with_symbolic_status, :status => status.to_s
      assert_equal code, @response.response_code
      assert_response status
    end
  end

  def test_head_with_integer_status
    ActionController::StatusCodes::STATUS_CODES.each do |code, message|
      get :head_with_integer_status, :status => code.to_s
      assert_equal message, @response.message
    end
  end

  def test_head_with_string_status
    get :head_with_string_status, :status => "404 Eat Dirt"
    assert_equal 404, @response.response_code
    assert_equal "Eat Dirt", @response.message
    assert_response :not_found
  end

  def test_head_with_status_code_first
    get :head_with_status_code_first
    assert_equal 403, @response.response_code
    assert_equal "Forbidden", @response.message
    assert_equal "something", @response.headers["X-Custom-Header"]
    assert_response :forbidden
  end
end
