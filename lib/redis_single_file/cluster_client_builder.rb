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
      #
      # Delegates class method calls to instance method
      #
      # @param [...] params passes directly to constructor
      # @return [Redis::Cluster] redis cluster instance
      def call(...) = new(...).call
    end
    #
    # @note redis:
    #   Standard redis client instance for a clustered environment. The
    #   cluster information will be extracted from this client when creating
    #   the new cluster-enabled client so must responsd to cluster commands
    #   and have an enabled cluster configured.
    #
    # @return [self] cluster client builder instance
    def initialize(redis:)
      @redis = redis
    end

    # Convert standard redis client to a cluster-enabled client. Client options
    # are extracted from the original client and passed to the new client along
    # with parsed nodes from original client's cluster configuration.
    #
    # @raise [ClusterDisabledError] if cluster not enabled
    # @return [Redis::Cluster] redis cluster instance
    def call
      raise ClusterDisabledError, 'cluster not detected' unless cluster_enabled?

      # use extracted client options with parsed nodes
      Redis::Cluster.new(**client_options, nodes:)
    end

    private # ==================================================================

    attr_reader :redis

    def nodes
      cluster_nodes.filter_map do |node|
        next unless node[:flags].include?('master')

        "redis://#{node[:address].split('@').first}"
      end
    end

    def cluster_enabled?
      redis.info('cluster')['cluster_enabled'] == '1'
    rescue Redis::CommandError
      false # assume cluster mode is disabled
    end

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

    def client_options
      config = redis._client.config
      params = %i[
        db ssl host port path custom username password protocol
        ssl_params read_timeout write_timeout connect_timeout
      ]

      params_hash = params.each.with_object({}) do |key, memo|
        memo[key] = config.public_send(key)
      end

      params_hash.merge(url: config.server_url)
    end
  end
end
