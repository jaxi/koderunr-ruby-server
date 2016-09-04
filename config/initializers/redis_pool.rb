module RedisPool
  extend self

  SIZE = 16
  TIMEOUT = 5

  HOST = "localhost".freeze
  PORT = 6379

  def pool
    @connection ||= ConnectionPool.new(size: SIZE, timeout: TIMEOUT) do
      Redis.connect(host: HOST, port: PORT)
    end
  end

  def with_conn
    pool.with do |conn|
      yield conn
    end
  end
end
