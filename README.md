# Redis Single File - Distributed Execution Synchronization

Redis single file is a queue-based implementation of a remote/shared semaphore
for distributed execution synchronization. A distributed semaphore may be useful
for synchronizing execution across numerous instances or between the application
and background job workers.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'redis-single-file'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redis-single-file

## Configuration

Configure redis single file via its configuration object.

```ruby
RedisSingleFile.configuration do |config|
  # config.host = 'localhost'
  # config.port = '6379'
  # config.expire_in = 300
end
```

## Documentation

### Distributed Queue Design

The redis blpop command will attempt to pop (delete and return) a value from
a queue but will block when no values are present in the queue. A timeout can
be provided to prevent deadlock situations.

To unblock (unlock) an instance, add/push an item to the queue. This is done
one at a time to controll the serialization of the distrubed execution. Redis
selects the instance waiting the longest each time a new token is added.

### Considerations over redlock approach

[Redlock](https://github.com/leandromoreira/redlock-rb) is the current standard
and the official approach suggested by redis themselves but the design does have
some complexities/drawbacks that some may wish to avoid. The following is a list
of pros and cons of redis single file over redlock.

* *Pro*: Multi-master redis node configuration not required.
* *Pro*: No polling or waiting logic needed as redis does all the blocking.
* *Pro*: Blpop is a write operation so clusters with read replicas can be used
   as all requests are sent to the write node eliminating any concern of
   replication lag negatively impacting synchronization.
* *Con*: Redis cluster failover could disrupt currently queued clients.

### Auto Expiration

All redis keys are expired and automatically removed after a certain period
but will be recreated again on the next use. Each new client should face one
of two scenarios when entering synchronization.

1. The mutex key is not set causing the client to create the keys and prime
   the queue with its first token unlocking it for the first execution.

2. The mutex key is already set so the client will skip the priming and enter
   directly into the queue where it should immediately find a token left by
   the last client upon completion.

## Usage Examples

#### Default lock name and infinite blocking
```ruby
  semaphore = RedisSingleFile::Semaphore.new
  semaphore.synchronize do
    # synchronized logic defined here...
  end
```

#### Named locks can provide exclusive synchronization
```ruby
   semaphore = RedisSingleFile::Semaphore.new(name: :user_cache_update)
   semaphore.synchronize do
      # synchronized logic defined here...
   end
```

#### Prevent deadlocks by providing a timeout
```ruby
   semaphore = RedisSingleFile::Semaphore.new(name: s3_file_upload)
   semaphore.synchronize(timeout: 15) do
      # synchronized logic defined here...
   end
```

#### Use your own redis client instance
```ruby
   redis = Redis.new(...)
   semaphore = RedisSingleFile::Semaphore.new(redis:)
   semaphore.synchronize do
      # synchronized logic defined here...
   end
```

## Run tests


## Disclaimer


## Contributing

1. [Fork it](https://github.com/lifeBCE/redis-single-file/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
