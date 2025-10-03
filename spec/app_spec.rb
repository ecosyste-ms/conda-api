# frozen_string_literal: true

describe CondaAPI do
  before(:all) do
    stub_conda_requests
    Conda.instance.reload_all
  end

  it "should show HelloWorld" do
    get "/"
    expect(last_response).to be_ok
  end

  it "should get list of packages" do
    get "/packages"
    expect(last_response).to be_ok
    json = JSON.parse(last_response.body)
    expect(json.keys).to include("numpy", "pandas", "biopython")
  end

  it "should get package by name" do
    get "/package/numpy"
    expect(last_response).to be_ok
    json = JSON.parse(last_response.body)
    expect(json["name"]).to eq("numpy")
    expect(json["versions"].length).to be > 0
  end

  it "should 404 on missing package" do
    get "/package/something-fake"
    expect(last_response).to be_not_found
  end

  it "should get packages by channel" do
    get "/Main/"
    expect(last_response).to be_ok
    json = JSON.parse(last_response.body)
    expect(json.keys).to include("numpy", "pandas")
  end

  it "should get specific package from channel" do
    get "/Main/numpy"
    expect(last_response).to be_ok
    json = JSON.parse(last_response.body)
    expect(json["name"]).to eq("numpy")
  end

  it "should get specific package version from channel" do
    get "/Main/numpy/1.24.3"
    expect(last_response).to be_ok
    json = JSON.parse(last_response.body)
    expect(json).to be_an(Array)
  end
end
