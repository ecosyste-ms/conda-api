# frozen_string_literal: true

describe Conda do
  before(:all) do
    stub_conda_requests
    Conda.instance.reload_all
  end

  describe "#packages" do
    it "returns all packages across channels" do
      packages = Conda.instance.packages
      expect(packages.keys).to include("numpy", "pandas", "biopython")
    end

    it "merges versions from multiple channels" do
      packages = Conda.instance.packages
      expect(packages["numpy"][:versions].length).to be > 1
    end

    it "caches packages result" do
      result1 = Conda.instance.packages
      result2 = Conda.instance.packages
      expect(result1.object_id).to eq(result2.object_id)
    end
  end

  describe "#packages_by_channel" do
    it "returns packages for specific channel" do
      packages = Conda.instance.packages_by_channel("Main")
      expect(packages.keys).to include("numpy", "pandas")
    end

    it "raises NotFound for invalid channel" do
      expect { Conda.instance.packages_by_channel("Invalid") }.to raise_error(Sinatra::NotFound)
    end
  end

  describe "#package" do
    it "returns package from specific channel" do
      package = Conda.instance.package("Main", "numpy")
      expect(package[:name]).to eq("numpy")
    end

    it "raises NotFound for missing package in channel" do
      expect { Conda.instance.package("Main", "nonexistent") }.to raise_error(Sinatra::NotFound)
    end
  end

  describe "#find_package" do
    it "finds package across all channels" do
      package = Conda.instance.find_package("numpy")
      expect(package[:name]).to eq("numpy")
    end

    it "raises NotFound for missing package" do
      expect { Conda.instance.find_package("nonexistent") }.to raise_error(Sinatra::NotFound)
    end
  end

  describe "#reload_all" do
    it "reloads all channels and updates cache" do
      stub_conda_requests
      initial_packages = Conda.instance.packages
      Conda.instance.reload_all
      reloaded_packages = Conda.instance.packages
      expect(reloaded_packages.object_id).not_to eq(initial_packages.object_id)
    end
  end
end
