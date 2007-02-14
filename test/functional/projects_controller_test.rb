require File.dirname(__FILE__) + '/../test_helper'
require 'projects_controller'
require 'rexml/document'
require 'rexml/xpath'
require 'changeset_log_parser'
# Re-raise errors caught by the controller.
class ProjectsController
  def rescue_action(e) raise end
end

class ProjectsControllerTest < Test::Unit::TestCase
  include FileSandbox

  def setup
    @controller = ProjectsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_index_rhtml  
    p1 = create_project_stub('one', 'success')
    p2 = create_project_stub('two', 'failed', [create_build_stub('1', 'failed')])
    Projects.expects(:load_all).returns([p1, p2])
    stub_change_set_parser
    
    get :index
    assert_response :success
    assert_equal %w(one two), assigns(:projects).map { |p| p.name }
  end
  
  def test_index_rjs
    Projects.expects(:load_all).returns([create_project_stub('one'), create_project_stub('two')])
    
    post :index, :format => 'js'

    assert_response :success
    assert_template 'index.rjs'
    assert_equal %w(one two), assigns(:projects).map { |p| p.name }
  end

  def test_index_rss
    Projects.expects(:load_all).returns([
        create_project_stub('one', 'success', [create_build_stub('10', 'success')]),
        create_project_stub('two')])

    post :index, :format => 'rss'

    assert_response :success
    assert_template 'rss'
    assert_equal %w(one two), assigns(:projects).map { |p| p.name }

    xml = REXML::Document.new(@response.body)
    assert_equal "one build 10 success", REXML::XPath.first(xml, '/rss/channel/item[1]/title').text
    assert_equal "two has never been built", REXML::XPath.first(xml, '/rss/channel/item[2]/title').text
    assert_equal "<pre>bobby checked something in</pre>", REXML::XPath.first(xml, '/rss/channel/item[1]/description').text
    assert_equal "<pre></pre>", REXML::XPath.first(xml, '/rss/channel/item[2]/description').text
  end

  def test_code
    in_sandbox do |sandbox|
      project = Project.new('three')
      project.path = sandbox.root
      sandbox.new :file => 'work/app/controller/FooController.rb', :with_contents => "class FooController\nend\n"
      
      Projects.expects(:find).returns(project)
    
      get :code, :project => 'two', :path => ['app', 'controller', 'FooController.rb'], :line => 2
      
      assert_response :success, @response.body
      assert @response.body =~ /class FooController/
    end
  end

  def test_force_build_should_request_force_build
    project = create_project_stub('two')
    Projects.expects(:find).with('two').returns(project)
    project.expects(:request_force_build)
    post :force_build, :project => "two"
    assert_response :success
    assert_equal 'two', assigns(:project).name
  end
  
  def test_force_build_should_assign_nil_if_project_not_found
    Projects.expects(:find).with('non_existing_project').raises("project not found error")
    post :force_build, :project => "non_existing_project"
    assert_response :success
    assert_equal nil, assigns(:project)
  end

  def stub_change_set_parser
    mock = Object.new  
    ChangesetLogParser.stubs(:new).returns(mock)
    mock.expects(:parse_log).returns([])
  end
end
