# Runner is the runnable class that talks to the
# Docker container and streaming stdin, stdout & stderr
class Runner
  class NotFound < StandardError; end

  def initialize(options = {})
    @lang = options[:lang]
    @source = options[:source]
    @version = options[:version]
    @timeout = options[:timeout]
  end

  def to_hash
    {
      lang: lang,
      source: source,
      version: version,
      timeout: timeout
    }
  end

  def to_json
    to_hash.to_json
  end

  def run!(writer)
    create_container
    start_container
    attach_container do |chunk|
      writer.write chunk
    end
  end

  # Public: Save the runnable to Redis store as a UUID
  #
  # Returns a uuid
  def save
    SecureRandom.uuid.tap do |uuid|
      RedisPool.with_conn do |conn|
        conn.set("#{uuid}#run", to_json)
      end
    end
  end

  def self.find(uuid)
    raw_data = RedisPool.with_conn do |conn|
      conn.get("#{uuid}#run")
    end

    raise NotFound if raw_data.nil?

    new(JSON.parse(raw_data, symbolize_names: true)).tap do |runner|
      runner.uuid = uuid
    end
  end

  def delete
    return unless uuid
    RedisPool.with_conn do |conn|
      conn.del("#{uuid}#run")
    end
  end

  def create_container
    options = {
      name: uuid,
      Image: image,
      NetworkDisabled: true,
      OpenStdin: true,
      Cmd: [source, uuid],
      KernelMemory: 1024 * 1024 * 4
    }
    @container = Docker::Container.create(options)
  end

  def start_container
    @stdin_reader, @stdin_writer = IO.pipe

    container.start!(
      CPUQuota: 20_000,
      MemorySwap: -1,
      Privileged: false,
      CapDrop: ['all'],
      Memory: 80 * 1024 * 1024,
      PidsLimit: 100
    )
  end

  def read_stdin
    RedisPool.with_conn do |conn|
      conn.subscribe_with_timeout(20, "#{uuid}#stdin") do |on|
        on.message do |_channel, message|
          stdin_writer.write(message)
        end
      end
    end
  end

  def attach_container
    Thread.new { read_stdin }
    streaming_container { |output| yield output }
  rescue StandardError => e
    Rails.logger.error e
  end

  def cleanup
    container.stop
    container.remove(force: true)
    delete
  end

  attr_reader :lang, :source, :version, :timeout, :container,
              :stdin_reader, :stdin_writer

  attr_accessor :uuid

  private

  def streaming_container
    Timeout.timeout(timeout) do
      container.attach(stdin: stdin_reader) do |_, chunk|
        chunk.split("\n").each do |piece|
          yield piece
        end
      end

      yield ''
    end
  end

  def image
    ImageSelector.new(lang, version).name
  end
end
