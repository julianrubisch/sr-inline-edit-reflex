require "action_controller/railtie"
require "action_cable/engine"
require "active_model"
require "active_record"
require "nulldb/rails"
require "rails/command"
require "rails/commands/server/server_command"
require "cable_ready"
require "stimulus_reflex"
require "view_component/engine"
require "view_component_reflex"

gem_dir = Gem::Specification.find_by_name("view_component_reflex").gem_dir

require "#{gem_dir}/app/components/view_component_reflex/component"

module ApplicationCable; end

class ApplicationCable::Connection < ActionCable::Connection::Base
  identified_by :session_id

  def connect
    self.session_id = request.session.id
  end  
end

class ApplicationCable::Channel < ActionCable::Channel::Base; end

class ApplicationController < ActionController::Base; end

class ApplicationReflex < StimulusReflex::Reflex; end

class Book < ActiveRecord::Base; end

class InlineEditComponent < ViewComponentReflex::Component  
  attr_reader :attribute
  
  def initialize(model:, attribute:, editing: false)
    @model = model
    @attribute = attribute
    @editing = editing
  end
  
  def model
    puts "Model: #{@model}"
    @model
  end
  
  def collection_key
    "#{model.id || SecureRandom.hex(16)}-#{attribute}"
  end
  
  def arm
    @editing = true
  end    
  
  def disarm
    @editing = false
    refresh! selector
  end
end

class DemosController < ApplicationController
  def show
    @book = Book.new(author: "Philip K. Dick", title: "A Scanner Darkly")
    render inline: <<~HTML
      <html>
        <head>
          <title>StimulusReflex Mini Demo</title>
          <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.0-beta2/dist/css/bootstrap.min.css" rel="stylesheet">
          <%= javascript_include_tag "/index.js", type: "module" %>
        </head>
        <body>
          <div class="container my-5">
            <h1>Inline Edit View Component Reflex</h1>            
            <%= render InlineEditComponent.new(model: @book, attribute: :author) do %>
              <%= @book.author %>
            <% end %>
            ,&nbsp;
            <%= render InlineEditComponent.new(model: @book, attribute: :title) do %>
              <%= @book.title %>
            <% end %>
          </div>
        </body>
      </html>
    HTML
  end
end

class MiniApp < Rails::Application
  require "stimulus_reflex/../../app/channels/stimulus_reflex/channel"

  config.action_controller.perform_caching = true
  config.consider_all_requests_local = true
  config.public_file_server.enabled = true
  config.secret_key_base = "cde22ece34fdd96d8c72ab3e5c17ac86"
  config.secret_token = "bf56dfbbe596131bfca591d1d9ed2021"
  config.session_store :cache_store
  config.hosts.clear
  
  config.to_prepare_blocks.each do |block|
    block.call
  end

  Rails.cache = ActiveSupport::Cache::RedisCacheStore.new(url: "redis://localhost:6379/1")
  Rails.logger = ActionCable.server.config.logger = Logger.new($stdout)
  ActionCable.server.config.cable = {"adapter" => "redis", "url" => "redis://localhost:6379/1"}

  routes.draw do
    mount ActionCable.server => "/cable"
    get '___glitch_loading_status___', to: redirect('/')
    resource :demo, only: :show
    root "demos#show"
  end
end

ActiveRecord::Base.establish_connection adapter: :nulldb, schema: "schema.rb"

Rails::Server.new(app: MiniApp, Host: "0.0.0.0", Port: ARGV[0]).start
