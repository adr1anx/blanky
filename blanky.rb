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
  config.gem "authlogic"
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
  
  file 'public/stylesheets/main.css',
  %q{}

# run authlogic generators and add basic files
  run "script/generate session user_session"
  run "script/generate rspec_model user --skip-migration"
  
  file "db/migrate/#{Time.now.strftime('%Y%m%d%H%M%S')}_create_users.rb",
  %q{class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.string    :email,               :null => false                # optional, you can use login instead, or both
      t.string    :crypted_password,    :null => false                # optional, see below
      t.string    :password_salt,       :null => false                # optional, but highly recommended
      t.string    :persistence_token,   :null => false                # required
      t.string    :single_access_token, :null => false                # optional, see Authlogic::Session::Params
      t.string    :perishable_token,    :null => false                # optional, see Authlogic::Session::Perishability

      # Magic columns, just like ActiveRecord's created_at and updated_at. These are automatically maintained by Authlogic if they are present.
      t.integer   :login_count,         :null => false, :default => 0 # optional, see Authlogic::Session::MagicColumns
      t.integer   :failed_login_count,  :null => false, :default => 0 # optional, see Authlogic::Session::MagicColumns
      t.datetime  :last_request_at                                    # optional, see Authlogic::Session::MagicColumns
      t.datetime  :current_login_at                                   # optional, see Authlogic::Session::MagicColumns
      t.datetime  :last_login_at                                      # optional, see Authlogic::Session::MagicColumns
      t.string    :current_login_ip                                   # optional, see Authlogic::Session::MagicColumns
      t.string    :last_login_ip                                      # optional, see Authlogic::Session::MagicColumns

      t.timestamps
    end
  end

  def self.down
    drop_table :users
  end
end
  }

  file 'app/models/user.rb',
  %q{class User < ActiveRecord::Base
  acts_as_authentic
end
  }
  run 'script/generate controller user_sessions'
  
  file 'config/routes.rb',
  %q{ActionController::Routing::Routes.draw do |map|

  map.resource :user_session
  map.resource :account, :controller => "users"
  map.resources :users

  map.login '/login', :controller => :user_sessions, :action => :new
  map.root :controller => "static", :action => "index"

  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'

end
  }
  
  file 'app/controllers/application_controller.rb',
  %q{# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details
  helper_method :current_user_session, :current_user
  filter_parameter_logging :password, :password_confirmation

  private
    def current_user_session
      return @current_user_session if defined?(@current_user_session)
      @current_user_session = UserSession.find
    end

    def current_user
      return @current_user if defined?(@current_user)
      @current_user = current_user_session && current_user_session.record
    end

    def require_user
      unless current_user
        store_location
        flash[:notice] = "You must be logged in to access this page"
        redirect_to new_user_session_url
        return false
      end
    end

    def require_no_user
      if current_user
        store_location
        flash[:notice] = "You must be logged out to access this page"
        redirect_to account_url
        return false
      end
    end

    def store_location
      session[:return_to] = request.request_uri
    end

    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end

end    
  }
  file 'app/controllers/user_sessions_controller.rb',
  %q{class UserSessionsController < ApplicationController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => :destroy

  def new
    @user_session = UserSession.new
  end

  def create
    @user_session = UserSession.new(params[:user_session])
    if @user_session.save
      flash[:notice] = "Login successful!"
      redirect_back_or_default account_url
    else
      render :action => :new
    end
  end

  def destroy
    current_user_session.destroy
    flash[:notice] = "Logout successful!"
    redirect_back_or_default new_user_session_url
  end

end
  }
  file 'app/controllers/users_controller.rb',
  %q{class UsersController < ApplicationController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => [:show, :edit, :update]

  def new
    @user = User.new
  end

  def create
    @user = User.new(params[:user])
    if @user.save
      flash[:notice] = "Account registered!"
      redirect_back_or_default root_url
    else
      render :action => :new
    end
  end

  def show
    @user = @current_user
  end

  def edit
    @user = @current_user
  end

  def update
    @user = @current_user # makes our views "cleaner" and more consistent
    if @user.update_attributes(params[:user])
      flash[:notice] = "Account updated!"
      redirect_to account_url
    else
      render :action => :edit
    end
  end

end
  }
  file 'app/helpers/application_helper.rb',
  %q{module ApplicationHelper
  def user_menu
    menu = []
    if current_user
      menu << link_to("Logout", user_session_path, :method => :delete)
    else
      menu << link_to("Sign Up", new_account_path)
      menu << link_to("Log In", login_path)
    end
    menu.join("|")
  end
end
  }
  file 'app/views/layouts/application.haml',
  %q{%html
  %head
    =stylesheet_link_tag "reset.css"
    =stylesheet_link_tag "main.css"
    =javascript_include_tag :defaults
  %body
    #header
      = user_menu
    #content
      =yield
  }
  file 'app/views/users/new.haml',
  %q{%h1="Sign Up"
-form_for @user, :url => account_path do |f|
  = f.error_messages
  = f.label :email
  %br/
  = f.text_field :email
  %br/
  %br/
  = f.label :password
  %br/
  = f.password_field :password
  %br/
  %br/
  = f.label :password_confirmation
  %br/
  = f.password_field :password_confirmation
  %br/
  %br/
  = f.submit "Register"
    }
    file 'app/views/user_sessions/new.haml',
    %q{%h1="Login"
-form_for @user_session, :url => user_session_path do |f|
  = f.error_messages
  = f.label :email
  %br/
  = f.text_field :email
  %br/
  %br/
  = f.label :password
  %br/
  = f.password_field :password
  %br/
  %br/
  = f.check_box :remember_me
  = f.label :remember_me
  %br/
  %br/
  = f.submit "Login"
    }
  rake("db:migrate")
# Initialize submodules
  git :submodule => "init"

# Commit all work so far to the repository
  git :add => '.'
  git :commit => "-a -m 'Initial commit'"

# Success!
  puts "SUCCESS!"