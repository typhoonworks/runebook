# frozen_string_literal: true

require "drb/drb"
require "drb/unix"
require "timeout"

module Runebook
  class Runtime
    # Manages a pool of Evaluator processes, one per session.
    # Handles spawning, connecting to, and cleaning up evaluator processes.
    #
    # Uses Redis to track evaluator metadata across Rails processes.
    class EvaluatorPool
      REDIS_KEY_PREFIX = "runebook:evaluator:"
      SPAWN_TIMEOUT = 10 # seconds to wait for evaluator to start

      # Minimal in-process registry fallback when Redis is unavailable.
      # Provides the subset of Redis API we use (get/set/del/scan_each).
      class LocalRegistry
        def initialize
          @store = {}
          @mutex = Mutex.new
        end

        def get(key)
          @mutex.synchronize { @store[key] }
        end

        def set(key, value)
          @mutex.synchronize { @store[key] = value }
        end

        def del(key)
          @mutex.synchronize { @store.delete(key) }
        end

        def scan_each(match: "*")
          regex = Regexp.new("^" + match.gsub("*", ".*") + "$")
          keys = @mutex.synchronize { @store.keys.grep(regex) }
          keys.each { |k| yield k }
        end
      end
      @local_registry = LocalRegistry.new

      class << self
        # Get or create an evaluator for a session
        #
        # @param session_token [String] Unique session token
        # @return [DRbObject] Client proxy to the evaluator
        def get_or_create(session_token)
          if (info = get_evaluator_info(session_token))
            begin
              client = connect_to_evaluator(info[:socket_path])

              if alive?(client)
                update_last_used(session_token)
                return client
              end
            rescue => e
              log_warn("Failed to connect to existing evaluator: #{e.message}")
            end

            # Dead or unresponsive, clean up
            shutdown(session_token)
          end

          spawn_evaluator(session_token)
        end

        # Check if an evaluator is alive
        #
        # @param session_token [String] Session token
        # @return [Boolean]
        def alive?(session_token_or_client)
          if session_token_or_client.is_a?(String)
            info = get_evaluator_info(session_token_or_client)
            return false unless info

            process_exists?(info[:pid])
          else
            # It's a DRb client
            Timeout.timeout(2) { session_token_or_client.alive? }
            true
          end
        rescue
          false
        end

        # Shutdown an evaluator
        #
        # @param session_token [String] Session token
        def shutdown(session_token)
          info = get_evaluator_info(session_token)
          return unless info

          # Try graceful shutdown
          begin
            client = connect_to_evaluator(info[:socket_path])
            client.shutdown
          rescue => e
            log_warn("Failed to shutdown evaluator gracefully: #{e.message}")
          end

          # Force kill if needed
          begin
            Process.kill("KILL", info[:pid]) if process_exists?(info[:pid])
          rescue => e
            log_warn("Failed to kill process #{info[:pid]}: #{e.message}")
          end

          # Cleanup files
          cleanup_files(session_token, info[:socket_path])

          # Remove from Redis
          redis { |r| r.del("#{REDIS_KEY_PREFIX}#{session_token}") }
        end

        # Cleanup orphaned evaluators
        def cleanup_orphaned
          redis do |r|
            r.scan_each(match: "#{REDIS_KEY_PREFIX}*") do |key|
              session_token = key.sub(REDIS_KEY_PREFIX, "")
              info = get_evaluator_info(session_token)
              next unless info

              # Check if session still exists and is active
              session = Session.find_by(token: session_token)
              if session.nil? || session.closed? || session.updated_at < 1.hour.ago
                log_info("Cleaning up orphaned evaluator for session #{session_token}")
                shutdown(session_token)
              elsif !process_exists?(info[:pid])
                log_warn("Evaluator process #{info[:pid]} died unexpectedly for session #{session_token}")
                r.del(key)
              end
            end
          end
        end

        private

        def spawn_evaluator(session_token)
          socket_path = "/tmp/runebook_eval_#{session_token}.sock"
          ready_file = "#{socket_path}.ready"

          # Clean up old files
          File.delete(socket_path) if File.exist?(socket_path)
          File.delete(ready_file) if File.exist?(ready_file)

          # Fork evaluator process
          pid = fork do
            # Redirect standard streams
            STDIN.reopen("/dev/null")
            STDOUT.reopen("/tmp/evaluator_#{session_token}.log", "a")
            STDERR.reopen("/tmp/evaluator_#{session_token}.log", "a")

            # Create and start evaluator
            evaluator = Evaluator.new(session_token)
            evaluator.start_server!
          end

          Process.detach(pid)

          # Wait for evaluator to be ready
          Timeout.timeout(SPAWN_TIMEOUT) do
            sleep 0.1 until File.exist?(ready_file)
          end

          # Store in Redis
          redis do |r|
            r.set(
              "#{REDIS_KEY_PREFIX}#{session_token}",
              {
                pid: pid,
                socket_path: socket_path,
                started_at: Time.current.iso8601,
                last_used_at: Time.current.iso8601
              }.to_json
            )
          end

          log_info("Spawned evaluator process #{pid} for session #{session_token}")

          connect_to_evaluator(socket_path)
        rescue Timeout::Error
          Process.kill("KILL", pid) rescue nil if pid
          cleanup_files(session_token, socket_path)
          raise "Failed to start evaluator process within #{SPAWN_TIMEOUT} seconds"
        rescue => e
          Process.kill("KILL", pid) rescue nil if pid
          cleanup_files(session_token, socket_path)
          raise "Failed to spawn evaluator: #{e.message}"
        end

        def connect_to_evaluator(socket_path)
          sleep 0.1 unless File.exist?(socket_path)
          DRbObject.new_with_uri("drbunix:#{socket_path}")
        end

        def get_evaluator_info(session_token)
          data = redis { |r| r.get("#{REDIS_KEY_PREFIX}#{session_token}") }
          return nil unless data

          JSON.parse(data, symbolize_names: true)
        end

        def update_last_used(session_token)
          key = "#{REDIS_KEY_PREFIX}#{session_token}"
          redis do |r|
            data = r.get(key)
            return unless data

            info = JSON.parse(data)
            info["last_used_at"] = Time.current.iso8601
            r.set(key, info.to_json)
          end
        end

        def process_exists?(pid)
          return false unless pid

          Process.kill(0, pid)
          true
        rescue Errno::ESRCH, Errno::EPERM
          false
        end

        def cleanup_files(session_token, socket_path)
          File.delete(socket_path) rescue nil
          File.delete("#{socket_path}.ready") rescue nil
          File.delete("/tmp/evaluator_#{session_token}.log") rescue nil

          gem_home = "/tmp/runebook_gems_#{session_token}"
          FileUtils.rm_rf(gem_home) if Dir.exist?(gem_home)
        end

        def redis(&block)
          # Prefer configured pool
          if defined?(REDIS_POOL)
            return REDIS_POOL.with(&block)
          end
          # Try direct Redis connection
          if defined?(Redis)
            begin
              client = Redis.new
              # Perform a lightweight ping to confirm availability
              client.ping
              return yield client
            rescue => e
              log_warn("Redis unavailable, falling back to LocalRegistry: #{e.class}: #{e.message}")
            end
          end
          # Fallback to local in-memory registry (per-process)
          yield(@local_registry)
        end

        def log_info(message)
          Rails.logger.info("[EvaluatorPool] #{message}") if defined?(Rails)
        end

        def log_warn(message)
          Rails.logger.warn("[EvaluatorPool] #{message}") if defined?(Rails)
        end

        def log_error(message)
          Rails.logger.error("[EvaluatorPool] #{message}") if defined?(Rails)
        end
      end
    end
  end
end
