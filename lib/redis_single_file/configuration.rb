# frozen_string_literal: true

module RedisSingleFile
  class Configuration
    include Singleton

    DEFAULT_HOST = 'localhost'.freeze
    DEFAULT_PORT = '6379'.freeze
    DEFAULT_EXPIRE_IN = 300 # 5 mins

    attr_writer :host, :port, :expire_in

    def host = @host || DEFAULT_HOST
    def port = @port || DEFAULT_PORT
    def expire_in = @expire_in || DEFAULT_EXPIRE_IN
  end
end
