# blanky.rb
# from Adrian Titus


# Delete unnecessary files
  run "rm README"
  run "rm public/index.html"
  run "rm public/favicon.ico"
  run "rm public/robots.txt"
  run "rm -f public/javascripts/*"

# Download JQuery
  run "curl -L http://jqueryjs.googlecode.com/files/jquery-1.2.6.min.js > public/javascripts/jquery.js"
  run "curl -L http://jqueryjs.googlecode.com/svn/trunk/plugins/form/jquery.form.js > public/javascripts/jquery.form.js"

# Set up git repository
  git :init
  
# Copy database.yml for distribution use
  run "cp config/database.yml config/database.yml.example"
  
# Set up .gitignore files
run %{find . -type d -empty | xargs -I xxx touch xxx/.gitignore}
file '.gitignore', <<-END
.DS_Store
coverage/*
log/*.log
db/*.db
db/*.sqlite3
db/schema.rb
tmp/**/*
doc/api
doc/app
config/database.yml
coverage/*
END

# Install submoduled plugins
  plugin 'asset_packager', :git => 'git://github.com/sbecker/asset_packager.git', :submodule => true

# user custom environment.rb to install plugins
  file 'config/environment.rb',
  %q{# Be sure to restart your server when you modify this file

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.5' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Specify gems that this application depends on and have them installed with rake gems:install
  # config.gem "bj"
  # config.gem "hpricot", :version => '0.6', :source => "http://code.whytheluckystiff.net"
  # config.gem "sqlite3-ruby", :lib => "sqlite3"
  # config.gem "aws-s3", :lib => "aws/s3"
  config.gem "haml"
  config.gem "rspec", :lib => false, :version => ">= 1.2.0"
  config.gem "rspec-rails", :lib => false, :version => ">= 1.2.0"
  config.time_zone = 'UTC'


end
  }

  rake('gems:install', :sudo => true)
  
  run 'script/generate rspec'
  run 'haml --rails .'
  run 'script/generate rspec_controller static'

  file 'app/controllers/static_controller.rb',
  %q{class StaticController < ApplicationController
  def index
  end
end
  }
  file 'app/views/layouts/applicaton.haml',
  %q{%html
  %head
  %body
  }
  file 'config/routes.rb',
  %q{ActionController::Routing::Routes.draw do |map|

  map.root :controller => "static", :action => "index"

  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
  }

# Initialize submodules
  git :submodule => "init"

# Commit all work so far to the repository
  git :add => '.'
  git :commit => "-a -m 'Initial commit'"

# Success!
  puts "SUCCESS!"