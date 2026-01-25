# frozen_string_literal: true

module Runebook
  class Runtime
    # Represents the result of a code evaluation.
    # Combines the evaluation value, captured output, errors, and tracing metadata.
    class EvaluationResult
      attr_reader :value, :stdout, :stderr, :error, :tracer_info

      def initialize(success:, value: nil, stdout: "", stderr: "", error: nil, tracer_info: nil)
        @success = success
        @value = value
        @stdout = stdout || ""
        @stderr = stderr || ""
        @error = error
        @tracer_info = tracer_info
        freeze
      end

      def success?
        @success
      end

      def failed?
        !@success
      end

      alias ok? success?

      def has_output?
        stdout.present? || stderr.present?
      end

      def has_error?
        error.present?
      end

      def execution_time_ms
        if tracer_info.respond_to?(:[])
          tracer_info[:execution_time_ms]
        else
          tracer_info&.execution_time_ms
        end
      end

      def memory_delta
        if tracer_info.respond_to?(:[])
          tracer_info[:memory_delta]
        else
          tracer_info&.memory_delta
        end
      end

      def modules_defined
        if tracer_info.respond_to?(:modules_defined)
          tracer_info.modules_defined || {}
        elsif tracer_info.respond_to?(:[])
          # Expect an array of module names; convert to hash-like structure
          names = Array(tracer_info[:modules_defined])
          names.each_with_object({}) { |n, h| h[n.to_s] = {} }
        else
          {}
        end
      end

      def to_h
        {
          success: success?,
          value: safe_inspect(value),
          stdout: stdout,
          stderr: stderr,
          error: error,
          metadata: {
            execution_time_ms: execution_time_ms,
            memory_delta: memory_delta,
            modules_defined: modules_defined.keys.map(&:to_s)
          }.compact
        }
      end

      def to_json(*args)
        to_h.to_json(*args)
      end

      private

      def safe_inspect(obj)
        obj.inspect
      rescue => e
        "#<#{obj.class}: inspect failed: #{e.message}>"
      end
    end
  end
end
