# blanky.rb
# from Adrian Titus


# Delete unnecessary files
  run "rm README"
  run "rm public/index.html"
  run "rm public/favicon.ico"
  run "rm public/robots.txt"

# Set up git repository
  git :init
  
  # download the yahoo css reset
  run "curl -L http://yui.yahooapis.com/2.8.0r4/build/reset/reset-min.css > public/stylesheets/reset.css"
  
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
  config.gem "haml"
  config.gem "rspec", :lib => false, :version => ">= 1.2.0"
  config.gem "rspec-rails", :lib => false, :version => ">= 1.2.0"
  config.gem "cucumber"
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
  file 'app/views/static/index.haml',
  %q{%h1="Static"
  }
  
  file 'app/views/layouts/application.haml',
  %q{%html
  %head
    =stylesheet_link_tag "reset.css"
    =stylesheet_link_tag "main.css"
    =javascript_include_tag :defaults
  %body
    =yield
  }
  
  file 'config/routes.rb',
  %q{ActionController::Routing::Routes.draw do |map|

  map.root :controller => "static", :action => "index"

  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
  }
  
  file 'public/stylesheets/main.css',
  %q{}

# Initialize submodules
  git :submodule => "init"

# Commit all work so far to the repository
  git :add => '.'
  git :commit => "-a -m 'Initial commit'"

# Success!
  puts "SUCCESS!"