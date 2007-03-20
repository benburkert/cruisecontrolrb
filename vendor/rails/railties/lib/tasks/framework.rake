namespace :rails do
  namespace :freeze do
    desc "Lock this application to the current gems (by unpacking them into vendor/rails)"
    task :gems do
      deps = %w(actionpack activerecord actionmailer activesupport actionwebservice)
      require 'rubygems'
      Gem.manage_gems

      rails = (version = ENV['VERSION']) ?
        Gem.cache.search('rails', "= #{version}").first :
        Gem.cache.search('rails').sort_by { |g| g.version }.last

      version ||= rails.version

      unless rails
        puts "No rails gem #{version} is installed.  Do 'gem list rails' to see what you have available."
        exit
      end

      puts "Freezing to the gems for Rails #{rails.version}"
      rm_rf   "vendor/rails"
      mkdir_p "vendor/rails"

      chdir("vendor/rails") do
        rails.dependencies.select { |g| deps.include? g.name }.each do |g|
          Gem::GemRunner.new.run(["unpack", "-v", "#{g.version_requirements}", "#{g.name}"])
          mv(Dir.glob("#{g.name}*").first, g.name)
        end

        Gem::GemRunner.new.run(["unpack", "-v", "=#{version}", "rails"])
        FileUtils.mv(Dir.glob("rails*").first, "railties")
      end
    end

    desc "Lock to latest Edge Rails or a specific revision with REVISION=X (ex: REVISION=4021) or a tag with TAG=Y (ex: TAG=rel_1-1-0)"
    task :edge do
      $verbose = false
      `svn --version` rescue nil
      unless !$?.nil? && $?.success?
        $stderr.puts "ERROR: Must have subversion (svn) available in the PATH to lock this application to Edge Rails"
        exit 1
      end
            
      rm_rf   "vendor/rails"
      mkdir_p "vendor/rails"
      
      svn_root = "http://dev.rubyonrails.org/svn/rails/"

      if ENV['TAG']
        rails_svn = "#{svn_root}/tags/#{ENV['TAG']}"
        touch "vendor/rails/TAG_#{ENV['TAG']}"
      else
        rails_svn = "#{svn_root}/trunk"

        if ENV['REVISION'].nil?
          ENV['REVISION'] = /^r(\d+)/.match(%x{svn -qr HEAD log #{svn_root}})[1]
          puts "REVISION not set. Using HEAD, which is revision #{ENV['REVISION']}."
        end

        touch "vendor/rails/REVISION_#{ENV['REVISION']}"
      end
      
      for framework in %w( railties actionpack activerecord actionmailer activesupport actionwebservice )
        system "svn export #{rails_svn}/#{framework} vendor/rails/#{framework}" + (ENV['REVISION'] ? " -r #{ENV['REVISION']}" : "")
      end
    end
  end

  desc "Unlock this application from freeze of gems or edge and return to a fluid use of system gems"
  task :unfreeze do
    rm_rf "vendor/rails"
  end

  desc "Update both configs, scripts and public/javascripts from Rails"
  task :update => [ "update:scripts", "update:javascripts", "update:configs" ]

  namespace :update do
    desc "Add new scripts to the application script/ directory"
    task :scripts do
      local_base = "script"
      edge_base  = "#{File.dirname(__FILE__)}/../../bin"

      local = Dir["#{local_base}/**/*"].reject { |path| File.directory?(path) }
      edge  = Dir["#{edge_base}/**/*"].reject { |path| File.directory?(path) }
  
      edge.each do |script|
        base_name = script[(edge_base.length+1)..-1]
        next if base_name == "rails"
        next if local.detect { |path| base_name == path[(local_base.length+1)..-1] }
        if !File.directory?("#{local_base}/#{File.dirname(base_name)}")
          mkdir_p "#{local_base}/#{File.dirname(base_name)}"
        end
        install script, "#{local_base}/#{base_name}", :mode => 0755
      end
    end

    desc "Update your javascripts from your current rails install"
    task :javascripts do
      require 'railties_path'  
      project_dir = RAILS_ROOT + '/public/javascripts/'
      scripts = Dir[RAILTIES_PATH + '/html/javascripts/*.js']
      scripts.reject!{|s| File.basename(s) == 'application.js'} if File.exists?(project_dir + 'application.js')
      FileUtils.cp(scripts, project_dir)
    end

    desc "Update config/boot.rb from your current rails install"
    task :configs do
      require 'railties_path'  
      FileUtils.cp(RAILTIES_PATH + '/environments/boot.rb', RAILS_ROOT + '/config/boot.rb')
    end
  end
end
