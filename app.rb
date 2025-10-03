# frozen_string_literal: true

require "sinatra/base"
require_relative "conda"
require_relative "app"
require "rufus-scheduler"
require "oj"

Oj.default_options = { mode: :compat }

class CondaAPI < Sinatra::Base
  scheduler = Rufus::Scheduler.new

  set :host_authorization, { permitted_hosts: [] }

  configure :production, :development do
    enable :logging
  end

  get "/" do
    "Last updated at #{Conda.instance.channels.values.first.timestamp} \n"
  end

  get "/packages" do
    content_type :json
    Oj.dump(Conda.instance.packages, mode: :compat)
  end

  get "/package/:name" do
    content_type :json
    Oj.dump(Conda.instance.find_package(params["name"]), mode: :compat)
  end

  get "/package/:name/:version" do
    content_type :json
    package = Conda.instance.find_package(params["name"]).clone
    package[:versions] = package[:versions].select { |version| version[:number] == params["version"] }
    Oj.dump(package, mode: :compat)
  end

  get "/:channel/" do
    content_type :json
    Oj.dump(Conda.instance.packages_by_channel(params["channel"]), mode: :compat)
  end

  get "/:channel/:name" do
    content_type :json
    Oj.dump(Conda.instance.package(params["channel"], params["name"]), mode: :compat)
  end

  get "/:channel/:name/:version" do
    content_type :json
    Oj.dump(Conda.instance.package_by_channel(params["channel"], params["name"], params["version"]), mode: :compat)
  end

  scheduler.every "15m" do
    Conda.instance.reload_all
  end
end
