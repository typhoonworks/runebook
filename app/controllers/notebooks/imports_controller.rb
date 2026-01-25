# frozen_string_literal: true

require "runebook/runemd"

module Notebooks
  class ImportsController < ApplicationController
    # POST /notebooks/imports
    # Import source content and create a new notebook
    def create
      content = params[:content].to_s.strip

      if content.blank?
        return respond_to do |format|
          format.html { redirect_to notebooks_path, alert: "Content is required" }
          format.json { render json: { ok: false, error: "Content is required" }, status: :bad_request }
        end
      end

      begin
        notebook = Notebook.create_from_content!(content)
        session = notebook.find_or_start_session

        respond_to do |format|
          format.html { redirect_to session_path(session.token) }
          format.json { render json: { ok: true, redirect_to: session_path(session.token) } }
        end
      rescue => e
        Rails.logger.error("Import failed: #{e.message}")
        respond_to do |format|
          format.html { redirect_to notebooks_path, alert: "Import failed: #{e.message}" }
          format.json { render json: { ok: false, error: "Import failed: #{e.message}" }, status: :unprocessable_entity }
        end
      end
    end
  end
end
