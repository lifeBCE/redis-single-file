# frozen_string_literal: true

require 'pry'

RSpec.describe RedisSingleFile::ClusterClientBuilder do
  let(:redis_mock) { MockRedis.new }
  let(:nil_mock) { NilResponder.new }

  it 'is callable' do
    instance = instance_double(described_class)
    expect(instance).to receive(:call)

    expect(described_class).to(
      receive(:new).with(redis: redis_mock).and_return(instance)
    )

    described_class.call(redis: redis_mock)
  end

  it 'raises ClusterDisabledError if env is not a cluster' do
    expect(redis_mock).to(
      receive(:info).with('cluster').and_return(
        { cluster_enabled: '0' }.transform_keys(&:to_s)
      )
    )

    expect { described_class.call(redis: redis_mock) }
      .to raise_error(RedisSingleFile::ClusterDisabledError)
  end

  it 'raises ClusterDisabledError if redis command error is raised' do
    expect(redis_mock).to(
      receive(:info).with('cluster').and_raise(Redis::CommandError)
    )

    expect { described_class.call(redis: redis_mock) }
      .to raise_error(RedisSingleFile::ClusterDisabledError)
  end

  it 'converts to proper cluster-enabled client' do
    # adds mock redis.cluster commands
    redis_mock.extend(MockRedisExtension)

    expect(redis_mock).to(
      receive(:info).with('cluster').and_return(
        { cluster_enabled: '1' }.transform_keys(&:to_s)
      )
    )

    allow(nil_mock).to(
      receive_messages(username: 'user', password: 'pass', db: '3')
    )

    client = instance_double(Redis::Client, config: nil_mock)
    expect(redis_mock).to receive(:_client).and_return(client)

    result = described_class.call(redis: redis_mock)
    config = result._client.config.client_config

    expect(result).to be_instance_of(Redis::Cluster)
    expect(config[:db]).to eq '3'
    expect(config[:username]).to eq 'user'
    expect(config[:password]).to eq 'pass'
  end
end
