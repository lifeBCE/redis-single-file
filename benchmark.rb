# frozen_string_literal: true

require 'benchmark/ips'
require 'redis_single_file'

PORT = ENV['WORKFLOW_PORT'] || 6379

scenario_1_semaphore = RedisSingleFile.new(name: :scenario1, port: PORT)
scenario_2_semaphore = RedisSingleFile.new(name: :scenario2, port: PORT)

Benchmark.ips do |x|
  x.report('synchronize') do
    scenario_1_semaphore.synchronize { nil }
  end

  x.report('synchronize!') do
    scenario_2_semaphore.synchronize! { nil }
  end

  x.report('threaded (10x)') do
    threads = 10.times.map do
      Thread.new do
        scenario_3_semaphore = RedisSingleFile.new(name: :scenario3, port: PORT)
        scenario_3_semaphore.synchronize { nil }
      end
    end

    threads.each { _1.join(0.2) } while threads.any?(&:alive?)
  end

  x.report('forked (10x)') do
    10.times.each do
      fork do
        scenario_4_semaphore = RedisSingleFile.new(name: :scenario4, port: PORT)
        scenario_4_semaphore.synchronize { nil }
      end
    end

    Process.waitall
  end

  x.compare!
end
