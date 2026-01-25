require "test_helper"

class EvaluatorCleanupJobTest < ActiveJob::TestCase
  test "invokes EvaluatorPool.cleanup_orphaned" do
    called = false
    pool = Runebook::Runtime::EvaluatorPool
    orig = pool.method(:cleanup_orphaned)
    pool.define_singleton_method(:cleanup_orphaned) { called = true }
    begin
      EvaluatorCleanupJob.perform_now
    ensure
      pool.define_singleton_method(:cleanup_orphaned, orig)
    end
    assert called, "Expected cleanup_orphaned to be called"
  end
end
