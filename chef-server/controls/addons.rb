reporting = installed_packages('opscode-reporting')
manage = installed_packages('chef-manage')
manage = installed_packages('opscode-manage') unless manage.exists?
sync = installed_packages('chef-sync')

control '030.gatherlogs.chef-server.reporting-with-2018-partition-tables' do
  title 'Make sure Reporting is uninstalled and all data removed'
  desc "
  Reporting has been EOL since 2018. Recommend that the customer follow the knowlege base article link to remove it

  Version: #{reporting.version}
"

  tag kb: 'https://getchef.zendesk.com/hc/en-us/articles/360049009791-Uninstall-Reporting-Add-on-502-503-POST-error-to-the-runs-API-endpoint-'

  sysinfo = {
    'Reporting' => reporting.exists? ? reporting.version : 'Not Installed',
    'Manage' => manage.exists? ? manage.version : 'Not Installed'
  }
  sysinfo['Sync'] = sync.version if sync.exists?

  tag system: sysinfo

  only_if { reporting.exists? }

  describe reporting do
    its('version') { should cmp >= '1.7.10' }
  end
end
