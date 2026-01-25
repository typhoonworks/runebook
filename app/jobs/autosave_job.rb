# frozen_string_literal: true

# Background job for autosaving notebook content.
# Writes to storage/autosave/YYYY_MM_DD/session_token/notebook.runemd
# Uses atomic writes (temp file + move) to prevent corruption.
class AutosaveJob < ApplicationJob
  queue_as :default

  # @param notebook_id [Integer] the notebook ID
  # @param session_token [String] the session token
  # @param content [String] the .runemd formatted content to save
  def perform(notebook_id:, session_token:, content:)
    notebook = Notebook.find_by(id: notebook_id)
    return unless notebook

    autosave_path = notebook.autosave_path(session_token)
    dir = autosave_path.dirname

    # Ensure directory exists
    FileUtils.mkdir_p(dir)

    # Atomic write using temp file + move
    Tempfile.create([ "autosave-", ".runemd" ], dir.to_s) do |tmp|
      tmp.write(content)
      tmp.flush
      FileUtils.mv(tmp.path, autosave_path)
    end

    Rails.logger.info("[AutosaveJob] Saved to #{autosave_path}")
  rescue StandardError => e
    Rails.logger.error("[AutosaveJob] Failed: #{e.message}")
    raise # Re-raise to trigger job retry
  end
end
