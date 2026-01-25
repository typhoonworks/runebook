# frozen_string_literal: true

require "stringio"

module Runebook
  class Runtime
    # Captures and streams output during code evaluation.
    # Inspired by Livebook's IOProxy with buffering and periodic flushing.
    #
    # Redirects $stdout and $stderr, buffers output, and streams to
    # ActionCable subscribers in real-time.
    class IOProxy
      FLUSH_INTERVAL_MS = 50

      attr_reader :session_token, :cell_ref, :stdout_buffer, :stderr_buffer

      def initialize(session_token:, cell_ref:)
        @session_token = session_token
        @cell_ref = cell_ref
        @stdout_buffer = StringIO.new
        @stderr_buffer = StringIO.new
        @mutex = Mutex.new
        @flush_thread = nil
        @stop_flushing = false
      end

      # Capture output from a block, streaming incrementally via ActionCable
      #
      # @yield The code block to capture output from
      # @return [Hash] { stdout:, stderr: } with captured output
      def capture(&block)
        original_stdout = $stdout
        original_stderr = $stderr

        # Create custom IO objects that write to our buffers
        $stdout = BufferedWriter.new(self, :stdout)
        $stderr = BufferedWriter.new(self, :stderr)

        start_flush_timer

        begin
          yield
        ensure
          stop_flush_timer
          flush # Final flush
          $stdout = original_stdout
          $stderr = original_stderr
        end

        {
          stdout: @stdout_buffer.string,
          stderr: @stderr_buffer.string
        }
      end

      # Write data to the buffer
      #
      # @param data [String] Data to write
      # @param stream [Symbol] :stdout or :stderr
      def write(data, stream:)
        @mutex.synchronize do
          buffer = stream == :stderr ? @stderr_buffer : @stdout_buffer
          buffer.write(data)
        end
      end

      # Flush buffered output to ActionCable
      def flush
        stdout_content, stderr_content = @mutex.synchronize do
          stdout = @stdout_buffer.string.dup
          stderr = @stderr_buffer.string.dup

          # Clear buffers
          @stdout_buffer.truncate(0)
          @stdout_buffer.rewind
          @stderr_buffer.truncate(0)
          @stderr_buffer.rewind

          [ stdout, stderr ]
        end

        return if stdout_content.empty? && stderr_content.empty?

        broadcast_output(stdout_content, stderr_content)
      end

      private

      def start_flush_timer
        @stop_flushing = false
        @flush_thread = Thread.new do
          until @stop_flushing
            sleep(FLUSH_INTERVAL_MS / 1000.0)
            flush unless @stop_flushing
          end
        end
      end

      def stop_flush_timer
        @stop_flushing = true
        @flush_thread&.join(0.1)
        @flush_thread = nil
      end

      def broadcast_output(stdout, stderr)
        # Only broadcast if ActionCable is available (not in evaluator subprocess)
        return unless defined?(ActionCable) && ActionCable.server

        message = {
          type: "output",
          cell_ref: @cell_ref,
          stdout: stdout.presence,
          stderr: stderr.presence,
          timestamp: Time.current.to_f
        }.compact

        ActionCable.server.broadcast("session_#{@session_token}", message)
      rescue => e
        # Log but don't fail if broadcast fails
        Rails.logger.warn("IOProxy broadcast failed: #{e.message}") if defined?(Rails)
      end

      class BufferedWriter
        def initialize(proxy, stream)
          @proxy = proxy
          @stream = stream
        end

        def write(data)
          data = data.to_s
          @proxy.write(data, stream: @stream)
          data.length
        end

        def puts(*args)
          args = [ "" ] if args.empty?
          args.each do |arg|
            write(arg.to_s)
            write("\n") unless arg.to_s.end_with?("\n")
          end
          nil
        end

        def print(*args)
          args.each { |arg| write(arg.to_s) }
          nil
        end

        def printf(format, *args)
          write(format % args)
          nil
        end

        def flush
          @proxy.flush
        end

        def tty?
          false
        end

        def isatty
          false
        end

        def sync
          true
        end

        def sync=(value)
          # Always sync
        end
      end
    end
  end
end
