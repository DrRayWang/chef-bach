#
# Cookbook Name:: bcpc
# Recipe:: 389ds
#
# Copyright 2013, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
Chef::Resource.send(:include, Bcpc::OSHelper)
include_recipe "bcpc::default"

Bcpc::OSHelper.set_config(node, '389ds-admin-user', "admin")
Bcpc::OSHelper.set_config(node, '389ds-admin-password', Bcpc::Helper.secure_password)
Bcpc::OSHelper.set_config(node, '389ds-rootdn-user', "cn=Directory Manager")
Bcpc::OSHelper.set_config(node, '389ds-rootdn-password', Bcpc::Helper.secure_password)
Bcpc::OSHelper.set_config(node, '389ds-replication-user', "cn=Replication Manager")
Bcpc::OSHelper.set_config(node, '389ds-replication-password', Bcpc::Helper.secure_password)

%w{389-ds ldap-utils}.each do |pkg|
    package pkg do
        action :upgrade
    end
end

template "/tmp/389ds-install.inf" do
    source "389ds-install.inf.erb"
    owner "root"
    group "root"
    mode 00600
    helpers(Bcpc::OSHelper)
end

bash "setup-389ds-server" do
	user "root"
	code <<-EOH
        setup-ds-admin --file=/tmp/389ds-install.inf -k -s
        service dirsrv stop
        service dirsrv-admin stop
        sed --in-place 's/^ServerLimit.*/ServerLimit 64/' /etc/dirsrv/admin-serv/httpd.conf
        sed --in-place '/^MinSpareThreads/d' /etc/dirsrv/admin-serv/httpd.conf
        sed --in-place '/^MaxSpareThreads/d' /etc/dirsrv/admin-serv/httpd.conf
        sed --in-place '/^ThreadsPerChild/d' /etc/dirsrv/admin-serv/httpd.conf
        sed --in-place 's/^nsslapd-port.*/nsslapd-listenhost: #{node[:bcpc][:management][:ip]}\\nnsslapd-port: 389/' /etc/dirsrv/slapd-#{node[:hostname]}/dse.ldif
        echo "dn: cn=Replication Manager,cn=config" >> /etc/dirsrv/slapd-#{node[:hostname]}/dse.ldif
        echo "objectClass: inetorgperson" >> /etc/dirsrv/slapd-#{node[:hostname]}/dse.ldif
        echo "objectClass: person" >> /etc/dirsrv/slapd-#{node[:hostname]}/dse.ldif
        echo "objectClass: top" >> /etc/dirsrv/slapd-#{node[:hostname]}/dse.ldif
        echo "cn: Replication Manager" >> /etc/dirsrv/slapd-#{node[:hostname]}/dse.ldif
        echo "sn: RM" >> /etc/dirsrv/slapd-#{node[:hostname]}/dse.ldif
        echo "userPassword: #{Bcpc::OSHelper.get_config(node, '389ds-replication-password')}" >> /etc/dirsrv/slapd-#{node[:hostname]}/dse.ldif
        echo "passwordExpirationTime: 20380119031407Z" >> /etc/dirsrv/slapd-#{node[:hostname]}/dse.ldif
        echo "nsIdleTimeout: 0" >> /etc/dirsrv/slapd-#{node[:hostname]}/dse.ldif
        service dirsrv start
        service dirsrv-admin start
	EOH
	not_if "test -d /etc/dirsrv/slapd-#{node[:hostname]}"
end

ruby_block "create-ldap-changelog" do
    block do
        if not system "ldapsearch -h #{node[:bcpc][:management][:ip]} -p 389  -D \"#{Bcpc::OSHelper.get_config(node, '389ds-rootdn-user')}\" -w \"#{Bcpc::OSHelper.get_config(node, '389ds-rootdn-password')}\" -b cn=config \"(cn=changelog5)\" | grep -v filter | grep changelog5 > /dev/null 2>&1" then
            %x[ ldapmodify -h #{node[:bcpc][:management][:ip]} -p 389  -D \"#{Bcpc::OSHelper.get_config(node, '389ds-rootdn-user')}\" -w \"#{Bcpc::OSHelper.get_config(node, '389ds-rootdn-password')}\" << EOH
dn: cn=changelog5,cn=config
changetype: add
objectclass: top
objectclass: extensibleObject
cn: changelog5
nsslapd-changelogdir: /var/lib/dirsrv/slapd-#{node[:hostname]}/changelogdb

            ]
        end
    end
end

ruby_block "create-ldap-supplier-replica" do
    block do
        if not system "ldapsearch -h #{node[:bcpc][:management][:ip]} -p 389  -D \"#{Bcpc::OSHelper.get_config(node, '389ds-rootdn-user')}\" -w \"#{Bcpc::OSHelper.get_config(node, '389ds-rootdn-password')}\" -b cn=config \"(cn=replica)\" | grep -v filter | grep replica > /dev/null 2>&1" then
            domain = node[:bcpc][:domain_name].split('.').collect{|x| 'dc='+x}.join(',')
            %x[ ldapmodify -h #{node[:bcpc][:management][:ip]} -p 389  -D \"#{Bcpc::OSHelper.get_config(node, '389ds-rootdn-user')}\" -w \"#{Bcpc::OSHelper.get_config(node, '389ds-rootdn-password')}\" << EOH
dn: cn=replica,cn="#{domain}",cn=mapping tree,cn=config
changetype: add
objectclass: top
objectclass: nsds5replica
objectclass: extensibleObject
cn: replica
nsds5replicaroot: #{domain}
nsds5replicaid: #{node[:bcpc][:node_number]}
nsds5replicatype: 3
nsds5flags: 1
nsds5ReplicaPurgeDelay: 604800
nsds5ReplicaBindDN: #{Bcpc::OSHelper.get_config(node, '389ds-replication-user')},cn=config

            ]
        end
    end
end

Bcpc::OSHelper.get_head_nodes(node, method( :search )).each do |server|
    if server['hostname'] != node[:hostname]
        ruby_block "setup-ldap-consumption-from-#{server['hostname']}" do
            block do
                if not system "ldapsearch -h #{server['bcpc']['management']['ip']} -p 389  -D \"#{Bcpc::OSHelper.get_config(node, '389ds-rootdn-user')}\" -w \"#{Bcpc::OSHelper.get_config(node, '389ds-rootdn-password')}\" -b cn=config \"(cn=To-#{node[:hostname]})\" | grep -v filter | grep #{node[:hostname]} > /dev/null 2>&1" then
                    domain = node[:bcpc][:domain_name].split('.').collect{|x| 'dc='+x}.join(',')
                    %x[ ldapmodify -h #{server['bcpc']['management']['ip']} -p 389  -D \"#{Bcpc::OSHelper.get_config(node, '389ds-rootdn-user')}\" -w \"#{Bcpc::OSHelper.get_config(node, '389ds-rootdn-password')}\" << EOH
dn: cn=To-#{node[:hostname]},cn=replica,cn="#{domain}",cn=mapping tree,cn=config
changetype: add
objectclass: top
objectclass: nsds5replicationagreement
cn: To-#{node[:hostname]}
nsds5replicahost: #{node[:bcpc][:management][:ip]}
nsds5replicaport: 389
nsds5ReplicaBindDN: #{Bcpc::OSHelper.get_config(node, '389ds-replication-user')},cn=config
nsds5replicabindmethod: SIMPLE
nsds5replicaroot: #{domain}
description: Agreement to sync from #{server['hostname']} to #{node[:hostname]}
nsds5replicatedattributelist: (objectclass=*) $ EXCLUDE authorityRevocationList
nsds5replicacredentials: #{Bcpc::OSHelper.get_config(node, '389ds-replication-password')}
nsds5BeginReplicaRefresh: start

                    ]
                end
            end
        end
    end
end

package "phpldapadmin" do
    action :upgrade
end

template "/etc/phpldapadmin/config.php" do
    source "phpldapadmin-config.php.erb"
    owner "root"
    group "root"
    mode 00644
    helpers(Bcpc::OSHelper)
end

template "/etc/apache2/vhost-ssl-root.d/phpldapadmin.conf" do
    source "apache-vhost-ssl-root-phpldapadmin.conf.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[apache2]", :delayed
end
