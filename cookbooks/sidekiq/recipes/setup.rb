#
# Cookbook Name:: sidekiq
# Recipe:: setup
#

if node['sidekiq']['is_sidekiq_instance']
  # report to dashboard
  ey_cloud_report "sidekiq" do
    message "Setting up sidekiq"
  end

  # bin script
  cookbook_file "/engineyard/bin/sidekiq" do
    mode 0755
    source "sidekiq"
    backup false
  end

  # loop through applications
  node.dna['applications'].each do |app_name, _|
    # reload monit
    execute "restart-sidekiq-for-#{app_name}" do
      command "monit reload && sleep 10 && monit restart all -g #{app_name}_sidekiq"
      action :nothing
    end
    
    # monit
    template "/etc/monit.d/sidekiq_#{app_name}.monitrc" do 
      mode 0644 
      source "sidekiq.monitrc.erb" 
      backup false
      variables({ 
        :app_name => app_name, 
        :workers => node['sidekiq']['workers'],
        :rails_env => node.dna['environment']['framework_env'],
        :memory_limit => 400 # MB
      })
      notifies :run, "execute[restart-sidekiq-for-#{app_name}]"
    end
    
    # database.yml
    execute "update-database-yml-pg-pool-for-#{app_name}" do
      db_yaml_file = "/data/#{app_name}/shared/config/database.yml"
      command "sed -ibak --follow-symlinks 's/reconnect/pool:      #{node['sidekiq']['concurrency']}\\\n  reconnect/g' #{db_yaml_file}"
      action :run
      only_if "test -f #{db_yaml_file} && ! grep 'pool: *#{node['sidekiq']['concurrency']}' #{db_yaml_file}"
      notifies :run, "execute[restart-sidekiq-for-#{app_name}]"
    end

    # yml files
    node['sidekiq']['workers'].times do |count|
      template "/data/#{app_name}/shared/config/sidekiq_#{count}.yml" do
        owner node['owner_name']
        group node['owner_name']
        mode 0644
        source "sidekiq.yml.erb"
        backup false
        variables(node['sidekiq'])
        notifies :run, "execute[restart-sidekiq-for-#{app_name}]"
      end
    end
  end 
end
