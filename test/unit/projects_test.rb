require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ProjectsTest < Test::Unit::TestCase
  include FileSandbox

  def setup
    @svn = FakeSourceControl.new("bob")
    @one = Project.new("one", @svn)
    @two = Project.new("two", @svn)
  end

  def test_load_all
    in_sandbox do |sandbox|
      sandbox.new :file => "one/cruise_config.rb", :with_content => ""
      sandbox.new :file => "two/cruise_config.rb", :with_content => ""

      projects = Projects.new(sandbox.root)
      projects.load_all

      assert_equal %w(one two), projects.map(&:name)
    end
  end

  def test_should_always_reload_project_objects
    in_sandbox do |sandbox|
      sandbox.new :file => "one/cruise_config.rb", :with_content => ""
      sandbox.new :file => "two/cruise_config.rb", :with_content => ""

      projects = Projects.new(sandbox.root)
      old_projects = projects.load_all
      old_project_one = Project.read("#{sandbox.root}/one", false)
      
      sandbox.new :file => "three/cruise_config.rb", :with_content => ""
      projects = Projects.new(sandbox.root)
      current_projects = projects.load_all
      current_project_one = Project.read("#{sandbox.root}/one", false)
      
      assert_not_equal old_projects, current_projects
      assert_not_same old_project_one, current_project_one
    end
  end

  def test_add
    in_sandbox do |sandbox|
      projects = Projects.new(sandbox.root)
      projects << @one << @two

      projects = Projects.new(sandbox.root)
      projects.load_all

      assert_equal %w(one two), projects.map(&:name)
    end
  end

  def test_add_checks_out_fresh_project
    in_sandbox do |sandbox|
      projects = Projects.new(sandbox.root)

      projects << @one

      assert SandboxFile.new('one/work').exists?
      assert SandboxFile.new('one/work/README').exists?
    end
  end

  def test_add_cleans_up_after_itself_if_svn_throws_exception
    in_sandbox do |sandbox|
      projects = Projects.new(sandbox.root)
      @svn.expects(:checkout).raises("svn error")

      assert_raises('svn error') do
        projects << @one
      end

      assert_false SandboxFile.new('one/work').exists?
      assert_false SandboxFile.new('one').exists?
    end
  end

  def test_can_not_add_project_with_same_name
    in_sandbox do |sandbox|
      projects = Projects.new(sandbox.root)
      projects << @one      
      assert_raises('project named "one" already exists') do
        projects << @one        
      end
      assert File.directory?(@one.path), "Project directory does not exist."
    end
  end

  def test_load_project
    in_sandbox do |sandbox|
      sandbox.new :file => 'one/cruise_config.rb', :with_content => ''

      new_project = Projects.load_project(File.join(sandbox.root, 'one'))

      assert_equal('one', new_project.name)
      assert_equal(File.join(sandbox.root, 'one'), new_project.path)
    end
  end

  def test_load_project_with_no_config
    in_sandbox do |sandbox|
      sandbox.new :directory => "myproject/builds-1"

      new_project = Projects.load_project(sandbox.root + '/myproject')

      assert_equal("myproject", new_project.name)
      assert_equal(Subversion, new_project.source_control.class)
      assert_equal(sandbox.root + "/myproject", new_project.path)
    end
  end

  def test_each
    in_sandbox do |sandbox|
      projects = Projects.new(sandbox.root)
      projects << @one << @two

      out = ""
      projects.each do |project|
        out << project.name
      end

      assert_equal("onetwo", out)
    end
  end
end