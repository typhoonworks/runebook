# frozen_string_literal: true

module Notebooks
  class DirectoriesController < ApplicationController
    # POST /notebooks/directories
    # Create a new directory in the workspace
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
        new_dir = parent_dir.join(dir_name)

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
  end
end
