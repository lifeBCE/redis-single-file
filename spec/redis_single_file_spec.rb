# frozen_string_literal: true

RSpec.describe RedisSingleFile do
  it "has a version number" do
    expect(RedisSingleFile::VERSION).not_to be nil
  end

  it ".new returns a semaphore instance" do
    expect(RedisSingleFile.new.class).to eq(RedisSingleFile::Semaphore)
  end

  it ".configuration returns a Configuration singleton" do
    RedisSingleFile.configuration do |config|
      expect(config).to eq(RedisSingleFile::Configuration.instance)
    end
  end

  it "Mutex aliases Semaphore" do
    expect(RedisSingleFile::Mutex).to eq(RedisSingleFile::Semaphore)
  end

  it "QueueTimeout exception extends StandardError" do
    expect(RedisSingleFile::QueueTimeout.new).to be_a_kind_of(StandardError)
  end
end
