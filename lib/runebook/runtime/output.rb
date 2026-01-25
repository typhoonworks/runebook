# frozen_string_literal: true

module Runebook
  class Runtime
    # Represents a structured output from code evaluation.
    class Output
      TYPES = %i[text error terminal markdown html table image frame].freeze

      attr_reader :type, :content, :metadata

      def initialize(type:, content:, metadata: {})
        raise ArgumentError, "Unknown output type: #{type}" unless TYPES.include?(type)

        @type = type
        @content = content
        @metadata = metadata
        freeze
      end

      def self.text(content)
        new(type: :text, content: content.to_s)
      end

      def self.terminal(content, chunk: false)
        new(type: :terminal, content: content.to_s, metadata: { chunk: chunk })
      end

      def self.error(message, backtrace: nil, context: nil)
        new(
          type: :error,
          content: message.to_s,
          metadata: { backtrace: backtrace, context: context }.compact
        )
      end

      def self.markdown(content, chunk: false)
        new(type: :markdown, content: content.to_s, metadata: { chunk: chunk })
      end

      def self.html(content)
        new(type: :html, content: content.to_s)
      end

      def self.table(data, headers: nil)
        new(type: :table, content: data, metadata: { headers: headers })
      end

      def self.image(content, mime_type:)
        new(type: :image, content: content, metadata: { mime_type: mime_type })
      end

      def self.frame(ref:, outputs: [], placeholder: false)
        new(type: :frame, content: outputs, metadata: { ref: ref, placeholder: placeholder })
      end

      def text?
        type == :text
      end

      def error?
        type == :error
      end

      def terminal?
        type == :terminal
      end

      def empty?
        content.nil? || content.empty?
      end

      def to_h
        {
          type: type,
          content: content,
          metadata: metadata
        }
      end

      def to_json(*args)
        to_h.to_json(*args)
      end
    end
  end
end
