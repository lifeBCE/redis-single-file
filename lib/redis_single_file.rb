# frozen_string_literal: true

require 'redis'
require 'securerandom'
require 'singleton'

require_relative "redis_single_file/version"
require_relative "redis_single_file/configuration"
require_relative "redis_single_file/semaphore"

module RedisSingleFile
  Mutex = Semaphore

  # initializer configuration block
  def self.configuration
    yield Configuration.instance if block_given?
  end
end
