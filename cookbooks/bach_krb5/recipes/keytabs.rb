get_all_nodes().each do |h|
  # Create directories to store keytabs
  directory "#{node[:bcpc][:hadoop][:kerberos][:keytab][:dir]}/#{float_host(h[:fqdn])}" do
    action :create
    owner "root"
    group "root"
    mode 0755
    recursive true
  end
  
  # Generate all the principals
  node[:bcpc][:hadoop][:kerberos][:data].each do |ke, va|

    krb5_principal "#{va['principal']}/#{float_host(h[:fqdn])}@#{node[:bcpc][:hadoop][:realm]}" do
      action :delete
      only_if {principal_exists?("#{va['principal']}/#{float_host(h[:fqdn])}@#{node[:bcpc][:hadoop][:realm]}") && node[:bcpc][:hadoop][:kerberos][:keytab][:recreate] == true}
    end

    krb5_principal "#{va['principal']}/#{float_host(h[:fqdn])}@#{node[:bcpc][:hadoop][:realm]}" do
      action :create
      randkey true
      not_if {principal_exists?("#{va['principal']}/#{float_host(h[:fqdn])}@#{node[:bcpc][:hadoop][:realm]}")}
    end
  end

  # Generate keytabs
  node[:bcpc][:hadoop][:kerberos][:data].each do |ke, va|

    file "#{node[:bcpc][:hadoop][:kerberos][:keytab][:dir]}/#{float_host(h[:fqdn])}/#{va['keytab']}" do
      action :delete
      only_if {File.exists?("#{node[:bcpc][:hadoop][:kerberos][:keytab][:dir]}/#{float_host(h[:fqdn])}/#{va['keytab']}") && node[:bcpc][:hadoop][:kerberos][:keytab][:recreate] == true}
    end

    execute "creating-keytab-for-#{ke}" do
      command "kadmin.local -q 'xst -k #{node[:bcpc][:hadoop][:kerberos][:keytab][:dir]}/#{float_host(h[:fqdn])}/#{va['keytab']} -norandkey #{va['principal']}/#{float_host(h[:fqdn])}@#{node[:bcpc][:hadoop][:realm]} HTTP/#{float_host(h[:fqdn])}@#{node[:bcpc][:hadoop][:realm]}'"
      action :run
      not_if {File.exists?("#{node[:bcpc][:hadoop][:kerberos][:keytab][:dir]}/#{float_host(h[:fqdn])}/#{va['keytab']}")}
    end
  end
end

include_recipe "bach_krb5::upload_keytabs"
