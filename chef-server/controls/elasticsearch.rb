es_cluster_state = log_analysis('elasticsearch_cluster_state.txt')
es_logs = log_analysis('var/log/opscode/elasticsearch/current')

# read-only indices
control 'gatherlogs.chef-server.elasticsearch_read_only_indicies' do
  title 'Check to see if Elasticsearch is reporting any indicies as read_only'
  desc "
  Elasticsearch is reporting that some indices are read-only. Typically this
  happens when the disk that contains the Elasticsearch database runs low on
  available free space.

  Once the disk space issues are resolved, you can remove the read-only flag by
  running the following command from the Chef Infra Server:
    curl -k -XPUT -H \"Content-Type: application/json\" http://localhost:9200/_all/_settings -d '{\"index.blocks.read_only_allow_delete\": null}'
  "

  tag kb: 'https://getchef.zendesk.com/hc/en-us/articles/360048195791-Chef-Infra-Server-data-var-disk-full-100-500-smell-something-burning-?source=search&auth_token=eyJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjo0ODU4NDUsInVzZXJfaWQiOjM2MTUwMzUwMTQ3MSwidGlja2V0X2lkIjoyNjk1NSwiY2hhbm5lbF9pZCI6NjMsInR5cGUiOiJTRUFSQ0giLCJleHAiOjE2MTQwOTE0OTZ9.JBg-oM4OcNzjUiPKpo75gOkb3cwKj6sg2dhFHXv1x1o'

  describe es_cluster_state.find('"read_only_allow_delete"\s+:\s+"true"') do
    its('last_entry') { should be_empty }
  end
  tag summary: es_cluster_state.summary!
end

# primary shard is not active
control 'gatherlogs.automate2.elasticsearch_failed shards' do
  title 'Check to see if Elasticsearch is reporting issues with failed shards'
  desc "
Elasticsearch is reporting that there are some shards are unavailable.

To attempt a retry for the shards, issue the following

    curl -XPOST 'localhost:9200/_cluster/reroute?retry_failed&pretty'

If that gives an error saying the shard is already assigned, then you will need to issue a flush to clear
the sync ID per each associated index that you received the 'already assigned' error for, and then retry
the above reroute command

    curl -XPOST 'localhost:9200/INDEX_NAME/_flush?force=true&pretty'
  "
  describe es_logs.find('failed shard') do
    its('last_entry') { should be_empty }
  end
  describe es_logs.find('primary shard is not active') do
    its('last_entry') { should be_empty }
  end
  describe es_logs.find('org.elasticsearch.action.search.SearchPhaseExecutionException: all shards failed') do
    its('last_entry') { should be_empty }
  end
  tag summary: es_logs.summary!
end

control 'gatherlogs.chef-server.elasticsearch_corrupted_translog' do
  title 'Check to see if there are any errors about corrupted transaction logs'
  desc "
Elasticsearch is reporting errors for possibly truncated or corrupted transaction
logs.  This can happen if there was a disk full event that occured or if the ES
service was unexpectedly terminated.

To resolve this:
1. Stop Chef Infra Server services: chef-server-ctl stop
2. Fix/Remove the bad transaction log file
3. Start the services again: chef-server-ctl start
  "

  tag kb: [
    'https://www.elastic.co/guide/en/elasticsearch/reference/6.8/shard-tool.html'
  ]

  describe es_logs.find('TranslogCorruptedException') do
    its('last_entry') { should be_empty }
  end
  tag summary: es_logs.summary!
end
