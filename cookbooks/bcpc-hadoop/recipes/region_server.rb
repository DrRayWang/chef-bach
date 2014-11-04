include_recipe 'bcpc-hadoop::hbase_config'

node.default['bcpc']['hadoop']['copylog']['region_server'] = {
    'logfile' => "/var/log/hbase/hbase-hbase-0-regionserver-#{node.hostname}.log", 
    'docopy' => true
}

node.default['bcpc']['hadoop']['copylog']['region_server_out'] = {
    'logfile' => "/var/log/hbase/hbase-hbase-0-regionserver-#{node.hostname}.out", 
    'docopy' => true
}

%w{hbase-regionserver libsnappy1 phoenix}.each do |pkg|
  package pkg do
    action :install
  end
end

directory "/usr/lib/hbase/lib/native/Linux-amd64-64/" do
  recursive true
  action :create
end

link "/usr/lib/hbase/lib/native/Linux-amd64-64/libsnappy.so.1" do
  to "/usr/lib/libsnappy.so.1"
end

template "/etc/hbase/conf/hbase-env.sh" do
  source "hb_hbase-env.sh.erb"
  mode 0655
end

template "/etc/default/hbase" do
  source "hdp_hbase.default.erb"
  mode 0655
  variables(:hbrs_jmx_port => node[:bcpc][:hadoop][:hbase_rs][:jmx][:port])
end

template "/etc/init.d/hbase-regionserver" do
  source "hdp_hbase-regionserver-initd.erb"
  mode 0655
end

rs_service_dep = ["template[/etc/hbase/conf/hbase-site.xml]",
                  "template[/etc/hbase/conf/hbase-env.sh]",
                  "template[/etc/hbase/conf/hbase-policy.xml]"] 

hadoop_service "hbase-regionserver" do
  dependencies rs_service_dep
  process_identifier "org.apache.hadoop.hbase.regionserver.HRegionServer"
end
