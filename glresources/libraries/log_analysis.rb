class LogAnalysis < Inspec.resource(1)
  name 'log_analysis'
  desc 'Parse log files to find issues'

  attr_accessor :logfile, :search, :messages
  def initialize(log, expr = nil, **options)
    @options = options || {}

    # setting this default fairly high, most logs are limited to 10000 lines
    # except for Automate v2 which includes the entire journalctl log output.
    @options[:log_limit] ||= 500000

    @search = expr
    @logfile = log
  end

  def messages
    @messages ||= read_content
  end

  def find(expr)
    # reset messages if new search
    @messages = nil
    @search = expr

    messages
    generate_summary

    # make sure we generate a summary for this search
    GLResult.new(logfile, search, last_entry: last_entry, hits: hits, empty?: empty? )
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

  def generate_summary
    @summary ||= []

    return if hits.zero?

    @generated_summary = true
    @summary.push <<~EOS
      Found #{hits} messages about '#{search}'
      File: #{logfile}
      Last entry: #{last_entry[0..2000]}
    EOS

    @summary
  end

  def summary
    @generated_summary ? @summary : generate_summary
  end

  def summary!
    summary
  ensure
    # reset after showing summary
    @generated_summary = false
    @summary = nil
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

    return [] unless File.exist?(logfile)

    flags = ''
    flags += '-i ' if @options[:case_sensitive] != true
    flags += inspec.os.family == 'darwin' ? '-E' : '-P'

    cmd << "tail -n#{@options[:log_limit]} #{logfile}"
    cmd << "grep -i '#{@options[:a2service]}'" if @options[:a2service]
    cmd << "grep #{flags} '#{search}'"

    command = inspec.command(cmd.join(' | '))

    if command.exit_status > 1
      raise "#{cmd.join(' | ')} exited #{command.exit_status}\nERROR MSG: #{command.stderr}"
    end

    command.stdout.split("\n")
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
