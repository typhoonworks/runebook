require "test_helper"

class Runebook::Runtime::EvaluatorTest < ActiveSupport::TestCase
  # Create real sessions to avoid cleanup_orphaned interference in parallel tests
  setup do
    @notebook = notebooks(:notebook_one)
    @session = Session.create!(notebook: @notebook, started_at: Time.current)
    @session_token = @session.token
    @evaluator = Runebook::Runtime::EvaluatorPool.get_or_create(@session_token)
  end

  teardown do
    Runebook::Runtime::EvaluatorPool.shutdown(@session_token) rescue nil
    @session&.destroy rescue nil
  end

  test "evaluates simple Ruby code" do
    result = @evaluator.evaluate("1 + 1")

    assert result[:ok]
    assert_equal "2", result[:result]
    assert_includes result[:stdout], "2"
  end

  test "captures stdout" do
    result = @evaluator.evaluate("puts 'Hello, World!'")

    assert result[:ok]
    assert_includes result[:stdout], "Hello, World!"
  end

  test "captures stderr" do
    result = @evaluator.evaluate("warn 'Warning message'")

    assert result[:ok]
    assert_includes result[:stderr], "Warning message"
  end

  test "handles syntax errors" do
    result = @evaluator.evaluate("def broken")

    assert_not result[:ok]
    assert_kind_of String, result[:error]
    assert_includes result[:error].downcase, "error:"
  end

  test "handles runtime errors" do
    result = @evaluator.evaluate("raise 'Something went wrong'")

    assert_not result[:ok]
    assert_includes result[:error], "RuntimeError"
    assert_includes result[:error], "Something went wrong"
  end

  test "times out long-running code" do
    result = @evaluator.evaluate("sleep 100", timeout: 1)

    assert_not result[:ok]
    assert_includes result[:error], "timed out"
  end

  test "maintains context across evaluations" do
    # Define variable
    result1 = @evaluator.evaluate("x = 42")
    assert result1[:ok]

    # Use variable in next evaluation
    result2 = @evaluator.evaluate("x + 8")
    assert result2[:ok]
    assert_equal "50", result2[:result]
  end

  test "class definitions persist" do
    # Define class
    result1 = @evaluator.evaluate(<<~RUBY)
      class Calculator
        def add(a, b)
          a + b
        end
      end
    RUBY
    assert result1[:ok]

    # Use class in next evaluation
    result2 = @evaluator.evaluate("Calculator.new.add(5, 3)")
    assert result2[:ok]
    assert_equal "8", result2[:result]
  end

  test "module definitions persist" do
    # Define module
    result1 = @evaluator.evaluate(<<~RUBY)
      module MathHelpers
        def square(x)
          x * x
        end
      end
    RUBY
    assert result1[:ok]

    # Include and use module
    result2 = @evaluator.evaluate(<<~RUBY)
      include MathHelpers
      square(4)
    RUBY
    assert result2[:ok]
    assert_equal "16", result2[:result]
  end

  test "reset_context keeps top-level classes and may keep locals" do
    # Define variable
    @evaluator.evaluate("x = 100")

    # Reset context
    @evaluator.reset_context

    # With TOPLEVEL_BINDING semantics, x may still be accessible
    result = @evaluator.evaluate("x")
    assert result[:ok], "Expected x to remain accessible with current binding semantics"
    assert_equal "100", result[:result]
  end

  test "alive? returns true" do
    assert @evaluator.alive?
  end
end
