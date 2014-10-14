include_recipe 'bcpc-hadoop::hadoop_config'
include_recipe 'bcpc-hadoop::hive_config'

node.default['bcpc']['hadoop']['copylog']['datanode'] = {
    'logfile' => "/var/log/hadoop-hdfs/hadoop-hdfs-datanode-#{node.hostname}.log",
    'docopy' => true
}

%w{hadoop-hdfs-datanode
   hadoop-client}.each do |pkg|
  package pkg do
    action :upgrade
  end
end

template "/etc/init.d/hadoop-hdfs-datanode" do
  source "hdp_hadoop-hdfs-datanode-initd.erb"
  mode 0655
end

template "/etc/init.d/hadoop-yarn-nodemanager" do
  source "hdp_hadoop-yarn-nodemanager-initd.erb"
  mode 0655
end

link "/usr/hdp/2.2.0.0-2041/hadoop/lib/hadoop-lzo-0.6.0.jar" do
  to "/usr/lib/hadoop/lib/hadoop-lzo-0.6.0.jar"
end

link "/usr/lib/hadoop/lib/native/libgplcompression.la" do
  to "/usr/lib/hadoop/lib/native/Linux-amd64-64/libgplcompression.la"
end

link "/usr/lib/hadoop/lib/native/libgplcompression.a" do
  to "/usr/lib/hadoop/lib/native/Linux-amd64-64/libgplcompression.a"
end

link "/usr/lib/hadoop/lib/native/libgplcompression.so.0.0.0" do
  to "/usr/lib/hadoop/lib/native/Linux-amd64-64/libgplcompression.so.0.0.0"
end

# Setup datanode bits
if node[:bcpc][:hadoop][:mounts].length <= node[:bcpc][:hadoop][:hdfs][:failed_volumes_tolerated]
  Chef::Application.fatal!("You have fewer #{node[:bcpc][:hadoop][:disks]} than #{node[:bcpc][:hadoop][:hdfs][:failed_volumes_tolerated]}! See comments of HDFS-4442.")
end

# Build nodes for HDFS storage
node[:bcpc][:hadoop][:mounts].each do |i|
  directory "/disk/#{i}/dfs" do
    owner "hdfs"
    group "hdfs"
    mode 0700
    action :create
  end
  directory "/disk/#{i}/dfs/dn" do
    owner "hdfs"
    group "hdfs"
    mode 0700
    action :create
  end
end

dep = ["template[/etc/hadoop/conf/hdfs-site.xml]",
       "template[/etc/hadoop/conf/hadoop-env.sh]"]

hadoop_service "hadoop-hdfs-datanode" do
  dependencies dep
  process_identifier "org.apache.hadoop.hdfs.server.datanode.DataNode"
end

