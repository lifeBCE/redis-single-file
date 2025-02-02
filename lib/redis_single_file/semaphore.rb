# frozen_string_literal: true

#
# == RedisSingleFile::Semaphore ================================================
#
# This class acts as the main synchronization engine for distributed logic
# execution by utilizing the redis blpop command to facilitate a distributed
# synchronous queue.
#
# == Distributed Queue =========================================================
#
# The redis blpop command will attempt to pop (delete and return) a value from
# a queue but will block when no values are present in the queue. A timeout can
# be provided to prevent deadlock situations.
#
# To unblock (unlock) an instance, add/push an item to the queue. This is done
# one at a time to controll the serialization of the distrubed execution. Redis
# selects the instance waiting the longest each time a new token is added.
#
# Some benefits to this approach over the redlock design might be:
#
# - Multi-master redis node configuration not required
# - No polling or waiting logic needed as redis does all the blocking
# - Blpop is a write operation so clusters with read replicas can be used as
#   all requests are sent to the write node eliminating any concern of
#   replication lag negatively impacting synchronization
#
# == Auto Expiration ===========================================================
#
# All redis keys are expired and automatically removed after a certain period
# but will be recreated again on the next use. Each new client should face one
# of two scenarios when entering synchronization.
#
# 1. The mutex key is not set causing the client to create the keys and prime
#    the queue with its first token unlocking it for the first execution.
#
# 2. The mutex key is already set so the client will skip the priming and enter
#    directly into the queue where it should immediately find a token left by
#    the last client upon completion.
#
# ---
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
# @return [self] the semaphore instance
#
module RedisSingleFile
  class Semaphore
    SYNC_NAME = 'default'
    MUTEX_KEY = 'RedisSingleFile/Mutex/%s'
    QUEUE_KEY = 'RedisSingleFile/Queue/%s'
    EXPIRE_IN = Configuration.instance.expire_in

    # blpop timeout exception class
    QueueTimeout = Class.new(StandardError)

    def initialize(
      redis: nil,
      name: SYNC_NAME,
      host: Configuration.instance.host,
      port: Configuration.instance.port
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
    #
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
    #
    def synchronize!(timeout: 0)
      return unless block_given?

      prime_queue unless redis.getset(mutex_key, mutex_val)
      raise QueueTimeout unless redis.blpop(queue_key, timeout:)

      yield
    ensure
      # always cycle the queue when exiting
      unlock_queue if block_given?
    end

    private #===================================================================

    attr_reader :redis, :mutex_key, :mutex_val, :queue_key

    def prime_queue
      redis.multi do
        redis.del(queue_key)        # remove existing queue
        redis.lpush(queue_key, '1') # create and prime new queue
      end
    end

    def unlock_queue
      redis.multi do
        # queue next client execution
        redis.lpush(queue_key, '1') if redis.llen(queue_key) == 0
        redis.expire(mutex_key, EXPIRE_IN) # set expiration for auto removal
        redis.expire(queue_key, EXPIRE_IN) # set expiration for auto removal
      end
    end
  end
end
