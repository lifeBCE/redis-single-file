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
  # @attr name [String] custom sync session name
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
    SYNC_NAME = 'default'
    MUTEX_KEY = 'RedisSingleFile/Mutex/%s'
    QUEUE_KEY = 'RedisSingleFile/Queue/%s'
    EXPIRE_IN = Configuration.expire_in

    # blpop timeout exception class
    QueueTimeout = Class.new(StandardError)

    def initialize(
      redis: nil,               # provide your own redis instance
      name: SYNC_NAME,          # designated sync name per session
      host: Configuration.host, # different redis host per session
      port: Configuration.port  # different redis port per session
    )
      @redis = redis || Redis.new(host:, port:)

      @mutex_val = name
      @mutex_key = format(MUTEX_KEY, @mutex_val)
      @queue_key = format(QUEUE_KEY, @mutex_val)
    end

    #
    # Queues up client and waits for turn to execute. Returns nil
    # when queue wait time expires.
    #
    # @param timeout [Integer] seconds for blpop to wait in queue
    # @yieldreturn [...] response from synchronized block execution
    # @return [nil] redis blpop timeout
    def synchronize(timeout: 0, &blk)
      synchronize!(timeout:, &blk)
    rescue QueueTimeout => _err
      nil
    end

    #
    # Queues up client and waits for turn to execute. Raise exception
    # when queue wait time expires.
    #
    # @param timeout [Integer] seconds for blpop to wait in queue
    # @yieldreturn [...] response from synchronized block execution
    # @raise [QueueTimeout] redis blpop timeout
    def synchronize!(timeout: 0)
      return unless block_given?

      with_retry_protection do
        prime_queue unless redis.getset(mutex_key, mutex_val)
        raise QueueTimeout unless redis.blpop(queue_key, timeout:)
      end

      yield
    ensure
      # always cycle the queue when exiting
      unlock_queue if block_given?
    end

    private #===================================================================

    attr_reader :redis, :mutex_key, :mutex_val, :queue_key

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
          # queue next client execution
          redis.lpush(queue_key, '1') if redis.llen(queue_key) == 0
          redis.expire(mutex_key, EXPIRE_IN) # set expiration for auto removal
          redis.expire(queue_key, EXPIRE_IN) # set expiration for auto removal
        end
      end
    end

    def with_retry_protection
      begin
        yield if block_given?
      rescue Redis::ConnectionError => _err
        retry_count ||= 0
        retry_count  += 1

        sleep 1 # give redis time to heal
        retry if retry_count < 10

        raise # re-raise after all retries exhausted
      end
    end
  end
end
