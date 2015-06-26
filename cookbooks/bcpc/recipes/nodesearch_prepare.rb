cookbook_file "cluster.txt" do
  path "/tmp/cluster.txt"
  action :nothing
end.run_action(:create_if_missing)

remote_directory "/tmp/roles" do
  source "roles"
  action :nothing
end.run_action(:create_if_missing)
