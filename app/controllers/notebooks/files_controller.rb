# frozen_string_literal: true

module Notebooks
  class FilesController < ApplicationController
    # GET /notebooks/files
    # Browse files in the workspace
    def index
      result = workspace_browser.browse(params[:path])

      if result.success?
        render json: {
          ok: true,
          current_path: result.current_path,
          parent_path: result.parent_path,
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

    # POST /notebooks/files
    # Create a new notebook file with a Notebook record
    def create
      notebook = Notebook.create_at_path!(
        directory: params[:path].presence || Notebook.workspace_dir.to_s,
        filename: params[:name]
      )

      render json: {
        ok: true,
        path: notebook.file_path,
        name: File.basename(notebook.file_path)
      }
    rescue ArgumentError => e
      status = case e.message
      when "Filename is required", "Invalid filename" then :bad_request
      else :unprocessable_entity
      end
      render json: { ok: false, error: e.message }, status: status
    rescue RuntimeError => e
      status = case e.message
      when "File already exists" then :conflict
      when /Path outside workspace/ then :forbidden
      else :unprocessable_entity
      end
      render json: { ok: false, error: e.message }, status: status
    end

    private

    def workspace_browser
      @workspace_browser ||= WorkspaceBrowser.new(restrict_to_workspace: false)
    end
  end
end
