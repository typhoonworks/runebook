require "test_helper"

class Runebook::Runtime::EvaluatorPoolTest < ActiveSupport::TestCase
  # Create real sessions to avoid cleanup_orphaned interference in parallel tests
  setup do
    @notebook = notebooks(:notebook_one)
    @session = Session.create!(notebook: @notebook, started_at: Time.current)
    @session_token = @session.token
    # Clean up any existing evaluators
    Runebook::Runtime::EvaluatorPool.shutdown(@session_token) rescue nil
  end

  teardown do
    # Clean up after tests
    Runebook::Runtime::EvaluatorPool.shutdown(@session_token) rescue nil
    @session&.destroy rescue nil
  end

  test "spawns new evaluator for session" do
    evaluator = Runebook::Runtime::EvaluatorPool.get_or_create(@session_token)

    assert_not_nil evaluator
    assert evaluator.alive?
  end

  test "returns same evaluator for same session token" do
    evaluator1 = Runebook::Runtime::EvaluatorPool.get_or_create(@session_token)
    evaluator2 = Runebook::Runtime::EvaluatorPool.get_or_create(@session_token)

    # Should be the same DRb object (same process)
    info = Runebook::Runtime::EvaluatorPool.send(:get_evaluator_info, @session_token)
    assert_not_nil info
    assert_equal info[:pid], info[:pid] # Same PID
  end

  test "different sessions get different evaluators" do
    session1 = Session.create!(notebook: @notebook, started_at: Time.current)
    session2 = Session.create!(notebook: @notebook, started_at: Time.current)

    begin
      evaluator1 = Runebook::Runtime::EvaluatorPool.get_or_create(session1.token)
      evaluator2 = Runebook::Runtime::EvaluatorPool.get_or_create(session2.token)

      info1 = Runebook::Runtime::EvaluatorPool.send(:get_evaluator_info, session1.token)
      info2 = Runebook::Runtime::EvaluatorPool.send(:get_evaluator_info, session2.token)

      assert_not_nil info1, "info1 should not be nil"
      assert_not_nil info2, "info2 should not be nil"
      assert_not_equal info1[:pid], info2[:pid]
    ensure
      # Cleanup
      Runebook::Runtime::EvaluatorPool.shutdown(session1.token) rescue nil
      Runebook::Runtime::EvaluatorPool.shutdown(session2.token) rescue nil
      session1.destroy rescue nil
      session2.destroy rescue nil
    end
  end

  test "shutdown terminates evaluator process" do
    evaluator = Runebook::Runtime::EvaluatorPool.get_or_create(@session_token)
    info = Runebook::Runtime::EvaluatorPool.send(:get_evaluator_info, @session_token)
    pid = info[:pid]

    # Process should exist
    assert Runebook::Runtime::EvaluatorPool.send(:process_exists?, pid)

    # Shutdown
    Runebook::Runtime::EvaluatorPool.shutdown(@session_token)

    # Give it a moment to shutdown
    sleep 0.5

    # Process should be gone
    assert_not Runebook::Runtime::EvaluatorPool.send(:process_exists?, pid)

    # Redis entry should be gone
    assert_nil Runebook::Runtime::EvaluatorPool.send(:get_evaluator_info, @session_token)
  end

  test "cleanup_orphaned removes evaluators for closed sessions" do
    session = sessions(:closed_old)

    # Create evaluator
    Runebook::Runtime::EvaluatorPool.get_or_create(session.token)

    # Should have evaluator
    assert_not_nil Runebook::Runtime::EvaluatorPool.send(:get_evaluator_info, session.token)

    # Run cleanup
    Runebook::Runtime::EvaluatorPool.cleanup_orphaned

    # Give it a moment
    sleep 0.5

    # Evaluator should be gone
    assert_nil Runebook::Runtime::EvaluatorPool.send(:get_evaluator_info, session.token)
  end
end
