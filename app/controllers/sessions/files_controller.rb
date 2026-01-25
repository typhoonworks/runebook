# frozen_string_literal: true

module Sessions
  class FilesController < ApplicationController
    before_action :set_session

    # GET /sessions/:session_id/files
    # Browse files in the workspace (session-scoped, restricted to workspace)
    def index
      result = workspace_browser.browse(params[:path])

      if result.success?
        render json: {
          ok: true,
          current_path: result.current_path,
          parent_path: result.parent_path,
          workspace_root: result.workspace_root,
          entries: result.entries.map { |e| { name: e.name, path: e.path, type: e.type } }
        }
      else
        status = case result.error
        when "Path outside workspace" then :forbidden
        when "Invalid path" then :bad_request
        when "Directory not found" then :not_found
        else :unprocessable_entity
        end

        render json: { ok: false, error: result.error }, status: status
      end
    end

    private

    def set_session
      @session = Session.find_by!(token: params[:session_id])
      @notebook = @session.notebook
    rescue ActiveRecord::RecordNotFound
      render json: { ok: false, error: "Session not found" }, status: :not_found
    end

    def workspace_browser
      @workspace_browser ||= WorkspaceBrowser.new
    end
  end
end
