# frozen_string_literal: true

require "./channel"
require "singleton"

class Conda
  include Singleton
  attr_reader :channels

  def initialize
    @channels = {
      "Main" => Channel.new("main", "repo.anaconda.com/pkgs"),
      "Msys2" => Channel.new("main", "repo.anaconda.com/pkgs"),
      "R" => Channel.new("main", "repo.anaconda.com/pkgs"),
      "CondaForge" => Channel.new("conda-forge", "conda.anaconda.org"),
      "BioConda" => Channel.new("bioconda", "conda.anaconda.org"),
    }
    @lock = Concurrent::ReadWriteLock.new
    @packages_cache = nil
    new_packages = compute_all_packages

    @lock.with_write_lock { @packages_cache = new_packages }
  end

  def packages_by_channel(channel)
    raise Sinatra::NotFound unless @channels.key?(channel)

    @channels[channel].packages
  end

  def package_by_channel(channel, name, version)
    raise Sinatra::NotFound unless @channels.key?(channel)

    @channels[channel].package_version(name, version)
  end

  def packages
    @lock.with_read_lock { @packages_cache }
  end

  def compute_all_packages
    global_packages = {}
    @channels.each_value do |channel|
      channel.only_one_version_packages.each do |package_name, package|
        if global_packages.key?(package_name)
          global_packages[package_name][:versions] += package[:versions].clone
        else
          global_packages[package_name] = package.clone
        end
      end
    end
    global_packages
  end

  def package(channel, name)
    packs = packages_by_channel(channel)
    raise Sinatra::NotFound unless packs.key?(name)

    packs[name]
  end

  def find_package(name)
    package = @channels.values.find { |channel| channel.packages.key?(name) }&.packages&.dig(name)
    raise Sinatra::NotFound if package.nil?

    package
  end

  def reload_all
    @channels.each_value(&:reload)
    new_packages = compute_all_packages
    @lock.with_write_lock { @packages_cache = new_packages }
  end
end
