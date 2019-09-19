title 'Basic checks for the chef-server configuration'

chef_backend = installed_packages('chef-backend')

control '000.gatherlogs.chef-backend.package' do
  title 'check that chef-backend is installed'
  desc "
  The installed version of Chef-Backend is old and should be upgraded
  Installed version: #{chef_backend.version}
  "
  tag system: {
    'Product' => "Chef-Backend #{chef_backend.version}"
  }

  only_if { chef_backend.exists? }
  describe chef_backend do
    it { should exist }
    its('version') { should cmp >= '2.0.30' }
  end
end

df = disk_usage

%w[/ /var /var/opt /var/opt/chef-backend /var/log /var/log/chef-backend].each do |mount|
  control "gatherlogs.chef-backend.critical_disk_usage.#{mount}" do
    title "check that #{mount} has plenty of free space"
    desc "
      there are several key directories that we need to make sure have enough
      free space for chef-backend to operate succesfully
    "

    only_if { df.exists?(mount) }

    describe df.mount(mount) do
      its('used_percent') { should cmp < 100 }
      its('available') { should cmp > disk_usage.to_filesize('250M') }
    end
  end
end

control '010.gatherlogs.chef-backend.required_memory' do
  title 'Check that the system has the required amount of memory'

  desc "
Chef recommends that the Backend system has at least 8GB of memory.
Please make sure the system means the minimum hardware requirements
"

  tag kb: 'https://automate.chef.io/docs/system-requirements/'
  tag verbose: true
  tag system: {
    'Total Memory' => "#{memory.total_mem} MB",
    'Free Memory' => "#{memory.free_mem} MB"
  }

  describe memory do
    # rough calculation for 8gb because of reasons
    its('total_mem') { should cmp >= 7168 }
    its('free_swap') { should cmp > 0 }
  end
end

control '010.gatherlogs.chef-backend.required_cpu_cores' do
  title 'Check that the system has the required number of cpu cores'

  desc "
Chef recommends that the Chef-Backend systems have at least 2 cpu cores.
Please make sure the system means the minimum hardware requirements
"

  tag kb: 'https://docs.chef.io/install_server_ha.html#hardware-requirements'
  tag verbose: true
  if cpu_info.exists?
    tag system: {
      'CPU Cores' => cpu_info.total,
      'CPU Model' => cpu_info.model_name
    }
  end

  describe cpu_info do
    # rough calculation for 8gb because of reasons
    its('total') { should cmp >= 2 }
  end
end

services = service_status(:chef_backend)

control "gatherlogs.chef-backend.service_status" do
  title "check that services are running"
  desc "There was a problem with one or more services.  Please check that it's
running, doesn't have a short run time, or the health checks are reporting an issue."
  tag verbose: true

  describe services do
    it { should_not be_empty }
  end

  summaries = []
  services.internal do |service|
    describe service do
      its('status') { should eq 'running' }
      its('runtime') { should cmp >= 90 }
    end
    summaries << service.summary
  end

  tag summary: summaries
end

# the clock difference against peer d4fed0cf06663880 is too high
etc_current = log_analysis('var/log/chef-backend/etcd/current')
control 'gatherlogs.chef-backend.clock_out_of_sync' do
  title 'Check to see if ETCD is reporting issues with clocks being out of sync'
  desc "
ETCD is reporting issues with the local system clocking being too far out of sync with other peers.

Ensure that `chrony` or `ntpd` services are installed and running to keep the clocks in sync.
  "
  describe etc_current.find('the clock difference against peer .* is too high') do
    its('last_entry') { should be_empty }
  end
  tag summary: etc_current.summary!
end

# 2019-09-19_18:54:10.99164 2019-09-19 18:54:10.990330 C | etcdmain: cannot access data directory: mkdir /var/opt/chef-backend/etcd/data: permission denied
control 'gatherlogs.chef-backend.etc_cannot_mkdir_data_directory' do
  title 'Check to see if ETCD is reporting errors trying to create its data directory'
  desc "
ETCD is reporting errors trying to create its data directory.

If `/var/opt` or `/var/opt/chef-backend` storage is provided via a separate mount
ensure that it is working correctly and that the permissions are correct for that
mount.
  "

  describe etc_current.find('cannot access data directory: .* /var/opt/chef-backend/etcd/data') do
    its('last_entry') { should be_empty }
  end
  tag summary: etc_current.summary!
end
