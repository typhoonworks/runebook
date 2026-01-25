# frozen_string_literal: true

require "set"

module Runebook
  class Runtime
    # Tracks execution metadata during code evaluation using Ruby's TracePoint.
    class Tracer
      TracerInfo = Data.define(
        :modules_defined,   # { Module => { line:, file:, methods: [] } }
        :methods_defined,   # Set of { module:, method:, line:, file: }
        :methods_called,    # Set of { receiver:, method: } (limited)
        :constants_defined, # Set of constant names
        :requires,          # Set of required file paths
        :execution_time_ms, # Integer
        :memory_delta       # { before:, after:, delta: }
      )

      attr_reader :modules_defined, :methods_defined, :methods_called,
                  :constants_defined, :requires

      def initialize
        @modules_defined = {}
        @methods_defined = Set.new
        @methods_called = Set.new
        @constants_defined = Set.new
        @requires = Set.new
        @call_count = 0
        @max_calls_tracked = 100 # Limit to prevent memory bloat
      end

      # Execute a block with tracing enabled
      #
      # @yield The code to trace
      # @return [TracerInfo] Collected metadata
      def trace(&block)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
        memory_before = current_memory_usage

        # Enable trace points
        traces = setup_traces
        traces.each(&:enable)

        begin
          yield
        ensure
          traces.each(&:disable)
        end

        end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
        memory_after = current_memory_usage

        build_tracer_info(
          execution_time_ms: end_time - start_time,
          memory_before: memory_before,
          memory_after: memory_after
        )
      end

      private

      def setup_traces
        traces = []

        # Track class/module definitions
        traces << TracePoint.new(:class) do |tp|
          next if internal_path?(tp.path)

          @modules_defined[tp.self] = {
            line: tp.lineno,
            file: tp.path,
            methods: []
          }
        end

        # Track method definitions
        traces << TracePoint.new(:c_call, :call) do |tp|
          next if internal_path?(tp.path)
          next if @call_count >= @max_calls_tracked

          if tp.method_id == :method_added || tp.method_id == :singleton_method_added
            # Method was defined
            @methods_defined << {
              module: tp.defined_class,
              method: tp.method_id,
              line: tp.lineno,
              file: tp.path
            }
          end

          # Track method calls (limited)
          @methods_called << {
            receiver: tp.defined_class&.name || tp.defined_class.to_s,
            method: tp.method_id
          }
          @call_count += 1
        end

        # Track requires
        traces << TracePoint.new(:c_call) do |tp|
          if tp.method_id == :require || tp.method_id == :require_relative
            # We can't easily get the argument, but we can track that require was called
            @requires << tp.path
          end
        end

        traces
      end

      def internal_path?(path)
        return true if path.nil?

        path.include?("/lib/runebook/") ||
          path.include?("/drb/") ||
          path.include?("/timeout") ||
          path.include?("/bundler/") ||
          path.include?("/rubygems/") ||
          path.start_with?("<internal:")
      end

      def current_memory_usage
        gc_stat = GC.stat
        {
          heap_live_slots: gc_stat[:heap_live_slots],
          total_allocated_objects: gc_stat[:total_allocated_objects],
          total_freed_objects: gc_stat[:total_freed_objects]
        }
      end

      def build_tracer_info(execution_time_ms:, memory_before:, memory_after:)
        TracerInfo.new(
          modules_defined: @modules_defined.dup,
          methods_defined: @methods_defined.dup,
          methods_called: @methods_called.dup,
          constants_defined: @constants_defined.dup,
          requires: @requires.dup,
          execution_time_ms: execution_time_ms,
          memory_delta: {
            before: memory_before,
            after: memory_after,
            delta: {
              heap_live_slots: memory_after[:heap_live_slots] - memory_before[:heap_live_slots],
              total_allocated: memory_after[:total_allocated_objects] - memory_before[:total_allocated_objects]
            }
          }
        )
      end
    end
  end
end
