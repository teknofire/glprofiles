lb_logs = log_analysis('journalctl_chef-automate.txt', a2service: 'automate-load-balancer.default')
ds_logs = log_analysis('journalctl_chef-automate.txt', a2service: 'deployment-service.default')

# level=error msg="Phase failed" error="hab-sup upgrade pending" phase="supervisor upgrade"
control 'gatherlogs.automate2.upgrade_failed' do
  impact 'critical'
  title 'Check to see if Automate is reporting a failure during the hab sup upgrade process'
  desc "
It appears that there was a failure during the upgrade process for Automate, please
check the logs and contact support to see about getting this fixed."

  tag kb: 'https://automate.chef.io/release-notes/20180706210448/#hanging-stuck-upgrades'

  describe ds_logs.find('level=error msg="Phase failed" error="hab-sup upgrade pending" phase="supervisor upgrade"') do
    its('last_entry') { should be_empty }
  end
  tag summary: ds_logs.summary!
end

control 'gatherlogs.automate2.auth_upstream_header_too_big' do
  impact 'medium'
  title 'Check to see if Automate is reporting a failure getting data from an upstream LDAP source'
  desc "
Automate is reporting errors fetching data from an upstream LDAP source. This commonly
occurs when LDAP returns too many groups or referencing LDAP groups by distinguished names (DN).

To resolve this you will need to add a `group_query_filter` to your Automate configs to
filter which groups Automate should use
  "
  tag kb: 'https://automate.chef.io/docs/ldap/#other-common-issues'

  describe lb_logs.find('upstream sent too big header while reading response header from upstream.*dex/auth/ldap') do
    its('last_entry') { should be_empty }
  end
  tag summary: lb_logs.summary!
end

control 'gatherlogs.automate2.loadbalancer_worker_connections' do
  title 'Check to see if Automate is reporting a error with not enough workers for the load balancer'
  desc "
This is an issue with older version of Automate 2 without persistant connections.
Please upgrade to the latest Automate version.

If running a recent version of Automate 2 then check to make sure there are no
issues with ElasticSearch, if there are a large number of GC events or disk io
problems then the ingestion process can get backed up and cause take up all the
available workers.
  "

  describe lb_logs.find('worker_connections are not enough') do
    its('last_entry') { should be_empty }
  end
  tag summary: lb_logs.summary!
end

butterfly_error = log_analysis('journalctl_chef-automate.txt', 'Butterfly error: Error reading or writing to DatFile', a2service: 'hab-sup')
control 'gatherlogs.automate2.butterfly_dat_error' do
  title 'Check to see if Automate is reporting an error reading or write to a DatFile'
  desc '
  The Habitat supervisor is having problems reading or writing to an internal DatFile.

  To fix this you will need to remove the failed DatFile and restart the Automate 2 services.
  '

  tag summary: butterfly_error.summary!

  describe butterfly_error do
    its('last_entry') { should be_empty }
  end
end

# FATAL:  sorry, too many clients already
pg_client_count = log_analysis('journalctl_chef-automate.txt', 'FATAL:\s+sorry, too many clients already', a2service: 'automate-postgresql.default')
control 'gatherlogs.automate2.postgresql_too_many_clients_error' do
  title 'Check to see if PostgreSQL is complaining about too many client connections'

  desc "
There appears to be too many client connections to PostgreSQL, this is a non-fatal issue
as connections should be queued.
"

  tag summary: pg_client_count.summary!

  describe pg_client_count do
    its('last_entry') { should be_empty }
  end
end

panic_errors = log_analysis('journalctl_chef-automate.txt', 'panic: runtime error:')
control 'gatherlogs.automate2.panic_errors' do
  title 'Check to see if there are any panic errors in Automate logs'
  desc "
There appears to be some issue with a service throwing panic errors.  Please
check the logs for more information about what service is crashing and contact
support to in order to resolve this issue.
  "

  tag summary: panic_errors.summary!
  describe panic_errors do
    its('last_entry') { should be_empty }
  end
end

control 'gatherlogs.automate2.rootcert_permissions_error' do
  title 'Check for permission error when generating root TLS certificate'
  desc "
Automate was unable to generate a new root TLS certificate, this is needed to
create certificates used for service communication.

To fix this error you will need to manually modify the permissons in
`/hab/svc/deployment-service/data/`.

```
chmod 0440 /hab/svc/deployment-service/data/Chef_Automate*.key
chmod 0444 /hab/svc/deployment-service/data/Chef_Automate*.crt /hab/svc/deployment-service/data/Chef_Automate*.crl
```
  "

  cert_error = 'failed to generate TLS certificate: failed to generate deployment-service TLS certificate: certstrap sign failure: Get CA certificate error: permission denied'
  describe ds_logs.find(cert_error) do
    its('last_entry') { should be_empty }
  end
  tag summary: ds_logs.summary!
end

saml_audience_check = log_analysis('journalctl_chef-automate.txt', 'Failed to authenticate: required audience', a2service: 'automate-dex.default')
control 'gatherlogs.automate2.failed_saml_audience_response' do
  title 'Check for errors related to failed audience checks for SAML IdP responses'
  desc "
Automate was unable to validate the SAML assertion for `AudienceRestriction` contained a valid value.

Possible ways to fix this:
1. Ensure that the response from the SAML IdP contains `https://AUTOMATE_HOST/dex/callback` in the response XML
2. Disable `AudienceRestriction` on the SAML IdP
3. Set `entity_issuer` in `[dex.v1.sys.connectors.saml]` to the value it should match (https://automate.chef.io/docs/configuration/#saml)
  "

  tag kb: 'https://automate.chef.io/docs/configuration/#saml'

  tag summary: saml_audience_check.summary!
  describe saml_audience_check do
    its('last_entry') { should be_empty }
  end
end

# unable to migrate a  TimeSeries index in Elasticsearch, error: migrateTimeSeries error
compliance_logs = log_analysis('journalctl_chef-automate.txt', a2service: 'compliance-service.default')
control 'gatherlogs.automate2.elasticsearch_compliance_migration_error' do
  title 'Check to see if ElasticSearch has issues migrating compliance indices'
  desc "
Compliance service is reporting an error while trying to migrate indices

A fix for this is pending and will be released in version > 20190729085402, in
the meantime the only way to fix this is to delete the offending index
  "

  describe compliance_logs.find('unable to migrate a TimeSeries index in Elasticsearch, error: migrateTimeSeries error') do
    its('last_entry') { should be_empty }
  end
  tag summary: compliance_logs.summary!
  tag kb: 'https://github.com/chef/automate/pull/1153'
end

# Sep 03 14:09:54 hab[734]: deployment-service.default(O): time="2019-09-03T14:09:54Z" level=warning msg="Skipping periodic converge because disable file is present" file=/hab/svc/deployment-service/data/converge_disable
control 'gatherlogs.automate2.deployment_service_converge_disabled' do
  title 'Check to see if converge_disable sentinel file is present'
  desc "
The `converge_disable` sentinel file is present which prevents the deployment
service from operating normally. If this file is present *do not* run
`chef-automate restart-services` as this can cause the system to become stuck
and unable to continue any action that was running that required the file to be
created.

This file is created during a restore and gets left behind when it fails, to
prevent the deployment service from reconverging and giving the illusion that
the restore was successful and Automate is running correctly.

Please check the timestamp of the last message to ensure that it's not an old
message from a previous action that was taking place on the system
  "

  describe ds_logs.find('Skipping periodic converge because disable file is present') do
    its('last_entry') { should be_empty }
  end
  tag summary: ds_logs.summary!
end

# Sep 09 17:44:58 hab[8384]: deployment-service.default(O): time="2019-09-09T17:44:58Z" level=info msg="finished unary call with code InvalidArgument" error="rpc error: code = InvalidArgument desc = \nConfiguration key 'compliance.v1.sys.retention' has been deprecated and is no longer allowed. Configure the retention data lifecycle with the chef.automate.domain.data_lifecycle.api.Purge gRPC interface\n" grpc.code=InvalidArgument grpc.method=PatchAutomateConfig grpc.service=chef.automate.domain.deployment.Deployment grpc.start_time="2019-09-09T17:44:58Z" grpc.time_ms=29.635 span.kind=server system=grpc
control 'gatherlogs.automate2.deprecated_config_keys' do
  title 'Check to see if applying a config update failed due to deprecated key'
  desc "
The following config keys were deprecated in version 20190904132002
  * compliance.v1.sys.retention.compliance_report_days
  * event_feed_service.v1.sys.service.purge_event_feed_after_days
  * ingest.v1.sys.service.purge_converge_history_after_days
  * ingest.v1.sys.service.purge_actions_after_days
  * data_lifecycle

To fix this error remove the keys from the config toml and run
`chef-automate config set/patch` again.
  "

  describe ds_logs.find('Configuration key .* has been deprecated and is no longer allowed') do
    its('last_entry') { should be_empty }
  end
  tag summary: ds_logs.summary!
  tag kb: 'https://automate.chef.io/docs/configuration/#data-retention'
end

control 'gatherlogs.automate2.load_balancer_timeout_errors' do
  title 'Check to see if Automate is reporting errors in the automate-loadbalancer due to upstream timeouts'
  desc "
Automate loadbalancer is reporting errors connecting to the upstream node.

Please check the status of the upstream service to find any additional errors
  "

  describe lb_logs.find('upstream timed out') do
    its('last_entry') { should be_empty }
  end
  tag summary: lb_logs.summary!
end



# unable to migrate a  TimeSeries index in Elasticsearch, error: migrateTimeSeries error
compliance_logs = log_analysis('journalctl_chef-automate.txt', a2service: 'compliance-service.default')
control 'gatherlogs.automate2.inspec_minimum_version_error' do
  title 'Check to see if ElasticSearch has issues migrating compliance indices'
  desc "
Compliance service is reporting an error while trying to migrate indices

A fix for this is pending and will be released in version > 20190729085402, in
the mean time the only way to fix this is to delete the offending index
  "

  describe compliance_logs.find('unable to migrate a TimeSeries index in Elasticsearch, error: migrateTimeSeries error') do
    its('last_entry') { should be_empty }
  end
  tag summary: compliance_logs.summary!
  tag kb: 'https://github.com/chef/automate/pull/1153'
end
