# frozen_string_literal: true

require "drb/drb"
require "drb/unix"
require "timeout"
require "fileutils"
require "stringio"
require "set"

module Runebook
  class Runtime
    # Evaluates Ruby code in an isolated process with its own binding context.
    # Runs as a DRb server that can be connected to from the main Rails process.
    #
    # Key features:
    # - Isolated gem environment per session
    # - Persistent binding context across evaluations
    # - Output capture via IOProxy
    # - Execution tracing via Tracer
    class Evaluator
      attr_reader :session_token, :socket_path, :gem_home

      def initialize(session_token)
        @session_token = session_token
        @socket_path = "/tmp/runebook_eval_#{session_token}.sock"
        @gem_home = "/tmp/runebook_gems_#{session_token}"
        @mutex = Mutex.new
        @context = Context.new

        setup_gem_environment
      end

      # Start the DRb server (called in forked process)
      def start_server!
        File.delete(@socket_path) if File.exist?(@socket_path)

        DRb.start_service("drbunix:#{@socket_path}", self)

        # Signal readiness
        File.write("#{@socket_path}.ready", Process.pid)

        log "Evaluator started for session #{@session_token} (PID: #{Process.pid})"

        DRb.thread.join
      end

      # Evaluate Ruby code
      #
      # @param code [String] Ruby code to evaluate
      # @param cell_ref [String, nil] Optional cell reference for backtrace labelling
      # @param timeout [Integer] Timeout in seconds
      # @return [Hash] { ok:, result:, error:, stdout:, stderr:, tracer_info: }
      def evaluate(code, cell_ref: nil, timeout: 30)
        @mutex.synchronize do
          tracer = Tracer.new

          eval_result = { ok: false, result: nil, error: nil }
          trace_info = nil

          captured = capture_output do
            trace_info = tracer.trace do
              Timeout.timeout(timeout) do
                filename = cell_ref ? "(cell:#{cell_ref})" : "(eval)"
                result_value = @context.binding.eval(code, filename, 1)

                # Track new variables
                @context.snapshot_variables

                # Print result like IRB
                inspected = safe_inspect(result_value)
                puts "\n=> #{inspected}"

                # Return only DRb-safe primitives (use inspected string)
                eval_result = { ok: true, result: inspected, error: nil }
                nil
              end
            end
          end

          {
            ok: eval_result[:ok],
            result: eval_result[:result],
            error: eval_result[:error],
            stdout: captured[:stdout],
            stderr: captured[:stderr],
            tracer_info: sanitize_tracer_info(trace_info)
          }
        end
      rescue SyntaxError => e
        {
          ok: false,
          result: nil,
          error: Formatter.format_error(e),
          stdout: "",
          stderr: "",
          tracer_info: nil
        }
      rescue Timeout::Error
        {
          ok: false,
          result: nil,
          error: "Execution timed out after #{timeout}s",
          stdout: "",
          stderr: "",
          tracer_info: nil
        }
      rescue => e
        {
          ok: false,
          result: nil,
          error: Formatter.format_error(e),
          stdout: "",
          stderr: "",
          tracer_info: nil
        }
      end

      # Install gems into the evaluator's isolated GEM_HOME using RubyGems API
      #
      # We avoid Bundler inline here to prevent interference with the app's
      # bundle (BUNDLE_PATH/Gemfile). RubyGems installs keep things scoped to
      # @gem_home and play nicely with our isolated environment.
      #
      # @param gem_specs [Array<Hash>] Array of { name:, version: }
      # @param timeout [Integer] Timeout in seconds
      # @return [Hash] { ok:, result:, error:, stdout:, stderr: }
      def install_gems(gem_specs, timeout: 120)
        @mutex.synchronize do
          return { ok: true, result: "No gems to install", error: nil, stdout: "", stderr: "" } if gem_specs.empty?

          captured = capture_output do
            Timeout.timeout(timeout) do
              install_with_rubygems(gem_specs)
            end
          end

          {
            ok: captured[:eval_result][:ok],
            result: captured[:eval_result][:result],
            error: captured[:eval_result][:error],
            stdout: captured[:stdout],
            stderr: captured[:stderr]
          }
        end
      rescue Timeout::Error
        { ok: false, result: nil, error: "Gem installation timed out after #{timeout}s", stdout: "", stderr: "" }
      rescue => e
        {
          ok: false,
          result: nil,
          error: "Gem installation failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(15)&.join("\n")}",
          stdout: "",
          stderr: ""
        }
      end

      # Perform installation using RubyGems into @gem_home
      def install_with_rubygems(gem_specs)
        require "rubygems/dependency_installer"

        # Ensure we don't inherit the app's Bundler environment
        %w[BUNDLE_GEMFILE BUNDLE_PATH BUNDLE_WITH BUNDLE_WITHOUT].each { |k| ENV.delete(k) }

        ENV["GEM_HOME"] = @gem_home
        ENV["GEM_PATH"] = @gem_home
        Gem.clear_paths

        installer = Gem::DependencyInstaller.new(
          install_dir: @gem_home,
          document: [],
        )

        installed = []
        gem_specs.each do |spec|
          name = spec[:name]
          req = spec[:version].to_s.strip
          requirement = req.empty? ? Gem::Requirement.default : Gem::Requirement.new(req)
          installer.install(name, requirement)
          installed << "#{name} (#{req.empty? ? "latest" : req})"
        end

        Gem.clear_paths
        refresh_gem_load_paths
        { ok: true, result: "Successfully installed: #{installed.join(', ')}", error: nil }
      rescue Gem::InstallError => e
        { ok: false, result: nil, error: "Gem installation error: #{e.message}" }
      rescue => e
        { ok: false, result: nil, error: "Gem installation error: #{e.class}: #{e.message}" }
      end

      def reset_context
        @mutex.synchronize do
          @context = Context.new
          log "Context reset for session #{@session_token}"
        end
      end

      def alive?
        true
      end

      # Refresh RubyGems load paths inside the evaluator process so newly
      # installed gems (possibly installed by the main Rails process) are
      # available for `require`.
      def refresh_gems
        # Point RubyGems at our isolated path and fully reset spec cache
        ENV["GEM_HOME"] = @gem_home
        ENV["GEM_PATH"] = @gem_home
        if defined?(Bundler)
          begin
            Bundler.reset!
          rescue
            # ignore
          end
        end
        Gem.clear_paths
        begin
          Gem.use_paths(@gem_home, [ @gem_home ])
        rescue
          # ignore
        end
        begin
          Gem::Specification.reset
        rescue
          # older rubygems may not need this
        end
        refresh_gem_load_paths
        true
      end

      def shutdown
        log "Shutting down evaluator for session #{@session_token}"

        FileUtils.rm_rf(@gem_home) if @gem_home && Dir.exist?(@gem_home)
        File.delete(@socket_path) if File.exist?(@socket_path)
        File.delete("#{@socket_path}.ready") if File.exist?("#{@socket_path}.ready")

        DRb.stop_service
        exit(0)
      end

      private

      def setup_gem_environment
        FileUtils.mkdir_p(@gem_home)

        ENV["GEM_HOME"] = @gem_home
        ENV["GEM_PATH"] = @gem_home
        # Avoid inheriting the app's bundler environment
        %w[BUNDLE_GEMFILE BUNDLE_PATH BUNDLE_WITH BUNDLE_WITHOUT].each { |k| ENV.delete(k) }

        # Detach from Bundler so we can load gems outside the app Gemfile
        if defined?(Bundler)
          begin
            Bundler.reset!
          rescue
            # ignore
          end
        end

        begin
          Gem.loaded_specs.clear
        rescue
          # ignore
        end

        Gem.clear_paths
        begin
          Gem.use_paths(@gem_home, [ @gem_home ])
        rescue
          # ignore
        end
      end

      def refresh_gem_load_paths
        # Recompute $LOAD_PATH entries for all gems in @gem_home
        begin
          Gem::Specification.reset
        rescue
          # ignore
        end
        # Drop any existing load paths under this gem_home to avoid stale entries
        $LOAD_PATH.reject! { |p| p.start_with?(@gem_home) }
        Gem::Specification.each do |spec|
          spec.full_require_paths.each do |path|
            $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
          end
        end
      end

      def capture_output
        old_stdout = $stdout
        old_stderr = $stderr

        stdout_io = StringIO.new
        stderr_io = StringIO.new

        $stdout = stdout_io
        $stderr = stderr_io

        yield

        {
          stdout: stdout_io.string,
          stderr: stderr_io.string
        }
      ensure
        $stdout = old_stdout
        $stderr = old_stderr
      end

      # Convert tracer info into a DRb-safe, primitive-only hash
      def sanitize_tracer_info(info)
        return nil unless info

        modules = []
        begin
          if info.respond_to?(:modules_defined)
            modules = info.modules_defined.keys.map { |m| m.respond_to?(:name) ? m.name.to_s : m.to_s }
          end
        rescue
          modules = []
        end

        {
          execution_time_ms: (info.respond_to?(:execution_time_ms) ? info.execution_time_ms : nil),
          memory_delta: (info.respond_to?(:memory_delta) ? info.memory_delta : nil),
          modules_defined: modules
        }.compact
      end

      def safe_inspect(obj)
        obj.inspect
      rescue => e
        "#<#{obj.class}: inspect failed: #{e.message}>"
      end

      def log(message)
        File.open("/tmp/evaluator_#{@session_token}.log", "a") do |f|
          f.puts "[#{Time.now.iso8601}] #{message}"
        end
      rescue
        # Ignore logging errors
      end
    end
  end
end
