require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "token is generated and status defaults to open" do
    s = Session.create!(notebook: notebooks(:notebook_one))

    assert s.persisted?
    assert s.token.present?, "token should be auto-generated"
    assert_equal "open", s.status
  end

  test "evaluation tracking fields have sensible defaults" do
    s = Session.create!(notebook: notebooks(:notebook_one))

    assert_equal 0, s.evaluation_count
    assert_nil s.last_evaluation_at
    assert_equal false, s.setup_cell_evaluated
  end

  test "runtime memoizes and returns a Runebook::Runtime" do
    s = Session.create!(notebook: notebooks(:notebook_one))

    r1 = s.runtime
    r2 = s.runtime

    assert_instance_of Runebook::Runtime, r1
    assert_same r1, r2, "runtime should be memoized per session instance"
  end

  test "disconnect_runtime! shuts down evaluator and clears memoized instance" do
    s = Session.create!(notebook: notebooks(:notebook_one))

    # Seed a memoized runtime instance
    fake_runtime = Object.new
    s.instance_variable_set(:@runtime, fake_runtime)

    called_with = nil
    pool = Runebook::Runtime::EvaluatorPool
    orig = pool.method(:shutdown)
    pool.define_singleton_method(:shutdown) { |tok| called_with = tok }
    begin
      s.disconnect_runtime!
    ensure
      pool.define_singleton_method(:shutdown, orig)
    end

    assert_equal s.token, called_with
    assert_nil s.instance_variable_get(:@runtime)
  end

  test "closing a session triggers runtime cleanup" do
    s = Session.create!(notebook: notebooks(:notebook_one))
    s.instance_variable_set(:@runtime, Object.new)

    called = false
    pool = Runebook::Runtime::EvaluatorPool
    orig = pool.method(:shutdown)
    pool.define_singleton_method(:shutdown) { |_tok| called = true }
    begin
      s.update!(status: :closed)
    ensure
      pool.define_singleton_method(:shutdown, orig)
    end

    assert s.closed?
    assert called, "EvaluatorPool.shutdown should be called when closing"
    assert_nil s.instance_variable_get(:@runtime)
  end
end
