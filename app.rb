# frozen_string_literal: true

require "sinatra/base"
require_relative "conda"
require_relative "app"
require "rufus-scheduler"

class CondaAPI < Sinatra::Base
  scheduler = Rufus::Scheduler.new

  configure :production, :development do
    enable :logging
  end

  configure :production do
    set :host_authorization, { permitted_hosts: ["conda.ecosyste.ms"] }
  end

  get "/" do
    "Last updated at #{Conda.instance.channels.values.first.timestamp} \n"
  end

  get "/packages" do
    content_type :json
    Conda.instance.packages.to_json
  end

  get "/package/:name" do
    content_type :json
    Conda.instance.find_package(params["name"]).to_json
  end

  get "/package/:name/:version" do
    content_type :json
    package = Conda.instance.find_package(params["name"]).clone
    package[:versions] = package[:versions].select { |version| version[:number] == params["version"] }
    package.to_json
  end

  get "/:channel/" do
    content_type :json
    Conda.instance.packages_by_channel(params["channel"]).to_json
  end

  get "/:channel/:name" do
    content_type :json
    Conda.instance.package(params["channel"], params["name"]).to_json
  end

  get "/:channel/:name/:version" do
    content_type :json
    Conda.instance.package_by_channel(params["channel"], params["name"], params["version"]).to_json
  end

  scheduler.every "15m" do
    puts "Reloading packages..."
    Conda.instance.reload_all
    puts "Reload finished"
  end
end
