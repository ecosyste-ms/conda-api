# frozen_string_literal: true

describe Channel do
  before do
    stub_conda_requests
  end

  describe "#initialize" do
    it "loads packages from remote" do
      channel = Channel.new("main", "repo.anaconda.com/pkgs")
      expect(channel.packages.keys).to include("numpy", "pandas")
    end
  end

  describe "#reload" do
    it "refreshes packages" do
      channel = Channel.new("conda-forge", "conda.anaconda.org")
      initial_timestamp = channel.timestamp
      sleep 0.01
      channel.reload
      expect(channel.timestamp).to be > initial_timestamp
    end
  end

  describe "#only_one_version_packages" do
    it "removes duplicate versions" do
      channel = Channel.new("main", "repo.anaconda.com/pkgs")
      packages = channel.only_one_version_packages

      packages.each_value do |package|
        version_numbers = package[:versions].map { |v| v[:number] }
        expect(version_numbers).to eq(version_numbers.uniq)
      end
    end

    it "caches deduplicated results" do
      channel = Channel.new("main", "repo.anaconda.com/pkgs")
      result1 = channel.only_one_version_packages
      result2 = channel.only_one_version_packages
      expect(result1.object_id).to eq(result2.object_id)
    end
  end

  describe "#package_version" do
    it "returns specific version" do
      channel = Channel.new("main", "repo.anaconda.com/pkgs")
      versions = channel.package_version("numpy", "1.24.3")
      expect(versions).to be_an(Array)
      expect(versions.first[:number]).to eq("1.24.3")
    end

    it "raises NotFound for missing package" do
      channel = Channel.new("main", "repo.anaconda.com/pkgs")
      expect { channel.package_version("nonexistent", "1.0") }.to raise_error(Sinatra::NotFound)
    end
  end
end
