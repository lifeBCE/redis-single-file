[![Build Status](https://github.com/lifeBCE/redis-single-file/actions/workflows/build.yml/badge.svg)](https://github.com/lifeBCE/redis-single-file/actions/workflows/build.yml)
[![RSpec Status](https://github.com/lifeBCE/redis-single-file/actions/workflows/rspec.yml/badge.svg)](https://github.com/lifeBCE/redis-single-file/actions/workflows/rspec.yml)
[![Rubocop Status](https://github.com/lifeBCE/redis-single-file/actions/workflows/rubocop.yml/badge.svg)](https://github.com/lifeBCE/redis-single-file/actions/workflows/rubocop.yml)
[![CodeQL Status](https://github.com/lifeBCE/redis-single-file/actions/workflows/codeql.yml/badge.svg)](https://github.com/lifeBCE/redis-single-file/actions/workflows/codeql.yml)

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
  # config.name = 'default'
  # config.expire_in = 300
end
```

## Usage Examples

#### Default lock name and infinite blocking
```ruby
  semaphore = RedisSingleFile.new
  semaphore.synchronize do
    # synchronized logic defined here...
  end
```

#### Named locks can provide exclusive synchronization
```ruby
   semaphore = RedisSingleFile.new(name: :user_cache_update)
   semaphore.synchronize do
      # synchronized logic defined here...
   end
```

#### Prevent deadlocks by providing a timeout
```ruby
   semaphore = RedisSingleFile.new(name: :s3_file_upload)
   semaphore.synchronize(timeout: 15) do
      # synchronized logic defined here...
   end
```

#### Use your own redis client instance
```ruby
   redis = Redis.new(...)
   semaphore = RedisSingleFile.new(redis:)
   semaphore.synchronize do
      # synchronized logic defined here...
   end
```

## Documentation

### Distributed Queue Design

The redis `blpop` command will attempt to pop (delete and return) a value from
a queue but will block when no values are present in the queue. A timeout can
be provided to prevent deadlock situations.

To unblock (unlock) an instance, add/push an item to the queue. This is done
one at a time to controll the serialization of the distrubuted execution. Redis
selects the instance waiting the longest each time a new token is added.

### Auto Expiration

All redis keys are expired and automatically removed after a certain period
but will be recreated again on the next use. Each new client should face one
of two scenarios when entering synchronization.

1. The mutex key is not set causing the client to create the keys and prime
   the queue with its first token unlocking it for the first execution.

2. The mutex key is already set so the client will skip the priming and enter
   directly into the queue where it should immediately find a token left by
   the last client upon completion or block waiting for the current client to
   finish execution.

### Considerations over redlock approach

[Redlock](https://github.com/leandromoreira/redlock-rb) is the current standard and the official approach [suggested by redis themselves](https://redis.io/docs/latest/develop/use/patterns/distributed-locks/) but the design does have some complexities/drawbacks that some may wish to avoid. The following is a list of pros and cons of redis single file over redlock.

<details>
<summary><code>Pro:</code> Multi-master redis node configuration not required</summary>
<br />
<blockquote>
The redlock design requires a multi-master redis node setup where each node is completely independent of the others (no replication). This would be uncommon in most standard application deployment environments so a seperate redis setup would be required just for the distributed lock management.
<br /><br />
Redis single file will work with your existing redis configuration so no need to maintain a seperate redis setup for the application of distributed semaphores.
</blockquote>
</details>

<details>
<summary><code>Pro:</code> No polling or waiting logic needed as redis does all the blocking</summary>
<br />
<blockquote>
The redlock design requires the client to enter into a polling loop checking for the ability to execute its logic repeatedly. This approach is less efficient and requires quite a bit more logic to accomplish also making it more prone to error.
<br /><br />
Redis single file pushes much of this responsibility off to redis itself with the use of the <code>blpop</code> command. Redis will block on that call when no item is present in the queue and will allocate tokens to competing clients waiting their turn on a `first-come, first-served basis`.
</blockquote>
</details>

<details>
<summary><code>Pro:</code> Replication lag is not a concern with <code>blpop</code></summary>
<br />
<blockquote>
The redlock design requires a multi-master setup given it utilizes read operations that could be delegated to a read replica in a standard clustered redis deployement. Redis replication is handled in an async manner so replication lag can hinder distributed synchronization when using read operations against a cluster utlizing replication.
<br /><br />
Redis single file is not susceptible to this limitation given that <code>blpop</code> is a write operation meaning it will always be handled by the master node eliminating concerns over replication lag.
</blockquote>
</details>

<details>
<summary><code>Con:</code> Redis cluster failover could disrupt currently queued clients</summary>
<br />
<blockquote>
Redis single file does attempt to recognize a connection failure and proceeds in rejoining the queue when detected but there is still a small chance that a cluster failover could cause already queued clients to have issues.
<br /><br />
Redlock is not susceptible to this given the use of the multi-master deployment and absence of read-replicas so cluster failover (and recovery) is not a concern.
</blockquote>
</details>

## Run Tests

    $ bundle exec rspec

```spec
Finished in 0.00818 seconds (files took 0.09999 seconds to load)
22 examples, 0 failures
```

## Benchmark

    $ bundle exec ruby benchmark.rb

```ruby
ruby 3.2.0 (2022-12-25 revision a528908271) [arm64-darwin22]
Warming up --------------------------------------
         synchronize   434.000 i/100ms
        synchronize!   434.000 i/100ms
      threaded (10x)    29.000 i/100ms
        forked (10x)     8.000 i/100ms
Calculating -------------------------------------
         synchronize      4.329k (± 1.9%) i/s  (230.98 μs/i) -     21.700k in   5.014460s
        synchronize!      4.352k (± 0.3%) i/s  (229.79 μs/i) -     22.134k in   5.086272s
      threaded (10x)    249.794 (±28.4%) i/s    (4.00 ms/i) -      1.073k in   5.058461s
        forked (10x)     56.588 (± 3.5%) i/s   (17.67 ms/i) -    288.000 in   5.097885s

Comparison:
        synchronize!:     4351.8 i/s
         synchronize:     4329.4 i/s - same-ish: difference falls within error
      threaded (10x):      249.8 i/s - 17.42x  slower
        forked (10x):       56.6 i/s - 76.90x  slower
```

## Cluster Management

After installing redis locally, you can use the provided `bin/cluster` script to manage a local cluster. To customize your local cluster, edit the `bin/cluster` script to provide your own values for the following script variables.

```bash
#
# configurable settings
#
HOST=127.0.0.1
PORT=30000
MASTERS=3  # min 3 for cluster
REPLICAS=2 # replicas per master
TIMEOUT=2000
PROTECTED_MODE=yes
ADDITIONAL_OPTIONS=""
```

<details>
<summary><strong>Start cluster nodes</strong></summary>

    $ bin/cluster start

```console
Starting 30001
Starting 30002
Starting 30003
Starting 30004
Starting 30005
Starting 30006
Starting 30007
Starting 30008
Starting 30009
```
</details>

<details>
<summary><strong>Create cluster configuration</strong></summary>

    $ bin/cluster create -f

```console
>>> Performing hash slots allocation on 9 nodes...
Master[0] -> Slots 0 - 5460
Master[1] -> Slots 5461 - 10922
Master[2] -> Slots 10923 - 16383
Adding replica 127.0.0.1:30005 to 127.0.0.1:30001
Adding replica 127.0.0.1:30006 to 127.0.0.1:30001
Adding replica 127.0.0.1:30007 to 127.0.0.1:30002
Adding replica 127.0.0.1:30008 to 127.0.0.1:30002
Adding replica 127.0.0.1:30009 to 127.0.0.1:30003
Adding replica 127.0.0.1:30004 to 127.0.0.1:30003
```
</details>

<details>
<summary><strong>Stop cluster nodes</strong></summary>

    $ bin/cluster stop

```console
Stopping 30001
Stopping 30002
Stopping 30003
Stopping 30004
Stopping 30005
Stopping 30006
Stopping 30007
Stopping 30008
Stopping 30009
```
</details>

<details>
<summary><strong>Clean local cluster files</strong></summary>

    $ bin/cluster clean

```console
Cleaning *.log
Cleaning appendonlydir-*
Cleaning dump-*.rdb
Cleaning nodes-*.conf
```
</details>

## Disclaimer

> [!WARNING]
> Make sure you understand the limitations and reliability inherent in this implementation prior to using it in a production environment. No guarantees are made. Use at your own risk!

## Inspiration

Inspiration for this gem was taken from a number of existing projects. It would be beneficial for anyone interested to take a look at all 3.

1. [Redlock](https://github.com/leandromoreira/redlock-rb)
2. [redis-semaphore](https://github.com/dv/redis-semaphore)
3. [redis-mutex](https://github.com/kenn/redis-mutex)

## Contributing

1. [Fork it](https://github.com/lifeBCE/redis-single-file/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
