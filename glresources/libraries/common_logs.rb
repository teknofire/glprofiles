class CommonLogs < Inspec.resource(1)
  name 'common_logs'
  desc 'lists of common log files for various services'

  def erchef
    files = %w[erchef.log current crash.log requests.log requests.log.1 requests.log.2 requests.log.3 requests.log.4 requests.log.5 requests.log.6 requests.log.7 requests.log.8 requests.log.9]
    if block_given?
      files.each { |f| yield f }
    else
      files
    end
  end

  def nginx
    files = %w[current error.log access.log internal-chef.access.log]
    if block_given?
      files.each { |f| yield f }
    else
      files
    end
  end

  def pg_hba
    files = %w[opscode-chef-mover/error.log opscode-chef-mover/console.log opscode-chef-mover/crash.log opscode-chef-mover/current opscode-erchef/sasl-error.log opscode-erchef/crash.log opscode-erchef/current opscode-erchef/erchef.log bookshelf/error.log bookshelf/console.log bookshelf/crash.log bookshelf/current oc_bifrost/error.log oc_bifrost/console.log oc_bifrost/crash.log oc_bifrost/current pg_stat_activity.txt private-chef-ctl_status.txt]
    if block_given?
      files.each { |f| yield f }
    else
      files
    end
  end

  def solr4
    files = %w[current]
    if block_given?
      files.each { |f| yield f }
    else
      files
    end
  end

  def ss_ontap
    # automate 2 uses a different filename
    files = %w[ss_ontap.txt ss.txt]
    if block_given?
      files.each { |f| yield f }
    else
      files
    end
  end
end
