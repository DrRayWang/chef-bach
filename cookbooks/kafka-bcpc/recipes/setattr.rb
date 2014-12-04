#
# Cookbook Name:: kafka-bcpc
# Recipe: setattr

# Override JAVA related node attributee
node.override['java']['jdk_version'] = '7'
node.override['java']['jdk']['7']['x86_64']['url'] = Bcpc::OSHelper.get_binary_server_url(node) + "jdk-7u51-linux-x64.tar.gz"
node.override['java']['jdk']['7']['i586']['url'] = Bcpc::OSHelper.get_binary_server_url(node) + "jdk-7u51-linux-i586.tar.gz"

# Get Kafka ZooKeeper servers
# Override ZooKeeper related node attribute if Kafka specific ZooKeeper quorum is used
if node[:use_hadoop_zookeeper_quorum]
  zk_hosts = Bcpc::OSHelper.get_node_attributes(HOSTNAME_NODENO_ATTR_SRCH_KEYS,"zookeeper_server",node,"bcpc-hadoop")
else
  zk_hosts = Bcpc::OSHelper.get_req_node_attributes(get_zk_nodes,HOSTNAME_NODENO_ATTR_SRCH_KEYS)
  node.override[:bcpc][:hadoop][:zookeeper][:servers] = zk_hosts
end
# Override Kafka related node attributes
node.override[:kafka][:broker][:zookeeper][:connect] = zk_hosts.map{|x| Bcpc::OSHelper.float_host(node,x['hostname'])}
