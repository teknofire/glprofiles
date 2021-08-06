es_cluster_state = log_analysis('elasticsearch_cluster_state.txt')

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
