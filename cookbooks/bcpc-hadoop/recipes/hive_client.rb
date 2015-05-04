# Install Hive Bits
# workaround for hcatalog dpkg not creating the hcat user it requires
user "hcat" do
  username "hcat"
  system true
  shell "/bin/bash"
  home "/usr/lib/hcatalog"
  supports :manage_home => false
end

package 'hive-hcatalog' do
  action :upgrade
end

link "/usr/hdp/current/hive-server2/lib/mysql-connector-java.jar" do
  to "/usr/share/java/mysql-connector-java.jar"
end

