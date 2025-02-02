# frozen_string_literal: true

module RedisSingleFile
  #
  # This class provides the ability to configure redis single file.
  #
  # @author lifeBCE
  #
  # @example RedisSingleFile configuration
  #   RedisSingleFile.configuration do |config|
  #     config.host = 'localhost'
  #     config.port = '6379'
  #     config.name = 'default'
  #     config.expire_in = 300
  #   end
  #
  # @return [self] the configuration instance
  class Configuration
    include Singleton

    # configuration defaults when not provided
    DEFAULT_HOST = 'localhost'
    DEFAULT_PORT = '6379'
    DEFAULT_NAME = 'default'
    DEFAULT_EXPIRE_IN = 300 # 5 mins
    DEFAULT_MUTEX_KEY = 'RedisSingleFile/Mutex/%s'
    DEFAULT_QUEUE_KEY = 'RedisSingleFile/Queue/%s'

    # class delegation methods to singleton instance
    #
    # Example:
    #   Configuration.host => Configuration.instance.host
    #   Configuration.port => Configuration.instance.port
    #
    class << self
      %i[host port name expire_in mutex_key queue_key].each do |attr|
        define_method(attr) { instance.send(attr) }
      end
    end

    # writers used in config block to set new values
    attr_writer :host, :port, :name, :expire_in

    # @return [String] redis server hostname value
    def host = @host || DEFAULT_HOST

    # @return [String] redis server port value
    def port = @port || DEFAULT_PORT

    # @return [String] default queue name when omitted
    def name = @name || DEFAULT_NAME

    # @return [String] redis keys expiration value
    def expire_in = @expire_in || DEFAULT_EXPIRE_IN

    # @note This attr is not configurable
    # @return [String] synchronization mutex key name
    def mutex_key = @mutex_key || DEFAULT_MUTEX_KEY

    # @note This attr is not configurable
    # @return [String] synchronization queue key name
    def queue_key = @queue_key || DEFAULT_QUEUE_KEY
  end
end
