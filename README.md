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
   semaphore = RedisSingleFile::Semaphore.new(name: :s3_file_upload)
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

## Documentation

### Distributed Queue Design

The redis blpop command will attempt to pop (delete and return) a value from
a queue but will block when no values are present in the queue. A timeout can
be provided to prevent deadlock situations.

To unblock (unlock) an instance, add/push an item to the queue. This is done
one at a time to controll the serialization of the distrubed execution. Redis
selects the instance waiting the longest each time a new token is added.

### Auto Expiration

All redis keys are expired and automatically removed after a certain period
but will be recreated again on the next use. Each new client should face one
of two scenarios when entering synchronization.

1. The mutex key is not set causing the client to create the keys and prime
   the queue with its first token unlocking it for the first execution.

2. The mutex key is already set so the client will skip the priming and enter
   directly into the queue where it should immediately find a token left by
   the last client upon completion.

### Considerations over redlock approach

[Redlock](https://github.com/leandromoreira/redlock-rb) is the current standard
and the official approach suggested by redis themselves but the design does have
some complexities/drawbacks that some may wish to avoid. The following is a list
of pros and cons of redis single file over redlock.

#### *Pro*: Multi-master redis node configuration not required.

The redlock design requires a multi-master redis node setup where each node is
completely independent of the others (no replication). This would be uncommon
in most standard application deployment environments so a seperate redis setup
would be required just for the distributed lock management.

Redis single file will work with your existing redis configuration so no need
to maintain a seperate redis setup for the application of distributed semaphores.

#### *Pro*: No polling or waiting logic needed as redis does all the blocking.

The redlock design requires the client to enter into a polling loop checking
for the ability to execute its logic repeatedly. This approach is less efficient
and requires quite a bit more logic to accomplish also making it more prone to
error.

Redis single file pushes much of this responsibility off to redis itself with
the use of the `blpop` command. Redis will block on that call when no item is
present in the queue and will allocate tokens to competing clients waiting their
turn on a `first-come, first-served basis`.

#### *Pro*: Replication lag is not a concern with `blpop`

The redlock design requires a multi-master setup given it utilizes read
operations that could be delegated to a read replica in a standard clustered
redis deployement. Redis replication is handled in an async manner so
replication lag can hinder distributed synchronization when using read
operations against a cluster utlizing replication.

Redis single file is not susceptible to this limitation given that `blpop`
is a write operation meaning it will always be handled by the master node
eliminating concerns voer replication lag.

#### *Con*: Redis cluster failover could disrupt currently queued clients.

Redis single file does attempt to recognize a connection failure and proceeds
in rejoining the queue when detected but there is still a small chance that a
cluster failover could cause already queued clients to have issues.

Redlock is not susceptible to this given the use of the multi-master deployment
and absence of read-replicas so cluster failover (and recovery) is not a concern.

## Run Tests

coming soon...

## Disclaimer


## Contributing

1. [Fork it](https://github.com/lifeBCE/redis-single-file/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
