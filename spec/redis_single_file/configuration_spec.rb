# frozen_string_literal: true

RSpec.describe RedisSingleFile::Configuration do
  it "defaults are configured as expected" do
    expect(RedisSingleFile::Configuration::DEFAULT_HOST).to eq('localhost')
    expect(RedisSingleFile::Configuration::DEFAULT_PORT).to eq('6379')
    expect(RedisSingleFile::Configuration::DEFAULT_NAME).to eq('default')
    expect(RedisSingleFile::Configuration::DEFAULT_EXPIRE_IN).to eq(300)
    expect(RedisSingleFile::Configuration::DEFAULT_MUTEX_KEY).to eq('RedisSingleFile/Mutex/%s')
    expect(RedisSingleFile::Configuration::DEFAULT_QUEUE_KEY).to eq('RedisSingleFile/Queue/%s')
  end

  it "delegations return expected default values" do
    expect(RedisSingleFile::Configuration.host).to eq('localhost')
    expect(RedisSingleFile::Configuration.port).to eq('6379')
    expect(RedisSingleFile::Configuration.name).to eq('default')
    expect(RedisSingleFile::Configuration.expire_in).to eq(300)
    expect(RedisSingleFile::Configuration.mutex_key).to eq('RedisSingleFile/Mutex/%s')
    expect(RedisSingleFile::Configuration.queue_key).to eq('RedisSingleFile/Queue/%s')
  end

  it "configuration block changes values" do
    RedisSingleFile.configuration do |config|
      config.host = 'test_host'
      config.port = '1234'
      config.name = 'queue_name'
      config.expire_in = 100
    end

    expect(RedisSingleFile::Configuration.host).to eq('test_host')
    expect(RedisSingleFile::Configuration.port).to eq('1234')
    expect(RedisSingleFile::Configuration.name).to eq('queue_name')
    expect(RedisSingleFile::Configuration.expire_in).to eq(100)

    # reset singleton to defaults
    RedisSingleFile.configuration do |config|
      config.host = RedisSingleFile::Configuration::DEFAULT_HOST
      config.port = RedisSingleFile::Configuration::DEFAULT_PORT
      config.name = RedisSingleFile::Configuration::DEFAULT_NAME
      config.expire_in = RedisSingleFile::Configuration::DEFAULT_EXPIRE_IN
    end
  end
end
