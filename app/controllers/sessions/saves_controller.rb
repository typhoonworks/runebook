# frozen_string_literal: true

module Sessions
  class SavesController < BaseController
    # POST /sessions/:session_id/save
    # Save the notebook to a file
    def create
      if params[:new_file_path].present?
        new_path = Pathname.new(params[:new_file_path]).expand_path

        unless workspace_browser.within_workspace?(new_path)
          return render json: { ok: false, error: "Path outside workspace" }, status: :forbidden
        end

        unless new_path.to_s.end_with?(".runemd")
          return render json: { ok: false, error: "File must have .runemd extension" }, status: :bad_request
        end

        if new_path.exist? && new_path.to_s != @notebook.file_path
          return render json: { ok: false, error: "File already exists" }, status: :conflict
        end

        old_path = @notebook.file_path
        if old_path.present? && old_path != new_path.to_s && File.exist?(old_path)
          unless @notebook.persisted_to_user_path?
            FileUtils.rm_f(old_path)
          end
        end

        @notebook.file_path = new_path.to_s
      end

      if params[:autosave_interval].present?
        @notebook.autosave_interval = params[:autosave_interval].to_i
      end

      if params[:title].present?
        @notebook.title = params[:title]
      end

      content = build_runemd_content

      dir = File.dirname(@notebook.file_path)
      FileUtils.mkdir_p(dir)

      Tempfile.create([ "save-", ".runemd" ], dir) do |tmp|
        tmp.write(content)
        tmp.flush
        FileUtils.mv(tmp.path, @notebook.file_path)
      end

      @notebook.mark_clean!
      @notebook.save!

      render json: {
        ok: true,
        saved_at: Time.current.iso8601,
        file_path: @notebook.file_path,
        autosave_interval: @notebook.effective_autosave_interval,
        persisted_to_user_path: @notebook.persisted_to_user_path?
      }
    rescue StandardError => e
      Rails.logger.error("Save failed: #{e.message}")
      render json: { ok: false, error: e.message }, status: :unprocessable_entity
    end

    private

    def workspace_browser
      @workspace_browser ||= WorkspaceBrowser.new
    end
  end
end
