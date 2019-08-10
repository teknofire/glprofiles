class LogAnalysis < Inspec.resource(1)
  name 'log_analysis'
  desc 'Parse log files to find issues'

  attr_accessor :logfile, :search
  def initialize(log, expr = nil, **options)
    @options = options || {}

    # max number of bytes to search through in the logs
    # default: 500mb
    @options[:log_limit] ||= 1024 * 1024 * 500

    @search = expr
    @logfile = log
    @summary ||= []
  end

  def messages
    @messages ||= read_content
  end

  def find(expr)
    # reset messages if new search
    @messages = nil
    @search = expr

    messages
    generate_summary(true)

    # make sure we generate a summary for this search
    GLResult.new(logfile, search, last_entry: last_entry, hits: hits, empty?: empty?)
  end

  def hits
    messages.count
  end
  alias_method :count, :hits

  def first
    messages.first
  end

  def last
    messages.last
  end

  def empty?
    messages.empty?
  end

  # this is for use in the matchers so we can get a better UX with the latest
  # log entry text showing up in the verbose output
  def last_entry
    last || ''
  end

  def content
    messages
  end

  def generate_summary(force = false)
    return @summary if hits.zero?
    return @summary if !force && @generated_summary

    @summary.push <<~EOS
      Found #{hits} messages about '#{search}'
      File: #{logfile}
      Last entry: #{last_entry[0..2000]}
    EOS
    @generated_summary = true

    @summary
  end

  def summary
    generate_summary
  end

  def summary!
    summary
  ensure
    # reset after showing summary
    @generated_summary = false
    @summary = []
  end

  def exists?
    hits > 0
  end

  def log_exists?
    inspec.file(logfile).exist?
  end

  def to_s
    "log_analysis(#{logfile}, #{search})"
  end

  private

  def read_content
    cmd = []
    return [] unless File.exist?(log_filename)

    flags = ''
    flags += '-i ' if @options[:case_sensitive] != true
    # osx grep doesn't support -P correctly
    flags += inspec.os.family == 'darwin' ? '-E' : '-P'

    cmd << "grep #{flags} '#{search}' #{log_filename}"

    exec_command(cmd.join(' | ')).stdout.split("\n")
  end

  def log_filename
    @log_filename ||= extract_service_logs
  end

  def extract_service_logs
    return logfile unless File.exist?(logfile)
    return logfile if !@options[:a2service] && File.size(logfile) <= @options[:log_limit]

    service = @options[:a2service]

    @tempfile = Tempfile.new(['gl', logfile, service].compact.join('-'))

    cmd = []
    cmd << "cat #{logfile}"
    cmd << "fgrep -i '#{@options[:a2service]}'" if @options[:a2service]
    cmd << "tail -c#{@options[:log_limit]}"

    exec_command(cmd.join(' | ') + " > #{@tempfile.path}")

    @tempfile.path
  end

  def exec_command(cmd)
    command = inspec.command(cmd)

    if command.exit_status > 1
      raise "#{cmd} exited #{command.exit_status}\nERROR MSG: #{command.stderr}"
    end

    command
  end
end

class GLResult
  attr_reader :logfile, :search

  def initialize(logfile, search, data = {})
    @logfile = logfile
    @search = search
    @data = data
  end

  def last_entry
    fetch :last_entry
  end

  def hits
    fetch :hits
  end
  alias_method :count, :hits

  def empty?
    fetch :empty?
  end

  def to_s
    "grep '#{search}' '#{logfile}'"
  end

  def fetch(item)
    @data[item.to_sym]
  end
end
