# frozen_string_literal: true

require 'mock_redis'

RSpec.describe RedisSingleFile::Semaphore do
  let(:redis_mock) { MockRedis.new }

  before do
    allow(Redis).to receive(:new).and_return(redis_mock)
  end

  it 'default redis client set as expected' do
    semaphore = described_class.new

    expect(semaphore.send(:redis)).to eq(redis_mock)
  end

  it 'provided redis client is set as expected' do
    semaphore = described_class.new(redis: redis_mock)

    expect(Redis).not_to have_received(:new)
    expect(semaphore.send(:redis)).to eq(redis_mock)
  end

  it 'default redis host and port is set as expected' do
    described_class.new
    expect(Redis).to have_received(:new).with(host: 'localhost', port: '6379')
  end

  it 'provided redis host is set as expected' do
    described_class.new(host: 'test-host')
    expect(Redis).to have_received(:new).with(host: 'test-host', port: '6379')
  end

  it 'provided redis port is set as expected' do
    described_class.new(port: '1234')
    expect(Redis).to have_received(:new).with(host: 'localhost', port: '1234')
  end

  it '#synchronize method calls synchronize! with default timeout' do
    semaphore = described_class.new
    expect(semaphore).to receive(:synchronize!).with(timeout: 0)

    semaphore.synchronize { nil }
  end

  it '#synchronize method calls synchronize! with provided timeout' do
    semaphore = described_class.new
    expect(semaphore).to receive(:synchronize!).with(timeout: 15)

    semaphore.synchronize(timeout: 15) { nil }
  end

  it '#synchronize returns nil on timeout' do
    semaphore = described_class.new
    expect(semaphore).to(
      receive(:synchronize!)
        .with(timeout: 0)
        .and_raise(RedisSingleFile::QueueTimeoutError)
    )

    result = semaphore.synchronize { nil }

    expect(result).to be_nil
  end

  it '#synchronize! returns without execution when no block provided' do
    semaphore = described_class.new
    expect(semaphore).not_to receive(:with_retry_protection)

    result = semaphore.synchronize!

    expect(result).to be_nil
  end

  it '#synchronize! primes the queue when first client' do
    expect(redis_mock).to receive(:del)
    expect(redis_mock).to receive(:lpush)
    expect(redis_mock).to receive(:blpop).and_return('1')

    semaphore = described_class.new
    result = semaphore.synchronize! { 'test body' }

    expect(result).to eq('test body')
  end

  it '#synchronize! skips priming the queue when not first client' do
    expect(redis_mock).not_to receive(:del)
    expect(redis_mock).not_to receive(:lpush)
    expect(redis_mock).to receive(:getset).and_return('1')
    expect(redis_mock).to receive(:blpop).and_return('1')

    semaphore = described_class.new
    result = semaphore.synchronize! { 'test body' }

    expect(result).to eq('test body')
  end

  it '#synchronize! persists redis keys when executing block' do
    expect(redis_mock).to receive(:blpop).and_return('1')
    expect(redis_mock).to receive(:persist).twice

    semaphore = described_class.new
    result = semaphore.synchronize! { 'test body' }

    expect(result).to eq('test body')
  end

  it '#synchronize! unlocks queue when exiting' do
    expect(redis_mock).to receive(:blpop).and_return('1')
    expect(redis_mock).to receive(:lpush)
    expect(redis_mock).to receive(:expire).twice

    semaphore = described_class.new
    result = semaphore.synchronize! { 'test body' }

    expect(result).to eq('test body')
  end

  it '#synchronize! does not cycle queue when token already exists' do
    expect(redis_mock).to receive(:getset).and_return('1')
    expect(redis_mock).to receive(:blpop).and_return('1')
    expect(redis_mock).to receive(:llen).and_return(1)
    expect(redis_mock).not_to receive(:lpush)
    expect(redis_mock).to receive(:expire).twice

    semaphore = described_class.new
    result = semaphore.synchronize! { 'test body' }

    expect(result).to eq('test body')
  end
end
