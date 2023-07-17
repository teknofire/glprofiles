# read-only indices
control 'gatherlogs.common.elasticsearch_cluster_state' do
  title 'Check Elasticsearch for a RED state'
  desc "
  Elasticsearch status is reporting as RED, this can occur if one or more primary shards have failed
  and no replicas are available to recover from.

  To determine why Elasticsearch is unable to recover check for messages in `/var/log/opscode/elasticsearch/current`
  as well as the output from the following commands:

  Elasticsearch ports ($ES_PORT):
    Chef Infra Server: 9200
    Automate: 10144

  * curl -XGET localhost:$ES_PORT/_cluster/allocation/explain?pretty
  * curl -XGET localhost:$ES_PORT/_cat/shards?h=index,shard,prirep,state,unassigned.reason| grep UNASSIGNED
  "

  tag kb: 'https://getchef.zendesk.com/hc/en-us/articles/360039852032-Abstract-and-remediation-for-Chef-Automate-services-down-Elasticsearch-in-CRITICAL-state-web-UI-and-client-runs-failing-with-500-errors'

  describe json('elasticsearch_cluster_health.txt') do
    its('status') { should_not eq 'red' }
  end
end
