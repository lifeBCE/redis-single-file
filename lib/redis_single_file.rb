# frozen_string_literal: true

require 'redis'
require 'securerandom'
require 'singleton'

require_relative "redis_single_file/version"
require_relative "redis_single_file/configuration"
require_relative "redis_single_file/semaphore"

module RedisSingleFile
  # alias semaphore as mutex
  Mutex = Semaphore

  # internal blpop timeout exception class
  QueueTimeout = Class.new(StandardError)

  class << self
    def configuration
      yield Configuration.instance if block_given?
    end

    def init(...) = Semaphore.new(...)
  end
end
