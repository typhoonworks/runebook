Rails.application.config.after_initialize do
  REDIS_POOL = ConnectionPool.new(size: 10, timeout: 5) do
    Redis.new(
      url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
      timeout: 1,
      reconnect_attempts: 3
    )
  end
end
