# frozen_string_literal: true

RSpec.describe RedisSingleFile do
  it 'has a version number' do
    expect(RedisSingleFile::VERSION).not_to be_nil
  end

  it '.new returns a semaphore instance' do
    expect(described_class.new.class).to eq(RedisSingleFile::Semaphore)
  end

  it '.configuration returns a Configuration singleton' do
    described_class.configuration do |config|
      expect(config).to eq(RedisSingleFile::Configuration.instance)
    end
  end

  it 'Mutex aliases Semaphore' do
    expect(RedisSingleFile::Mutex).to eq(RedisSingleFile::Semaphore)
  end

  it 'QueueTimeoutError exception extends StandardError' do
    expect(RedisSingleFile::QueueTimeoutError.new).to be_a(StandardError)
  end
end
