# frozen_string_literal: true

require "typhoeus"
require "json"
require "redis"
require "digest"

class Channel
  ARCHES = %w[emscripten-wasm32 freebsd-64 linux-32 linux-64 linux-aarch64 linux-armv6l linux-armv7l linux-ppc64 linux-ppc64le linux-riscv64 linux-s390x noarch osx-64 osx-arm64 wasi-wasm32 win-32 win-64 win-arm64 zos-z].freeze

  attr_reader :timestamp

  def initialize(channel, domain)
    @channel_name = channel
    @domain = domain
    @timestamp = Time.now
    @lock = Concurrent::ReadWriteLock.new
    @deduped_cache = nil
    @redis = redis_client
    reload
  end

  def reload
    new_packages = retrieve_packages
    deduped = remove_duplicate_versions(new_packages)
    @lock.with_write_lock do
      @packages = new_packages
      @deduped_cache = deduped
    end
    @timestamp = Time.now
  end

  def packages
    @lock.with_read_lock { @packages }
  end

  def package_version(name, version)
    @lock.with_read_lock do
      raise Sinatra::NotFound unless @packages.key?(name)

      @packages[name][:versions].filter { |package| package[:number] == version }
    end
  end

  def only_one_version_packages
    @lock.with_read_lock { @deduped_cache }
  end

  private

  def retrieve_packages
    packages = {}
    channel_resp = cached_get("https://#{@domain}/#{@channel_name}/channeldata.json")
    channeldata = JSON.parse(channel_resp)["packages"]

    hydra = Typhoeus::Hydra.new(max_concurrency: 20)
    requests = {}

    ARCHES.each do |arch|
      url = "https://#{@domain}/#{@channel_name}/#{arch}/repodata.json"
      request = Typhoeus::Request.new(url)
      request.on_complete do |response|
        next unless response.success?

        begin
          cached_body = cache_response(url, response)
          blob = JSON.parse(cached_body)['packages']
          blob.each_key do |key|
            version = blob[key]
            package_name = version["name"]

            unless packages.key?(package_name)
              package_data = channeldata[package_name]
              packages[package_name] = base_package(package_data, package_name)
            end

            packages[package_name][:versions] << release_version(key, version)
          end
        rescue => e
          # Skip failed architectures
        end
      end
      hydra.queue(request)
      requests[arch] = request
    end

    hydra.run
    packages
  end

  def redis_client
    return nil if ENV["RACK_ENV"] == "test"
    Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379/0")
  rescue => e
    nil
  end

  def cached_get(url)
    cache_key = "http:#{Digest::SHA256.hexdigest(url)}"
    etag_key = "#{cache_key}:etag"
    last_modified_key = "#{cache_key}:last_modified"

    if @redis
      cached_body = @redis.get(cache_key)
      cached_etag = @redis.get(etag_key)
      cached_last_modified = @redis.get(last_modified_key)

      if cached_body && (cached_etag || cached_last_modified)
        headers = {}
        headers["If-None-Match"] = cached_etag if cached_etag
        headers["If-Modified-Since"] = cached_last_modified if cached_last_modified

        response = Typhoeus.get(url, headers: headers)

        if response.code == 304
          @redis.expire(cache_key, 3600)
          @redis.expire(etag_key, 3600) if cached_etag
          @redis.expire(last_modified_key, 3600) if cached_last_modified
          return cached_body
        elsif response.success?
          store_in_cache(cache_key, etag_key, last_modified_key, response)
          return response.body
        else
          return cached_body
        end
      end
    end

    response = Typhoeus.get(url)
    return nil unless response.success?

    store_in_cache(cache_key, etag_key, last_modified_key, response) if @redis
    response.body
  end

  def cache_response(url, response)
    cache_key = "http:#{Digest::SHA256.hexdigest(url)}"
    etag_key = "#{cache_key}:etag"
    last_modified_key = "#{cache_key}:last_modified"

    store_in_cache(cache_key, etag_key, last_modified_key, response)
    response.body
  end

  def store_in_cache(cache_key, etag_key, last_modified_key, response)
    return unless @redis

    @redis.setex(cache_key, 3600, response.body)

    if response.headers["ETag"]
      @redis.setex(etag_key, 3600, response.headers["ETag"])
    end

    if response.headers["Last-Modified"]
      @redis.setex(last_modified_key, 3600, response.headers["Last-Modified"])
    end
  end

  def base_package(package_data, package_name)
    {
      versions: [],
      repository_url: package_data["dev_url"],
      homepage: package_data["home"],
      licenses: package_data["license"],
      description: package_data["description"],
      name: package_name,
    }
  end

  def release_version(artifact, package_version)
    {
      artifact: artifact,
      download_url: "https://#{@domain}/#{@channel_name}/#{package_version['subdir']}/#{artifact}",
      number: package_version["version"],
      original_license: package_version["license"],
      published_at: package_version["timestamp"].nil? ? nil : Time.at(package_version["timestamp"] / 1000),
      dependencies: package_version["depends"],
      arch: package_version["subdir"],
      channel: @channel_name,
    }
  end

  def remove_duplicate_versions(packages)
    packages.each_value do |value|
      value[:versions] = value[:versions].uniq { |vers| vers[:number] }
    end
    packages
  end
end
