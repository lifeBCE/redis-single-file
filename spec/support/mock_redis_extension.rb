# frozen_string_literal: true

module MockRedisExtension
  # intercepts calls to `cluster` on the MockRedis instance.
  def cluster(subcommand)
    case subcommand.to_s.downcase
    when 'info'
      cluster_info
    when 'nodes'
      cluster_nodes
    else
      # if the subcommand isn't supported, mimic Redis's error.
      raise Redis::CommandError, "ERR unknown command 'cluster #{subcommand}'"
    end
  end

  private

  def cluster_info
    # hash with the expected cluster info data
    info = {
      cluster_state: 'ok',
      cluster_slots_assigned: 16_384,
      cluster_slots_ok: 16_384,
      cluster_slots_pfail: 0,
      cluster_slots_fail: 0,
      cluster_known_nodes: 9,
      cluster_size: 3,
      cluster_current_epoch: 9,
      cluster_my_epoch: 1,
      cluster_stats_messages_ping_sent: 33_021,
      cluster_stats_messages_pong_sent: 32_968,
      cluster_stats_messages_sent: 65_989,
      cluster_stats_messages_ping_received: 32_960,
      cluster_stats_messages_pong_received: 33_021,
      cluster_stats_messages_meet_received: 8,
      cluster_stats_messages_received: 65_989,
      total_cluster_links_buffer_limit_exceeded: 0
    }

    # convert the hash to the expected string format
    info.to_a.map { |pair| pair.join(':') }.join("\n")
  end

  def cluster_nodes
    [ # node_id ip:port@bus-port flags master_id ping_sent pong_recv config_epoch link_state slots
      '1111 127.0.0.1:30001@40001 myself,master - 0 1738893521000 1 connected 0-5460',
      '2222 127.0.0.1:30002@40002 master - 0 1738893521220 2 connected 5461-10922',
      '3333 127.0.0.1:30003@40003 master - 0 1738893521220 3 connected 10923-16383',
      '4444 127.0.0.1:30004@40004 slave 4321 0 1738893521422 3 connected',
      '5555 127.0.0.1:30005@40005 slave 4321 0 1738893521220 3 connected',
      '6666 127.0.0.1:30006@40006 slave 4567 0 1738893521220 1 connected',
      '7777 127.0.0.1:30007@40007 slave 1234 0 1738893521220 2 connected',
      '8888 127.0.0.1:30008@40008 slave 1234 0 1738893521321 2 connected',
      '9999 127.0.0.1:30009@40009 slave 4567 0 1738893521322 1 connected'
    ].join("\n")
  end
end
