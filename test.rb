#!/usr/bin/env ruby

require 'pry'
require 'redis_single_file'

RUN_ID = 'same-same' #SecureRandom.uuid

ITERATIONS = (ARGV[0] || 10).to_i
WORK_LOAD  = (ARGV[1] || 1).to_i
TIMEOUT    = ITERATIONS * WORK_LOAD

#semaphore = RedisSingleFile.new(name: RUN_ID, port: 30001)
#semaphore.synchronize!(timeout: 10) do
#  puts "Hello World!"
#  sleep 1
#end

#exit

#10.times.map do
#  fork do
#    semaphore = RedisSingleFile.new(name: RUN_ID)
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

# exit


#while true do
threads = ITERATIONS.times.map do
  thread = Thread.new do
    semaphore = RedisSingleFile.new(name: RUN_ID, port: 30001)
    semaphore.synchronize(timeout: TIMEOUT) do
      puts "Hello World!"
      sleep WORK_LOAD
    end
  end

#  sleep 0.05
  thread
end

while threads.any?(&:alive?) do
  threads.each { _1.join(0.5) }
end
#end
