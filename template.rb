require "fileutils"

# Copied from: https://github.com/mattbrictson/rails-template
# Add this template directory to source_paths so that Thor actions like
# copy_file and template resolve against our source files. If this file was
# invoked remotely via HTTP, that means the files are not present locally.
# In that case, use `git clone` to download them to a local temporary dir.
def add_template_repository_to_source_path
  if __FILE__ =~ %r{\Ahttps?://}
    require "tmpdir"
    source_paths.unshift(tempdir = Dir.mktmpdir("jumpstart-"))
    at_exit { FileUtils.remove_entry(tempdir) }
    git clone: [
      "--quiet",
      "https://github.com/excid3/jumpstart.git",
      tempdir
    ].map(&:shellescape).join(" ")

    if (branch = __FILE__[%r{jumpstart/(.+)/template.rb}, 1])
      Dir.chdir(tempdir) { git checkout: branch }
    end
  else
    source_paths.unshift(File.dirname(__FILE__))
  end
end

def add_gems
  gem "jquery-rails"
  gem 'devise'
  gem 'slim'
  gem "figaro"
  gem 'money-rails'
  # gem 'unique_numbers', :git => "https://github.com/martinbeck/unique_numbers.git"
  gem 'stripe'
  gem "letter_opener", :group => :development
  gem 'paperclip', '~> 5.2.0'
  gem 'aws-sdk', '~> 2.3'
  gem "acts_as_hashids"
  gem 'kaminari'
  gem 'ransack'
  gem 'redcarpet'
  gem 'friendly_id', '~> 5.2.0'
  gem 'pg', :group => :production
  gem 'bullet', group: 'development'
  gem 'sidekiq'
  gem 'obscenity'
  gem 'html2slim'
  gem 'sitemap_generator', '~> 6.0', '>= 6.0.1'
end

def set_application_name
  # Add Application Name to Config
  environment "config.application_name = Rails.application.class.parent_name"

  # Announce the user where he can change the application name in the future.
  puts "You can change application name inside: ./config/application.rb"
end

def install_devise
  # Install Devise
  generate "devise:install"

  # Configure Devise
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
              env: 'development'

  generate "devise:views"

  # Create Devise User
  generate :devise, "User", "name"

end

def convert_slim

  #convert layout views to slim
  run "erb2slim -d app/views/layouts/"

  #convert devise views to slim
  run "for file in app/views/devise/**/*.erb; do erb2slim $file ${file%erb}slim && rm $file; done"

end

def add_friendly_id
  generate "friendly_id"

  insert_into_file(
    Dir["db/migrate/**/*friendly_id_slugs.rb"].first,
    "[5.2]",
    after: "ActiveRecord::Migration"
  )
end

def add_sitemap
  rails_command "sitemap:install"
end

# Main setup

add_template_repository_to_source_path

add_gems

after_bundle do
  install_devise
  convert_slim
  add_friendly_id

  # Migrate
  rails_command "db:create"
  rails_command "db:migrate"

  # Migrations must be done before this
  add_sitemap

  route "root to: 'home#index'"

  directory "app", force: true
  directory "config", force: true
  directory "vendor", force: true

  git :init
  git add: "."
  git commit: %Q{ -m 'Initial commit' }
end