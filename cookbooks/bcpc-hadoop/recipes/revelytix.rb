Chef::Resource.send(:include, Bcpc::OSHelper)

ruby_block "initialize-revelytix-config" do
    block do
      Bcpc::OSHelper.set_config(node, 'revelytix_loom_ssl_password', Bcpc::Helper.secure_password)
      Bcpc::OSHelper.set_config(node, 'revelitix_ssl_trust_password', Bcpc::Helper.secure_password)
    end
end

directory "/var/lib/loom" do
  action :create
end

directory "/tmp/#{node["bcpc"]["revelytix"]["loom_username"]}" do
  action :create
end

user node["bcpc"]["revelytix"]["loom_username"] do
  action :create
  shell "/bin/false"
  home "/var/lib/loom"
end

bash "create-loom-dir" do
  uname = node["bcpc"]["revelytix"]["loom_username"]
  code "hadoop fs -mkdir -p /user/#{uname}; hadoop fs -chown #{uname} /user/#{uname}"
  user "hdfs"
  not_if "sudo -u hdfs hadoop fs -test -d /user/#{uname}"
end

bash "create-loom-tmpdir" do
  uname = node["bcpc"]["revelytix"]["loom_username"]
  code "hadoop fs -mkdir -p /tmp/hive-#{uname}; hadoop fs -chown #{uname} /tmp/hive-#{uname}"
  user "hdfs"
  not_if "sudo -u hdfs hadoop fs -test -d /tmp/hive-#{uname}"
end


package "loom" do
  action :upgrade
end

template "loom-properties" do
  path "/opt/loom/config/loom.properties"
  source "revelytix-loom-properties.erb"
  owner "root"
  group "root"
  mode "0755"
  helpers(Bcpc::OSHelper)
#  notifies :enable, "service[loom]"
#  notifies :start, "service[loom]"
end

template "loom-security-unix-conf" do
  path "/opt/loom/config/security-unix.conf"
  source "revelytix-loom-security.erb"
end

service "revelytix-loom" do
  action [:enable, :start]
end
