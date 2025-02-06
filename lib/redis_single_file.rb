# frozen_string_literal: true

require 'redis'
require 'redis-clustering'
require 'singleton'

require_relative 'redis_single_file/version'
require_relative 'redis_single_file/configuration'
require_relative 'redis_single_file/cluster_client_builder'
require_relative 'redis_single_file/semaphore'

#
# RedisSingleFile - Distributed Execution Synchronization
#
# Redis single file is a queue-based implementation of a remote/shared
# semaphore for distributed execution synchronization. A distributed
# semaphore may be useful for synchronizing execution across numerous
# instances or between the application and background job workers.
#
# @author lifeBCE
#
module RedisSingleFile
  # alias semaphore as mutex
  Mutex = Semaphore

  # internal blpop timeout exception class
  QueueTimeoutError = Class.new(StandardError)

  # MOVED response received but no cluster configured
  ClusterDisabledError = Class.new(StandardError)

  class << self
    # @return [Configuration] singleton instance
    def configuration
      yield Configuration.instance if block_given?
    end

    # @return [Semaphore] distributed locking instance
    def new(...) = Semaphore.new(...)
  end
end
