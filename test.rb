#!/usr/bin/env ruby

require 'pry'
require 'securerandom'
require 'redis_single_file'

PORT = ENV['REDIS_PORT'] || 6379
RUN_ID = SecureRandom.uuid

ITERATIONS = (ARGV[0] || 10).to_i
WORK_LOAD  = (ARGV[1] || 1).to_i
TIMEOUT    = ITERATIONS * WORK_LOAD

#semaphore = RedisSingleFile.new(name: RUN_ID, port: PORT)
#semaphore.synchronize!(timeout: 10) do
#  puts "Hello World!"
#  sleep 1
#end

#exit

#10.times.map do
#  fork do
#    semaphore = RedisSingleFile.new(name: RUN_ID, port: PORT)
#    semaphore.synchronize!(timeout: TIMEOUT) do
#      puts "Hello World!"
#      sleep WORK_LOAD
#    end
#  end
#
#  sleep 0.05
#end
#
#Process.waitall

#exit

threads = ITERATIONS.times.map do
  thread = Thread.new do
    semaphore = RedisSingleFile.new(name: RUN_ID, port: PORT)
    semaphore.synchronize(timeout: TIMEOUT) do
      puts "Hello World!"
      sleep WORK_LOAD
    end
  end

  thread
end

threads.each { _1.join(0.2) } while threads.any?(&:alive?)
