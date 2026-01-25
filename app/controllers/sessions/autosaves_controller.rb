# frozen_string_literal: true

module Sessions
  class AutosavesController < BaseController
    # POST /sessions/:session_id/autosave
    # Queue an autosave job for the notebook
    def create
      content = build_runemd_content

      AutosaveJob.perform_later(
        notebook_id: @notebook.id,
        session_token: @session.token,
        content: content
      )

      render json: { ok: true, queued: true }
    rescue StandardError => e
      Rails.logger.error("Autosave queue failed: #{e.message}")
      render json: { ok: false, error: e.message }, status: :unprocessable_entity
    end
  end
end
