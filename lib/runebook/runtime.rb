# frozen_string_literal: true

module Runebook
  # Runtime provides the main interface for code evaluation in Runebook.
  # It manages evaluator processes, handles output streaming via ActionCable,
  # and tracks execution metadata via tracing.
  class Runtime
    attr_reader :session_token

    def initialize(session_token)
      @session_token = session_token
    end

    # Evaluate Ruby code in the runtime context
    #
    # @param code [String] Ruby code to evaluate
    # @param cell_ref [String] Unique reference for the cell being evaluated
    # @param parent_refs [Array<String>] References to parent cells for context
    # @return [Runtime::EvaluationResult] Structured result with outputs and metadata
    def evaluate(code, cell_ref:, parent_refs: [])
      evaluator = EvaluatorPool.get_or_create(@session_token)

      # Keep DRb calls simple (no callbacks). Pass cell_ref so evaluator can
      # label backtraces as (cell:<ref>) for errors.
      result = evaluator.evaluate(code, cell_ref: cell_ref, timeout: 30)

      EvaluationResult.new(
        success: result[:ok],
        value: result[:result],
        stdout: result[:stdout],
        stderr: result[:stderr],
        error: result[:error],
        tracer_info: result[:tracer_info]
      )
    end

    # Install/cleanup gems for this session (used by setup cell) with live streaming.
    #
    # Runs in the main Rails process so we can stream progress via ActionCable
    # using IOProxy. Installs into the session's isolated GEM_HOME so the
    # evaluator process can use the gems.
    #
    # @param gem_specs [Array<Hash>] Array of { name:, version: }
    # @param cell_ref [String] Cell reference for streaming output
    def install_gems(gem_specs, cell_ref: nil)
      gem_home = "/tmp/runebook_gems_#{@session_token}"

      proxy = IOProxy.new(session_token: @session_token, cell_ref: cell_ref || "setup")
      captured = nil
      begin
        captured = proxy.capture do
          reconcile_gems_with_rubygems(gem_specs, gem_home)
        end
      rescue => e
        return EvaluationResult.new(success: false, value: nil, stdout: captured&.dig(:stdout) || "", stderr: "#{e.class}: #{e.message}")
      end

      # Ask evaluator (if running) to refresh its gem paths
      begin
        evaluator = EvaluatorPool.get_or_create(@session_token)
        evaluator.refresh_gems
        # Reset the binding context so code doesn't depend on previously loaded libs
        evaluator.reset_context
      rescue
        # ignore if evaluator not up yet; next eval will set paths during init
      end

      EvaluationResult.new(
        success: true,
        value: "Installed #{gem_specs.map { |s| s[:name] }.join(', ')}",
        stdout: captured[:stdout],
        stderr: captured[:stderr],
        error: nil
      )
    end

    private

    def reconcile_gems_with_rubygems(gem_specs, gem_home)
      require "json"
      require "rubygems/dependency_installer"
      require "rubygems/uninstaller"

      desired = Array(gem_specs).map { |s| { name: s[:name].to_s, version: s[:version].to_s } }

      # Ensure we don't inherit the app's Bundler environment
      %w[BUNDLE_GEMFILE BUNDLE_PATH BUNDLE_WITH BUNDLE_WITHOUT].each { |k| ENV.delete(k) }

      FileUtils.mkdir_p(gem_home)
      ENV["GEM_HOME"] = gem_home
      ENV["GEM_PATH"] = gem_home
      Gem.clear_paths

      # Acquire a coarse lock so concurrent setup edits don't fight
      lock_path = File.join(gem_home, ".setup_lock")
      FileUtils.mkdir_p(gem_home)
      File.open(lock_path, "w") do |lock|
        lock.flock(File::LOCK_EX)

      # Verbose RubyGems UI prints fetch/install/uninstall progress to stdout
      begin
        require "rubygems/user_interaction"
        Gem::DefaultUserInteraction.ui = Gem::StreamUI.new($stdout, $stderr, true, true)
      rescue
        # best effort
      end

      puts "Resolving and installing gems into #{gem_home}..."

      # Current installed names in this gem_home
      installed_specs = Gem::Specification.to_a
      installed_names = installed_specs.map(&:name).uniq
      desired_names = desired.map { |s| s[:name] }.uniq

      # Uninstall gems that were removed from setup
      stale = installed_names - desired_names
      unless stale.empty?
        puts "Removing gems: #{stale.join(', ')}"
        stale.each do |name|
          begin
            Gem::Uninstaller.new(name, install_dir: gem_home, all: true, executables: true, ignore: true).uninstall
            puts "Uninstalled #{name}"
          rescue => e
            puts "WARN: Failed to uninstall #{name}: #{e.class}: #{e.message}"
          end
        end
      end

      # Install missing or non-satisfying versions
      installer = Gem::DependencyInstaller.new(install_dir: gem_home, document: [])
      desired.each do |spec|
        name = spec[:name]
        req_str = spec[:version].to_s.strip
        requirement = req_str.empty? ? Gem::Requirement.default : Gem::Requirement.new(req_str)

        candidates = Gem::Specification.find_all_by_name(name)
        if candidates.none? { |gs| requirement.satisfied_by?(Gem::Version.new(gs.version)) }
          puts "Installing #{name} #{req_str unless req_str.empty?}..."
          installer.install(name, requirement)
          puts "Installed #{name}"
        else
          puts "Using #{name} (already installed)"
        end
      end

      # Persist desired state for debugging/reloads
      File.write(File.join(gem_home, "setup_gems.json"), JSON.pretty_generate(desired))

      Gem.clear_paths
      ensure
        lock.flock(File::LOCK_UN)
      end
    end

    def reset_context
      evaluator = EvaluatorPool.get_or_create(@session_token)
      evaluator.reset_context
    end

    def disconnect
      EvaluatorPool.shutdown(@session_token)
    end

    def connected?
      EvaluatorPool.alive?(@session_token)
    end
  end
end

require_relative "runtime/output"
require_relative "runtime/evaluation_result"
require_relative "runtime/formatter"
require_relative "runtime/tracer"
require_relative "runtime/io_proxy"
require_relative "runtime/context"
require_relative "runtime/evaluator"
require_relative "runtime/evaluator_pool"
