# frozen_string_literal: true

module Sessions
  class DirectoriesController < ApplicationController
    before_action :set_session

    # POST /sessions/:session_id/directories
    # Create a new directory in the workspace (session-scoped, restricted to workspace)
    def create
      parent = params[:path].presence || Notebook.workspace_dir.to_s
      dir_name = params[:name].to_s.strip

      if dir_name.blank?
        return render json: { ok: false, error: "Directory name is required" }, status: :bad_request
      end

      unless dir_name.match?(/\A[\w\-. ]+\z/)
        return render json: { ok: false, error: "Invalid directory name" }, status: :bad_request
      end

      begin
        parent_dir = Pathname.new(parent).expand_path

        unless workspace_browser.within_workspace?(parent_dir)
          return render json: { ok: false, error: "Path outside workspace" }, status: :forbidden
        end

        new_dir = parent_dir.join(dir_name)

        unless workspace_browser.within_workspace?(new_dir)
          return render json: { ok: false, error: "Path outside workspace" }, status: :forbidden
        end

        if new_dir.exist?
          return render json: { ok: false, error: "Directory already exists" }, status: :conflict
        end

        FileUtils.mkdir_p(new_dir)

        render json: {
          ok: true,
          path: new_dir.to_s,
          name: dir_name
        }
      rescue ArgumentError, Errno::ENOENT, Errno::EACCES => e
        render json: { ok: false, error: "Failed to create directory: #{e.message}" }, status: :unprocessable_entity
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
