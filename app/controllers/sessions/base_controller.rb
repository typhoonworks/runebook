# frozen_string_literal: true

require "runebook/runemd"

module Sessions
  class BaseController < ApplicationController
    before_action :set_session

    private

    def set_session
      @session = Session.find_by!(token: params[:session_id])
      @notebook = @session.notebook
    rescue ActiveRecord::RecordNotFound
      render json: { ok: false, error: "Session not found" }, status: :not_found
    end

    def build_runemd_content
      data = {
        version: @notebook.version || 1,
        autosave_interval: @notebook.effective_autosave_interval,
        title: params[:title] || @notebook.title,
        setup_cell: build_setup_cell,
        sections: build_sections
      }

      Runebook::Runemd.export(data)
    end

    def build_setup_cell
      content = params.dig(:setup_cell, :content).to_s
      { type: :setup, content: content }
    end

    def build_sections
      sections = params[:sections] || []

      sections.map do |section|
        {
          title: section[:title] || "Section",
          cells: (section[:cells] || []).map do |cell|
            {
              type: cell[:type]&.to_sym || :ruby,
              content: cell[:content] || ""
            }
          end
        }
      end
    end
  end
end
