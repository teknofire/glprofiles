es_disk = log_analysis('var/log/chef-backend/elasticsearch/current', 'one or more nodes has gone under the high or low watermark')

control 'gatherlogs.chef-backend.elasticsearch-disk-space-errors' do
  impact 1
  title 'Check to see if ElasticSearch is erroring because of available disk space'
  desc "
When ElasticSearch detects that there is not enough free space on the disk it
will reroute shards to other nodes and if space becomes critical enough will
stop accepting new documents to prevent corrupting the database.  You will need
to free up disk space to fix this issue.
  "

  tag summary: es_disk.summary

  describe es_disk do
    its('last_entry') { should be_empty }
  end
end

es_gc = log_analysis('var/log/chef-backend/elasticsearch/current', '\[o.e.m.j.JvmGcMonitorService\] .* \[gc\]')
control 'gatherlogs.chef-backend.elasticsearch-high-gc-counts' do
  impact 'high'
  title 'Check to see if the ElasticSearch is reporting large number of GC events'
  desc "
The ElasticSearch service is reporting a large number of GC events, this is usually
an indication that the heap size needs to be increased.
  "
  tag summary: es_gc.summary

  describe es_gc do
    its('hits') { should cmp <= 10 }
  end
end

control 'gatherlogs.chef-server.postgresql_samenet_issue' do
  title 'Check to see if pg_hba.conf might be missing addresses'
  desc "
PostgreSQL is reporting that pg_hba.conf has not been updated with the IP addresses
of all of the nodes in the cluster. Please refer to the documentation to update the
postgresql.md5_auth_cidr_addresses setting on your Chef Backend HA nodes, or the
appropriate setting for your postgresql clustering mechanism.
"
  common_logs.pg_hba do |logfile|
    pg_hba_conf = log_analysis(
      "./#{logfile}",
      'FATAL:  no pg_hba.conf entry'
    )
    tag summary: pg_hba_conf.summary
    describe pg_hba_conf do
      its('last_entry') { should be_empty }
    end
  end
end
