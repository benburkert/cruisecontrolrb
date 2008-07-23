require 'rubygems'
require 'grit'

class GitRevision < Revision
  attr_accessor :commit,:message
  
  def initialize(commit)
    @commit = commit
  end
  
  def number
    @commit.id_abbrev
  end
  
  def committed_by
    @commit.author
  end
  
	def committed_by
    @commit.committer
	end

  def time
    @commit.authored_date
  end
  
end

class Git
  include Grit
  include CommandLine
  
  attr_accessor :url, :path, :username, :password, :branch, :project
  
  def initialize(options = {})
    @url = options.delete(:url)
    @path = options.delete(:path) || "."
    @username = options.delete(:username)
    @password = options.delete(:password)
    @interactive = options.delete(:interactive)
    @error_log = options.delete(:error_log)
    @branch = options.delete(:branch) || "master"
    @repository = options.delete(:repository) || "origin"
    @include_submodules = true
  end
  
  def repo
    @repo ||= Repo.new("#{path}/.git")
  end
  
  def latest_revision
    revision = GitRevision.new(repo.commits(@branch).first)
    build = Build.new(@project,revision.number)
    last_build = @project.last_complete_build || build
    revision.message = repo.git.log({},"--pretty=oneline --abbrev-commit  #{last_build.revision}..#{build.revision}")
    revision
  end

  def update_origin
    repo.git.remote({}, "update")
    repo.git.log({}, "HEAD..origin/#{@branch}").strip
  end
  
  def reset_from_remote
    Dir.chdir(path) do
      repo.git.reset({}, "--hard", "origin/#{@branch}")
      if @include_submodules
        repo.git.submodule({},'update')
      end
    end
  end
  
  def update(revision = nil)
    update_origin
    reset_from_remote
  end
  
  def up_to_date?(reasons = [], revision_number = latest_revision.number)
    return true if update_origin.empty?
    reset_from_remote
#    reasons << "New revision #{latest_revision.number} detected"
    reasons << latest_revision
    false
  end
  
  def checkout
    return clone unless File.exists?("#{path}/.git")
  end
  
  def clone(stdout = $stdout)
    FileUtils.rm_rf(path) if File.exists?(@path)
    git("clone", [@url, @path], :execute_locally => false)
    if @include_submodules
        git("submodule",["init"])
        git("submodule",["update"])
    end
  end
  
  def git(operation, arguments, options = {}, &block)
    command = ["git"]
    command << operation
    command += arguments.compact
    command
    
    execute_in_local_copy(command, options, &block)
  end
  
  def execute_in_local_copy(command, options, &block)
    if block_given?
      execute(command, &block)
    else
      error_log = File.expand_path(self.error_log)
      if options[:execute_locally] != false
        Dir.chdir(path) do
          execute_with_error_log(command, error_log)
        end
      else
        execute_with_error_log(command, error_log)
      end
    end
  end
  
  def execute_with_error_log(command, error_log)
    FileUtils.rm_f(error_log)
    FileUtils.touch(error_log)
    execute(command, :stderr => error_log) do |io| 
      result = io.readlines 
      begin 
        error_message = File.open(error_log){|f|f.read}.strip.split("\n")[1] || ""
      rescue
        error_message = ""
      ensure
        FileUtils.rm_f(error_log)
      end
      raise BuilderError.new(error_message, "git_error") unless error_message.empty?
      return result
    end
  end
  
  def error_log
    @error_log ? @error_log : File.join(@path, "..", "git.err")
  end
end
