require File.dirname(__FILE__) + '/../abstract_unit'
require File.dirname(__FILE__) + '/fake_controllers'

class TestTest < Test::Unit::TestCase
  class TestController < ActionController::Base
    def set_flash
      flash["test"] = ">#{flash["test"]}<"
      render :text => 'ignore me'
    end

    def render_raw_post
      raise Test::Unit::AssertionFailedError, "#raw_post is blank" if request.raw_post.blank?
      render :text => request.raw_post
    end

    def test_params
      render :text => params.inspect
    end

    def test_uri
      render :text => request.request_uri
    end

    def test_html_output
      render :text => <<HTML
<html>
  <body>
    <a href="/"><img src="/images/button.png" /></a>
    <div id="foo">
      <ul>
        <li class="item">hello</li>
        <li class="item">goodbye</li>
      </ul>
    </div>
    <div id="bar">
      <form action="/somewhere">
        Name: <input type="text" name="person[name]" id="person_name" />
      </form>
    </div>
  </body>
</html>
HTML
    end

    def test_only_one_param
      render :text => (params[:left] && params[:right]) ? "EEP, Both here!" : "OK"
    end

    def test_remote_addr
      render :text => (request.remote_addr || "not specified")
    end

    def test_file_upload
      render :text => params[:file].size
    end

    def redirect_to_symbol
      redirect_to :generate_url, :id => 5
    end

    def redirect_to_same_controller
      redirect_to :controller => 'test', :action => 'test_uri', :id => 5
    end

    def redirect_to_different_controller
      redirect_to :controller => 'fail', :id => 5
    end

    def create
      headers['Location'] = 'created resource'
      head :created
    end

    private
      def rescue_action(e)
        raise e
      end

      def generate_url(opts)
        url_for(opts.merge(:action => "test_uri"))
      end
  end

  def setup
    @controller = TestController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    ActionController::Routing::Routes.reload
    ActionController::Routing.use_controllers! %w(content admin/user test_test/test)
  end

  def teardown
    ActionController::Routing::Routes.reload
  end

  def test_raw_post_handling
    params = {:page => {:name => 'page name'}, 'some key' => 123}
    get :render_raw_post, params.dup

    raw_post = params.map {|k,v| [CGI::escape(k.to_s), CGI::escape(v.to_s)].join('=')}.sort.join('&')
    assert_equal raw_post, @response.body
  end

  def test_process_without_flash
    process :set_flash
    assert_equal '><', flash['test']
  end

  def test_process_with_flash
    process :set_flash, nil, nil, { "test" => "value" }
    assert_equal '>value<', flash['test']
  end

  def test_process_with_request_uri_with_no_params
    process :test_uri
    assert_equal "/test_test/test/test_uri", @response.body
  end

  def test_process_with_request_uri_with_params
    process :test_uri, :id => 7
    assert_equal "/test_test/test/test_uri/7", @response.body
  end

  def test_process_with_request_uri_with_params_with_explicit_uri
    @request.set_REQUEST_URI "/explicit/uri"
    process :test_uri, :id => 7
    assert_equal "/explicit/uri", @response.body
  end

  def test_multiple_calls
    process :test_only_one_param, :left => true
    assert_equal "OK", @response.body
    process :test_only_one_param, :right => true
    assert_equal "OK", @response.body
  end

  def test_assert_tag_tag
    process :test_html_output

    # there is a 'form' tag
    assert_tag :tag => 'form'
    # there is not an 'hr' tag
    assert_no_tag :tag => 'hr'
  end

  def test_assert_tag_attributes
    process :test_html_output

    # there is a tag with an 'id' of 'bar'
    assert_tag :attributes => { :id => "bar" }
    # there is no tag with a 'name' of 'baz'
    assert_no_tag :attributes => { :name => "baz" }
  end

  def test_assert_tag_parent
    process :test_html_output

    # there is a tag with a parent 'form' tag
    assert_tag :parent => { :tag => "form" }
    # there is no tag with a parent of 'input'
    assert_no_tag :parent => { :tag => "input" }
  end

  def test_assert_tag_child
    process :test_html_output

    # there is a tag with a child 'input' tag
    assert_tag :child => { :tag => "input" }
    # there is no tag with a child 'strong' tag
    assert_no_tag :child => { :tag => "strong" }
  end

  def test_assert_tag_ancestor
    process :test_html_output

    # there is a 'li' tag with an ancestor having an id of 'foo'
    assert_tag :ancestor => { :attributes => { :id => "foo" } }, :tag => "li"
    # there is no tag of any kind with an ancestor having an href matching 'foo'
    assert_no_tag :ancestor => { :attributes => { :href => /foo/ } }
  end

  def test_assert_tag_descendant
    process :test_html_output

    # there is a tag with a decendant 'li' tag
    assert_tag :descendant => { :tag => "li" }
    # there is no tag with a descendant 'html' tag
    assert_no_tag :descendant => { :tag => "html" }
  end

  def test_assert_tag_sibling
    process :test_html_output

    # there is a tag with a sibling of class 'item'
    assert_tag :sibling => { :attributes => { :class => "item" } }
    # there is no tag with a sibling 'ul' tag
    assert_no_tag :sibling => { :tag => "ul" }
  end

  def test_assert_tag_after
    process :test_html_output

    # there is a tag following a sibling 'div' tag
    assert_tag :after => { :tag => "div" }
    # there is no tag following a sibling tag with id 'bar'
    assert_no_tag :after => { :attributes => { :id => "bar" } }
  end

  def test_assert_tag_before
    process :test_html_output

    # there is a tag preceeding a tag with id 'bar'
    assert_tag :before => { :attributes => { :id => "bar" } }
    # there is no tag preceeding a 'form' tag
    assert_no_tag :before => { :tag => "form" }
  end

  def test_assert_tag_children_count
    process :test_html_output

    # there is a tag with 2 children
    assert_tag :children => { :count => 2 }
    # in particular, there is a <ul> tag with two children (a nameless pair of <li>s)
    assert_tag :tag => 'ul', :children => { :count => 2 }
    # there is no tag with 4 children
    assert_no_tag :children => { :count => 4 }
  end

  def test_assert_tag_children_less_than
    process :test_html_output

    # there is a tag with less than 5 children
    assert_tag :children => { :less_than => 5 }
    # there is no 'ul' tag with less than 2 children
    assert_no_tag :children => { :less_than => 2 }, :tag => "ul"
  end

  def test_assert_tag_children_greater_than
    process :test_html_output

    # there is a 'body' tag with more than 1 children
    assert_tag :children => { :greater_than => 1 }, :tag => "body"
    # there is no tag with more than 10 children
    assert_no_tag :children => { :greater_than => 10 }
  end

  def test_assert_tag_children_only
    process :test_html_output

    # there is a tag containing only one child with an id of 'foo'
    assert_tag :children => { :count => 1,
                              :only => { :attributes => { :id => "foo" } } }
    # there is no tag containing only one 'li' child
    assert_no_tag :children => { :count => 1, :only => { :tag => "li" } }
  end

  def test_assert_tag_content
    process :test_html_output

    # the output contains the string "Name"
    assert_tag :content => /Name/
    # the output does not contain the string "test"
    assert_no_tag :content => /test/
  end

  def test_assert_tag_multiple
    process :test_html_output

    # there is a 'div', id='bar', with an immediate child whose 'action'
    # attribute matches the regexp /somewhere/.
    assert_tag :tag => "div", :attributes => { :id => "bar" },
               :child => { :attributes => { :action => /somewhere/ } }

    # there is no 'div', id='foo', with a 'ul' child with more than
    # 2 "li" children.
    assert_no_tag :tag => "div", :attributes => { :id => "foo" },
                  :child => {
                    :tag => "ul",
                    :children => { :greater_than => 2,
                                   :only => { :tag => "li" } } }
  end

  def test_assert_tag_children_without_content
    process :test_html_output

    # there is a form tag with an 'input' child which is a self closing tag
    assert_tag :tag => "form",
      :children => { :count => 1,
        :only => { :tag => "input" } }

    # the body tag has an 'a' child which in turn has an 'img' child
    assert_tag :tag => "body",
      :children => { :count => 1,
        :only => { :tag => "a",
          :children => { :count => 1,
            :only => { :tag => "img" } } } }
  end

  def test_assert_tag_attribute_matching
    @response.body = '<input type="text" name="my_name">'
    assert_tag :tag => 'input',
                 :attributes => { :name => /my/, :type => 'text' }
    assert_no_tag :tag => 'input',
                 :attributes => { :name => 'my', :type => 'text' }
    assert_no_tag :tag => 'input',
                 :attributes => { :name => /^my$/, :type => 'text' }
  end

  def test_assert_tag_content_matching
    @response.body = "<p>hello world</p>"
    assert_tag :tag => "p", :content => "hello world"
    assert_tag :tag => "p", :content => /hello/
    assert_no_tag :tag => "p", :content => "hello"
  end

  def test_assert_generates
    assert_generates 'controller/action/5', :controller => 'controller', :action => 'action', :id => '5'
    assert_generates 'controller/action/7', {:id => "7"}, {:controller => "controller", :action => "action"}
    assert_generates 'controller/action/5', {:controller => "controller", :action => "action", :id => "5", :name => "bob"}, {}, {:name => "bob"}
    assert_generates 'controller/action/7', {:id => "7", :name => "bob"}, {:controller => "controller", :action => "action"}, {:name => "bob"}
    assert_generates 'controller/action/7', {:id => "7"}, {:controller => "controller", :action => "action", :name => "bob"}, {}
  end

  def test_assert_routing
    assert_routing 'content', :controller => 'content', :action => 'index'
  end

  def test_assert_routing_in_module
    assert_routing 'admin/user', :controller => 'admin/user', :action => 'index'
  end

  def test_params_passing
    get :test_params, :page => {:name => "Page name", :month => '4', :year => '2004', :day => '6'}
    parsed_params = eval(@response.body)
    assert_equal(
      {'controller' => 'test_test/test', 'action' => 'test_params',
       'page' => {'name' => "Page name", 'month' => '4', 'year' => '2004', 'day' => '6'}},
      parsed_params
    )
  end

  def test_id_converted_to_string
    get :test_params, :id => 20, :foo => Object.new
    assert_kind_of String, @request.path_parameters['id']
  end

  def test_array_path_parameter_handled_properly
    with_routing do |set|
      set.draw do |map|
        map.connect 'file/*path', :controller => 'test_test/test', :action => 'test_params'
        map.connect ':controller/:action/:id'
      end

      get :test_params, :path => ['hello', 'world']
      assert_equal ['hello', 'world'], @request.path_parameters['path']
      assert_equal 'hello/world', @request.path_parameters['path'].to_s
    end
  end

  def test_assert_realistic_path_parameters
    get :test_params, :id => 20, :foo => Object.new

    # All elements of path_parameters should use string keys
    @request.path_parameters.keys.each do |key|
      assert_kind_of String, key
    end
  end

  def test_with_routing_places_routes_back
    assert ActionController::Routing::Routes
    routes_id = ActionController::Routing::Routes.object_id

    begin
      with_routing { raise 'fail' }
      fail 'Should not be here.'
    rescue RuntimeError
    end

    assert ActionController::Routing::Routes
    assert_equal routes_id, ActionController::Routing::Routes.object_id
  end

  def test_remote_addr
    get :test_remote_addr
    assert_equal "0.0.0.0", @response.body

    @request.remote_addr = "192.0.0.1"
    get :test_remote_addr
    assert_equal "192.0.0.1", @response.body
  end

  def test_header_properly_reset_after_remote_http_request
    xhr :get, :test_params
    assert_nil @request.env['HTTP_X_REQUESTED_WITH']
  end

   def test_header_properly_reset_after_get_request
    get :test_params
    @request.recycle!
    assert_nil @request.instance_variable_get("@request_method")
  end

  %w(controller response request).each do |variable|
    %w(get post put delete head process).each do |method|
      define_method("test_#{variable}_missing_for_#{method}_raises_error") do
        remove_instance_variable "@#{variable}"
        begin
          send(method, :test_remote_addr)
          assert false, "expected RuntimeError, got nothing"
        rescue RuntimeError => error
          assert true
          assert_match %r{@#{variable} is nil}, error.message
        rescue => error
          assert false, "expected RuntimeError, got #{error.class}"
        end
      end
    end
  end

  FILES_DIR = File.dirname(__FILE__) + '/../fixtures/multipart'

  def test_test_uploaded_file
    filename = 'mona_lisa.jpg'
    path = "#{FILES_DIR}/#{filename}"
    content_type = 'image/png'

    file = ActionController::TestUploadedFile.new(path, content_type)
    assert_equal filename, file.original_filename
    assert_equal content_type, file.content_type
    assert_equal file.path, file.local_path
    assert_equal File.read(path), file.read
  end

  def test_fixture_file_upload
    post :test_file_upload, :file => fixture_file_upload(FILES_DIR + "/mona_lisa.jpg", "image/jpg")
    assert_equal 159528, @response.body
  end

  def test_test_uploaded_file_exception_when_file_doesnt_exist
    assert_raise(RuntimeError) { ActionController::TestUploadedFile.new('non_existent_file') }
  end

  def test_assert_redirected_to_symbol
    with_foo_routing do |set|
      assert_deprecated(/generate_url.*redirect_to/) do
        get :redirect_to_symbol
      end
      assert_response :redirect
      assert_redirected_to :generate_url
    end
  end

  def test_assert_follow_redirect_to_same_controller
    with_foo_routing do |set|
      get :redirect_to_same_controller
      assert_response :redirect
      assert_redirected_to :controller => 'test_test/test', :action => 'test_uri', :id => 5
      assert_nothing_raised { follow_redirect }
    end
  end

  def test_assert_follow_redirect_to_different_controller
    with_foo_routing do |set|
      get :redirect_to_different_controller
      assert_response :redirect
      assert_redirected_to :controller => 'fail', :id => 5
      assert_raise(RuntimeError) { follow_redirect }
    end
  end

  def test_redirect_url_only_cares_about_location_header
    get :create
    assert_response :created

    # Redirect url doesn't care that it wasn't a :redirect response.
    assert_equal 'created resource', @response.redirect_url
    assert_equal @response.redirect_url, redirect_to_url

    # Must be a :redirect response.
    assert_raise(Test::Unit::AssertionFailedError) do
      assert_redirected_to 'created resource'
    end
  end

  protected
    def with_foo_routing
      with_routing do |set|
        set.draw do |map|
          map.generate_url 'foo', :controller => 'test'
          map.connect      ':controller/:action/:id'
        end
        yield set
      end
    end
end
