# frozen_string_literal: true

module Runebook
  class Runtime
    # Formats errors and results for display.
    module Formatter
      begin
        require "did_you_mean"
      rescue LoadError
        # Optional
      end
      class << self
        # Format an exception for display
        #
        # @param exception [Exception] The exception to format
        # @return [String] Formatted error message with optional stacktrace
        def format_error(exception)
          case exception
          when SyntaxError
            format_syntax_error(exception)
          when NameError, NoMethodError
            format_with_trace(exception)
          when LoadError
            format_with_trace(exception)
          when Timeout::Error
            format_timeout_error(exception)
          else
            format_with_trace(exception)
          end
        end

        # Format a result value for display
        #
        # @param value [Object] The value to format
        # @return [String] Formatted result
        def format_result(value)
          "=> #{safe_inspect(value)}"
        end

        # Create an Output object from an exception
        #
        # @param exception [Exception] The exception to convert
        # @return [Output] Structured error output
        def error_output(exception)
          Output.error(
            format_error(exception),
            backtrace: cleaned_backtrace(exception),
            context: error_context(exception)
          )
        end

        private

        def format_syntax_error(exception)
          "error: #{clean_error_message(exception)}"
        end

        def format_timeout_error(exception)
          "error: Execution timed out"
        end

        def format_with_trace(exception)
          lines = []
          lines << "error: #{clean_error_message(exception)} (#{exception.class})"

          suggestions = suggestions_for(exception)
          if suggestions.any?
            lines << "Did you mean:"
            suggestions.first(5).each do |s|
              lines << "  * #{s}"
            end
          end

          trace = cleaned_backtrace(exception)
          unless trace.empty?
            trace.each_with_index do |line, i|
              prefix = i == trace.length - 1 ? "\u2514\u2500" : "\u251C\u2500"
              simplified = simplify_trace_line(line)
              lines << "#{prefix} #{simplified}"
            end
          end

          lines.join("\n")
        end

        def clean_error_message(exception)
          message = exception.message.to_s

          # Remove "for #<ClassName:0x...>"
          message = message.gsub(/\s+for #<[^>]+>/, "")

          # Remove Ruby receiver suffix like "for main:Object"
          message = message.gsub(/\s+for\s+[^:]+:[^\s]+/, "")

          # Truncate very long messages
          message.length > 500 ? "#{message[0..500]}..." : message
        end

        # Filter stacktrace to show only user-relevant frames
        def cleaned_backtrace(exception)
          trace = exception.backtrace || []

          user_trace = trace.select do |line|
            # Keep lines from (eval) or (cell:xxx)
            line.match?(/\(eval\)|\(cell:/) ||
              # Keep lines from user gems (not system/evaluator gems)
              (line.include?("/gems/") && !internal_gem?(line))
          end

          user_trace.first(5)
        end

        # Check if a gem is internal/system gem
        def internal_gem?(line)
          line.include?("timeout.rb") ||
            line.include?("drb/") ||
            line.include?("concurrent-ruby") ||
            line.include?("mutex_m") ||
            line.include?("bundler")
        end

        # Simplify a stacktrace line to show just file:line
        def simplify_trace_line(line)
          if line =~ /(.+):(\d+)(?::in `.+')?$/
            file = ::Regexp.last_match(1)
            line_num = ::Regexp.last_match(2)

            if file.include?("(eval)") || file.include?("(cell:")
              "#{file}:#{line_num}"
            elsif file.include?("/gems/")
              gem_name = file[%r{/gems/([^/]+)}, 1]
              "#{gem_name}:#{line_num}"
            else
              "#{File.basename(file)}:#{line_num}"
            end
          else
            line
          end
        end

        def error_context(exception)
          case exception
          when SyntaxError
            :syntax
          when NameError, NoMethodError
            :name
          when LoadError
            :load
          when Timeout::Error
            :timeout
          else
            :runtime
          end
        end

        def suggestions_for(exception)
          if exception.respond_to?(:corrections)
            Array(exception.corrections).compact.reject(&:empty?)
          else
            []
          end
        rescue
          []
        end

        def safe_inspect(obj)
          obj.inspect
        rescue => e
          "#<#{obj.class}: inspect failed: #{e.message}>"
        end
      end
    end
  end
end
