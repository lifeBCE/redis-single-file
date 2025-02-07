# frozen_string_literal: true

module RedisSingleFile
  #
  # This class acts as the main synchronization engine for distributed logic
  # execution by utilizing the redis blpop command to facilitate a distributed
  # synchronous queue.
  #
  # @author lifeBCE
  #
  # @attr redis [...] redis client instance
  # @attr name [String] custom sync queue name
  # @attr host [String] host for redis server
  # @attr port [String] port for redis server
  #
  # @example Default lock name and infinite blocking
  #   semaphore = RedisSingleFile::Semaphore.new
  #   semaphore.synchronize do
  #      # synchronized logic defined here...
  #   end
  #
  # @example Named locks can provide exclusive synchronization
  #   semaphore = RedisSingleFile::Semaphore.new(name: :user_cache_update)
  #   semaphore.synchronize do
  #      # synchronized logic defined here...
  #   end
  #
  # @example Prevent deadlocks by providing a timeout
  #   semaphore = RedisSingleFile::Semaphore.new(name: s3_file_upload)
  #   semaphore.synchronize(timeout: 15) do
  #      # synchronized logic defined here...
  #   end
  #
  # @example Use your own redis client instance
  #   redis = Redis.new(...)
  #   semaphore = RedisSingleFile::Semaphore.new(redis:)
  #   semaphore.synchronize do
  #     # synchronized logic defined here...
  #   end
  #
  # @return [self] the semaphore instance
  class Semaphore
    #
    # @note redis:
    #   Any more advanced configuration than host and port should be applied
    #   to an instance outside of redis single file and passed in via this
    #   attribute.
    #
    # @note name:
    #   Distributed semaphores are coordinated by name. Each client that wishes
    #   to synchronize a particular block should do so under the same name.
    #
    # #note host:
    #   Each synchronized execution can be done on a different redis server
    #   than globally configured. Passing a value for this attribute will
    #   redirect to that host.
    #
    # @note port:
    #   Each synchronized execution can be done on a different redis port
    #   than globally configured. Passing a value for this attribute will
    #   redirect to that port.
    #
    # @return [self] semaphore instance
    def initialize(
      redis: nil,               # provide your own redis instance
      name: Configuration.name, # designate queue name per session
      host: Configuration.host, # designate redis host per session
      port: Configuration.port  # designate redis port per session
    )
      @redis = redis || Redis.new(host:, port:)

      @mutex_val = name
      @mutex_key = format(Configuration.mutex_key, @mutex_val)
      @queue_key = format(Configuration.queue_key, @mutex_val)
    end

    # Queues up client and waits for turn to execute. Returns nil
    # when queue wait time expires.
    #
    # @param timeout [Integer] seconds for client to wait in queue
    # @yieldreturn [...] response from synchronized block execution
    # @return [nil] redis blpop timeout
    def synchronize(timeout: 0, &)
      synchronize!(timeout:, &)
    rescue QueueTimeoutError => _e
      nil
    end

    # Queues up client and waits for turn to execute. Raise exception
    # when queue wait time expires.
    #
    # @param timeout [Integer] seconds for blpop to wait in queue
    # @yieldreturn [...] response from synchronized block execution
    # @raise [QueueTimeoutError] redis blpop timeout
    def synchronize!(timeout: 0)
      return unless block_given?

      with_retry_protection do
        prime_queue unless redis.getset(mutex_key, mutex_val)
        raise QueueTimeoutError unless redis.blpop(queue_key, timeout:)

        redis.multi do
          redis.persist(mutex_key) # unexpire during execution
          redis.persist(queue_key) # unexpire during execution
        end
      end

      yield
    ensure
      # always cycle the queue when exiting
      unlock_queue if block_given?
    end

    private #===================================================================

    attr_reader :redis, :mutex_key, :mutex_val, :queue_key

    def expire_in
      @expire_in ||= Configuration.expire_in
    end

    def prime_queue
      with_retry_protection do
        redis.multi do
          redis.del(queue_key)        # remove existing queue
          redis.lpush(queue_key, '1') # create and prime new queue
        end
      end
    end

    def unlock_queue
      with_retry_protection do
        redis.multi do
          # queue next client execution if queue is empty
          redis.lpush(queue_key, '1') if redis.llen(queue_key) == 0
          redis.expire(mutex_key, expire_in) # set expiration for auto removal
          redis.expire(queue_key, expire_in) # set expiration for auto removal
        end
      end
    end

    def with_retry_protection(&)
      with_cluster_protection(&) if block_given?
    rescue Redis::ConnectionError => _e
      retry_count ||= 0
      retry_count  += 1

      # retry 5 times over 15 seconds then give up
      sleep(retry_count) && retry if retry_count < 6
      raise # re-raise after all retries exhausted
    end

    def with_cluster_protection
      yield if block_given?
    rescue Redis::CommandError => e
      cmd = e.message.split.first

      # redis cluster configured but client does not support
      # MOVED 14403 127.0.0.1:30003 (redis://localhost:30001)
      if cmd == 'MOVED'
        retry_count ||= 0
        retry_count  += 1

        if retry_count < 2 # allow a single retry
          @redis = ClusterClientBuilder.call(redis:)
          retry # retry same command with new client
        end
      end

      raise # cmd != MOVED or retries exhausted
    end
  end
end
