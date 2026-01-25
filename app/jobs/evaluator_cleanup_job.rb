class EvaluatorCleanupJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Running evaluator cleanup job"
    Runebook::Runtime::EvaluatorPool.cleanup_orphaned
  rescue => e
    Rails.logger.error "Evaluator cleanup job failed: #{e.message}\n#{e.backtrace.join("\n")}"
    raise
  end
end
