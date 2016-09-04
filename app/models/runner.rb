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
      timeout: timeout,
    }
  end

  def to_json
    to_hash.to_json
  end

  # Public: Save the runnable to Redis store as a UUID
  #
  # Returns a uuid
  def save
    SecureRandom.uuid.tap do |uuid|
      self.class.store.set("#{uuid}#run", to_json)
    end
  end

  def self.find(uuid)
    stored_data = self.store.get("#{uuid}#run")

    raise NotFound if stored_data.nil?

    new(JSON.parse(stored_data, symbolize_names: true)).tap do |runner|
      runner.uuid = uuid
    end
  end

  def delete
    self.class.store.del("#{uuid}#run") if uuid
  end

  def create_container
    options = {
      "name" => uuid,
      "Image": image,
      "NetworkDisabled" => true,
      "OpenStdin" => true,
      "Cmd" => [source, uuid],
      "KernelMemory": 1024 * 1024 * 4,
    }
    @container = Docker::Container.create(options)
  end

  def start_container
    @stdin_reader, @stdin_writer = IO.pipe

    container.start!(
      "CPUQuota" => 20000,
      "MemorySwap" => -1,
      "Privileged" => false,
      "CapDrop" => ["all"],
      "Memory" => 80 * 1024 * 1024,
      "PidsLimit" => 100
    )
  end

  def read_stdin
    self.class.store.subscribe_with_timeout(20, "#{uuid}#stdin") do |on|
      on.message do |channel, message|
        stdin_writer.write(message)
      end
    end
  end

  def attach_container
    Thread.new { read_stdin }

    Timeout::timeout(timeout) do
      container.attach(stdin: stdin_reader) do |_, chunk|
        chunk.split("\n").each do |piece|
          yield piece
        end
      end

      yield ""
    end
  rescue Timeout::Error
    container.stop
    container.remove(force: true)
    delete
  end

  attr_reader :lang, :source, :version, :timeout, :container

  attr_reader :stdin_reader, :stdin_writer

  attr_accessor :uuid

  private

  def self.store
    @store ||= Redis.new(host: "localhost", port: 6379)
  end

  def image
    selected_version = version
    available_versions = LANGUAGE_VERSIONS[lang]

    if selected_version.blank?
      if available_versions.length > 0
        selected_version = available_versions.first
      else
        selected_version = "latest"
      end
    end

    "#{DOCKER_IMAGES[lang]}:#{selected_version}"
  end
end
