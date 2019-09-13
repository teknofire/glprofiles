# Aug 25 06:02:01 hab[24744]: backup-gateway.default(O): Error: Rename across devices not allowed, please fix your backend configuration (/hab/svc/backup-  gateway/data/.minio.sys/tmp/f726a257-b969-4518-80bd-522b9fa9ebda/9b31252f-932f-4a8c-88dc-93a510c9bf4f)->(/hab/svc/backup-gateway/data/backups/20190325060201/.status)
bg_logs = log_analysis('journalctl_chef-automate.txt', a2service: 'backup-gateway.default')

control 'gatherlogs.automate2.backups_delete_rename_across_device' do
  impact 'medium'
  title 'Check to see if Automate is reporting a failure with backups due to rename across devices error'
  desc "
Automate is encountering an error while trying to perform a backup operation.
The failure is happening while trying to perform a rename across devices.

This can happen when `/hab` and `/var/opt/chef-automate/backups` are mounted
from different devices.

Upgrading Automate to the latest version or >= 20190325233053 will fix this issue
  "
  describe bg_logs.find('Rename across devices not allowed') do
    its('last_entry') { should be_empty }
  end
  tag summary: bg_logs.summary!
end
