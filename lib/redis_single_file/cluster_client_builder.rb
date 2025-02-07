# frozen_string_literal: true

module RedisSingleFile
  #
  # This class is a cluster client builder that performs automatic cluster
  # detection and redis client conversion. All params from the original
  # non-cluster client will be transfered to the new cluster-enabled client
  # when building the new client.
  #
  # @author lifeBCE
  #
  # @return [self] the custer_client instance
  class ClusterClientBuilder
    class << self
      def call(...) = new(...).call
    end

    def initialize(redis: nil)
      @redis = redis
    end

    # !@method call
    #   @raise [ClusterDisabledError] if cluster not enabled
    #   @return [Redis::Cluster] redis cluster instance
    def call
      raise ClusterDisabledError, 'cluster not detected' unless cluster_enabled?

      # use extracted client options with parsed nodes
      Redis::Cluster.new(**client_options, nodes:)
    end

    private # ==================================================================

    # !@method redis
    #   @return [Redis|Redis::Cluster] redis client
    attr_reader :redis

    # !@method nodes
    #   @return [Array<String>] list of redis master nodes
    def nodes
      cluster_nodes
        .select { _1[:flags].include?('master') }
        .map    { "redis://#{_1[:address].split('@').first}" }
    end

    # !@method cluster_enabled?
    #   @return [Boolean] whether client is connected to a cluster
    def cluster_enabled?
      redis.info('cluster')['cluster_enabled'] == '1'
    rescue Redis::CommandError
      false # assume cluster mode is disabled
    end

    # !@method cluster_nodes
    #   @return [Array<Hash>] list of parsed cluster nodes
    def cluster_nodes
      cluster_info = redis.cluster('NODES')

      cluster_info.split("\n").map do |line|
        parts = line.split
        master_id = parts[3] == '-' ? nil : parts[3]

        {
          id: parts[0],                 # Node ID
          address: parts[1],            # IP:Port@bus-port
          flags: parts[2].split(','),   # Flags (e.g., master, slave, fail, handshake)
          master_id:,                   # Master node ID (if applicable)
          ping_sent: parts[4].to_i,     # Milliseconds since last PING
          pong_received: parts[5].to_i, # Milliseconds since last PONG
          config_epoch: parts[6].to_i,  # Config epoch
          link_state: parts[7],         # Link state (connected/disconnected)
          slots: parts[8..]             # Assigned slots (if present)
        }
      end
    end

    # !@method client_options
    #   @return [Hash] current redis client config options
    def client_options
      config = redis._client.config

      {
        url: config.server_url,
        host: config.host,
        port: config.port,
        path: config.path,
        db: config.db,
        username: config.username,
        password: config.password,
        protocol: config.protocol,
        read_timeout: config.read_timeout,
        connect_timeout: config.connect_timeout,
        write_timeout: config.write_timeout,
        custom: config.custom,
        ssl: config.ssl?,
        ssl_params: config.ssl_params
      }
    end
  end
end
