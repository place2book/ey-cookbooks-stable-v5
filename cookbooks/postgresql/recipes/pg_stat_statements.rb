file_name = "/db/postgresql/#{node[:postgresql][:short_version]}/custom.conf"
Chef::Log.info "filename #{file_name}"
update_file "configure pg_stat_statements" do
  action :append
  path file_name
  body <<-EOF
  
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.max = 10000
pg_stat_statements.track = all
EOF
  not_if "grep pg_stat_stements #{file_name}"
end

Chef::Log.info("The pg_stat_statements extension has been created but a server restart is needed to load the module for it to work.")