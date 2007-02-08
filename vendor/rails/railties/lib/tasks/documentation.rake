namespace :doc do
  desc "Generate documentation for the application"
  Rake::RDocTask.new("app") { |rdoc|
    rdoc.rdoc_dir = 'doc/app'
    rdoc.title    = "Rails Application Documentation"
    rdoc.options << '--line-numbers' << '--inline-source'
    rdoc.rdoc_files.include('doc/README_FOR_APP')
    rdoc.rdoc_files.include('app/**/*.rb')
    rdoc.rdoc_files.include('lib/**/*.rb')
  }

  desc "Generate documentation for the Rails framework"
  Rake::RDocTask.new("rails") { |rdoc|
    rdoc.rdoc_dir = 'doc/api'
    rdoc.template = "#{ENV['template']}.rb" if ENV['template']
    rdoc.title    = "Rails Framework Documentation"
    rdoc.options << '--line-numbers' << '--inline-source'
    rdoc.rdoc_files.include('README')
    rdoc.rdoc_files.include('vendor/rails/railties/CHANGELOG')
    rdoc.rdoc_files.include('vendor/rails/railties/MIT-LICENSE')
    rdoc.rdoc_files.include('vendor/rails/activerecord/README')
    rdoc.rdoc_files.include('vendor/rails/activerecord/CHANGELOG')
    rdoc.rdoc_files.include('vendor/rails/activerecord/lib/active_record/**/*.rb')
    rdoc.rdoc_files.exclude('vendor/rails/activerecord/lib/active_record/vendor/*')
    rdoc.rdoc_files.include('vendor/rails/actionpack/README')
    rdoc.rdoc_files.include('vendor/rails/actionpack/CHANGELOG')
    rdoc.rdoc_files.include('vendor/rails/actionpack/lib/action_controller/**/*.rb')
    rdoc.rdoc_files.include('vendor/rails/actionpack/lib/action_view/**/*.rb')
    rdoc.rdoc_files.include('vendor/rails/actionmailer/README')
    rdoc.rdoc_files.include('vendor/rails/actionmailer/CHANGELOG')
    rdoc.rdoc_files.include('vendor/rails/actionmailer/lib/action_mailer/base.rb')
    rdoc.rdoc_files.include('vendor/rails/actionwebservice/README')
    rdoc.rdoc_files.include('vendor/rails/actionwebservice/CHANGELOG')
    rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service.rb')
    rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/*.rb')
    rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/api/*.rb')
    rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/client/*.rb')
    rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/container/*.rb')
    rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/dispatcher/*.rb')
    rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/protocol/*.rb')
    rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/support/*.rb')
    rdoc.rdoc_files.include('vendor/rails/activesupport/README')
    rdoc.rdoc_files.include('vendor/rails/activesupport/CHANGELOG')
    rdoc.rdoc_files.include('vendor/rails/activesupport/lib/active_support/**/*.rb')
  }

  plugins = FileList['vendor/plugins/**'].collect { |plugin| File.basename(plugin) }

  desc "Generate documation for all installed plugins"
  task :plugins => plugins.collect { |plugin| "doc:plugins:#{plugin}" }

  desc "Remove plugin documentation"
  task :clobber_plugins do 
    rm_rf 'doc/plugins' rescue nil
  end

  namespace :plugins do
    # Define doc tasks for each plugin
    plugins.each do |plugin|
      task(plugin => :environment) do
        plugin_base   = "vendor/plugins/#{plugin}"
        options       = []
        files         = Rake::FileList.new
        options << "-o doc/plugins/#{plugin}"
        options << "--title '#{plugin.titlecase} Plugin Documentation'"
        options << '--line-numbers' << '--inline-source'
        options << '-T html'

        files.include("#{plugin_base}/lib/**/*.rb")
        if File.exists?("#{plugin_base}/README")
          files.include("#{plugin_base}/README")    
          options << "--main '#{plugin_base}/README'"
        end
        files.include("#{plugin_base}/CHANGELOG") if File.exists?("#{plugin_base}/CHANGELOG")

        options << files.to_s

        sh %(rdoc #{options * ' '})
      end
    end
  end
end