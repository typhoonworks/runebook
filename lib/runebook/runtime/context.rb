# frozen_string_literal: true

module Runebook
  class Runtime
    # Manages the execution context (binding) for code evaluation.
    class Context
      attr_reader :id, :binding, :local_variables, :defined_modules

      def initialize(id: nil, parent: nil)
        @id = id || generate_id
        @parent = parent
        @binding = create_binding(parent)
        @local_variables = Set.new
        @defined_modules = Set.new
      end

      # Create a new context derived from this one
      #
      # @return [Context] New child context
      def derive
        Context.new(parent: self)
      end

      # Merge another context into this one (for branching cells)
      #
      # @param other [Context] Context to merge from
      # @return [Context] New merged context
      def merge(other)
        merged = Context.new(parent: self)

        other.local_variables.each do |var|
          begin
            value = other.binding.local_variable_get(var)
            merged.binding.local_variable_set(var, value)
            merged.local_variables << var
          rescue NameError
            # Variable no longer exists
          end
        end

        merged
      end

      # Track a newly defined local variable
      #
      # @param name [Symbol] Variable name
      def track_variable(name)
        @local_variables << name.to_sym
      end

      # Track a newly defined module/class
      #
      # @param mod [Module] Module or class that was defined
      def track_module(mod)
        @defined_modules << mod
      end

      # Get all local variables from this context and parents
      #
      # @return [Hash] { variable_name => value }
      def all_variables
        vars = {}

        # Get parent variables first
        if @parent
          vars.merge!(@parent.all_variables)
        end

        # Override with local variables
        @local_variables.each do |var|
          begin
            vars[var] = @binding.local_variable_get(var)
          rescue NameError
            # Variable no longer exists
          end
        end

        vars
      end

      # Snapshot the current local variables from the binding
      def snapshot_variables
        @binding.local_variables.each do |var|
          @local_variables << var
        end
      end

      private

      def generate_id
        SecureRandom.hex(8)
      end

      def create_binding(parent)
        if parent
          # Create a binding that inherits from parent
          # We can't truly clone a binding, so we create a fresh one
          # and copy the local variables
          fresh_binding = create_fresh_binding

          # Copy local variables from parent
          parent.local_variables.each do |var|
            begin
              value = parent.binding.local_variable_get(var)
              fresh_binding.local_variable_set(var, value)
            rescue NameError
              # Variable no longer exists in parent
            end
          end

          fresh_binding
        else
          create_fresh_binding
        end
      end

      def create_fresh_binding
        # Use the process top-level binding so that classes/modules/constants
        # defined in one cell are available to subsequent cells in this session.
        # Each session has its own evaluator process, so TOPLEVEL_BINDING remains
        # isolated per session while giving predictable Ruby semantics.
        TOPLEVEL_BINDING
      end
    end
  end
end
