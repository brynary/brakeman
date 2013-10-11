require 'bertrpc'

class SmokeClient
  DEFAULT_TIMEOUT = 20

  def initialize(uri, timeout = nil)
    @uri = uri
    @timeout = timeout
  end

  def method_missing(remote_method_name, *args)
    start_time = Time.now
    result = mod.send(remote_method_name, repo_id.to_s, *args)
    duration = ((Time.now - start_time) * 1_000).round
    SmokeInstrumentation.call(remote_method_name, duration)
    result
  end

  def repo_id
    @repo_id ||= uri_parts[1]
  end

  def mod
    service.call.send(module_name)
  end

  def service
    @service ||= ::BERTRPC::Service.new(@uri.host, @uri.port, @timeout || DEFAULT_TIMEOUT)
  end

  def module_name
    @module_name ||= uri_parts[0]
  end

  def uri_parts
    @uri_parts ||= @uri.path.sub(/^\//, "").split("/")
  end
end

class SmokeInstrumentation

  def self.runtime=(value)
    @runtime = value
  end

  def self.runtime
    @runtime ||= 0
  end

  def self.call_count=(value)
    @smoke_call_count = value
  end

  def self.call_count
    @smoke_call_count ||= 0
  end

  def self.call(remote_method_name, duration)
    return unless $statsd
    self.runtime += duration
    self.call_count += 1
    $statsd.timing    "worker.brakeman.smoke.time", duration
    $statsd.timing    "worker.brakeman.smoke.#{remote_method_name}.time", duration
    $statsd.increment "worker.brakeman.smoke.calls"
    $statsd.increment "worker.brakeman.smoke.#{remote_method_name}.calls"
  end
end
