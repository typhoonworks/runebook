# frozen_string_literal: true

# Clean up any stale evaluator processes and socket files on Rails startup
# This handles the case where Rails is restarted but old evaluators are still referenced in Redis

Rails.application.config.after_initialize do
  next unless Rails.env.development? || Rails.env.test?

  Rails.logger.info "[Runtime] Cleaning up stale evaluators on startup..."

  # Kill any orphaned evaluator processes and clean up Redis entries
  begin
    if defined?(REDIS_POOL)
      REDIS_POOL.with do |redis|
        redis.scan_each(match: "runebook:evaluator:*") do |key|
          begin
            data = redis.get(key)
            if data
              info = JSON.parse(data, symbolize_names: true)
              # Try to kill the process if it exists
              Process.kill("TERM", info[:pid]) rescue nil
              sleep 0.1
              Process.kill("KILL", info[:pid]) rescue nil
            end
          rescue => e
            Rails.logger.debug "[Runtime] Error killing process: #{e.message}"
          end
          redis.del(key)
        end
      end
    end
  rescue => e
    Rails.logger.warn "[Runtime] Failed to clean up Redis: #{e.message}"
  end

  # Clean up any orphaned socket files
  Dir.glob("/tmp/runebook_eval_*.sock*").each do |file|
    File.delete(file) rescue nil
  end

  # Clean up evaluator log files
  Dir.glob("/tmp/evaluator_*.log").each do |file|
    File.delete(file) rescue nil
  end

  # Clean up gem directories
  Dir.glob("/tmp/runebook_gems_*").each do |dir|
    FileUtils.rm_rf(dir) rescue nil
  end

  Rails.logger.info "[Runtime] Cleanup complete"
end
