class ServiceStatus < Inspec.resource(1)
  name 'service_status'
  desc 'Parse the service status for given product'

  def initialize(product)
    @product = product
  end

  def content
    @content ||= case @product.to_sym
                 when :automate, :chef_server
                   parse_services
                 when :automate2
                   parse_a2_services
                 when :chef_backend
                   parse_backend_services
                 end
  end

  def method_missing(service)
    content[service.to_sym] || super
  end

  def respond_to_missing?(service, include_private = false)
    content.key?(service.to_sym) || super
  end

  def internal_service?(name)
    internal.key?(name)
  end

  def exists?
    inspec.file(status_file).exist?
  end

  def internal
    if block_given?
      content[:internal].each do |_service, service_object|
        yield service_object
      end
    else
      content[:internal]
    end
  end

  def external
    if block_given?
      content[:external].each do |_service, service_object|
        yield service_object
      end
    else
      content[:external]
    end
  end

  def to_s
    "service log #{status_file}"
  end

  def empty?
    internal.empty? && external.empty?
  end

  private

  def status_file
    case @product.to_sym
    when :automate
      'delivery-ctl-status.txt'
    when :chef_server
      'private-chef-ctl_status.txt'
    when :chef_backend
      'chef-backend-ctl-status.txt'
    when :automate2
      'chef-automate_status.txt'
    end
  end

  def parse_a2_services
    services = { internal: {}, external: {} }

    read_content.each_line do |line|
      next if line =~ /^chef-automate_status$/
      next if line =~ /^\s*$/ # blank lines
      next if line =~ /^Service Name/

      service, status, health, runtime, pid = line.split(/\s+/)
      services[:internal][service] = ServiceObject.new(name: service, status: status, pid: pid, runtime: runtime.to_i, health: health, internal: true)
    end
    services
  end

  def parse_backend_services
    services = { internal: {}, external: {} }

    read_content.each_line do |line|
      # skip header
      match = line.match(/^(\w+)\s+(\w+)\s+\(pid (\w+)\)\s+(\d+d \d+h \d+m \d+s)\s+(.*)$/)
      puts match.inspect
      next if match.nil?

      _dummy, service, status, pid, runtime, health = *match.to_a
      days, hours, minutes, seconds = *runtime.split(/\s/).map(&:to_i)
      runtime = days * (24 * 3600) + hours * 3600 + minutes * 60 + seconds

      services[:internal][service] = ServiceObject.new(name: service, status: status, pid: pid, runtime: runtime.to_i, health: health, internal: true)
    end

    services
  end

  def parse_services
    services = { internal: {}, external: {} }
    is_internal = true
    read_content.each_line do |line|
      next if line[0] == '-'
      next if line =~ /^\s*$/ # blank lines
      next if line =~ /Internal Services/

      if /External Services/.match?(line)
        is_internal = false
        next
      end

      service_line, _log_line = line.gsub(/[:\(\)]/, '').split(';')

      if is_internal
        status, service, _dummy, pid, runtime = service_line.split(/\s+/)
        services[:internal][service] = ServiceObject.new(name: service, status: status, pid: pid, runtime: runtime.to_i, internal: is_internal)
      else
        status, service, _dummy, constatus, _dummy, host = service_line.split(/\s+/)
        services[:external][service] = ServiceObject.new(name: service, status: status, internal: is_internal, connection_status: constatus, host: host)
      end
    end

    services
  end

  def read_content
    f = inspec.file(status_file)
    if f.file?
      f.content
    else
      ''
    end
  end
end

class ServiceObject
  def initialize(args)
    @args = args
  end

  def exist?
    true
  end

  def method_missing(field)
    @args[field.to_sym] || super
  end

  def respond_to_missing?(field, include_private = false)
    @args.key?(field.to_sym) || super
  end

  def summary
    %w[name status runtime health].map do |key|
      next unless @args.include?(key.to_sym)

      "#{key.capitalize}: #{@args[key.to_sym]}"
    end.join(', ')
  end

  def to_s
    @args[:name] || 'Unknown'
  end
end
