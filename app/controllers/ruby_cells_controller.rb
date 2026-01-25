# frozen_string_literal: true

class RubyCellsController < ApplicationController
  protect_from_forgery with: :null_session
  skip_before_action :verify_authenticity_token

  def evaluate
    code = params[:code].to_s
    session_token = params[:session_token].to_s
    cell_type = params[:cell_type].to_s.presence || "code"
    cell_ref = params[:cell_ref].to_s.presence || SecureRandom.hex(8)

    session = Session.find_by(token: session_token)
    unless session
      return render json: {
        html: render_error("Invalid session"),
        ok: false
      }
    end

    begin
      runtime = session.runtime

      if cell_type == "setup"
        gem_specs = parse_gem_specifications(code)
        result = runtime.install_gems(gem_specs, cell_ref: cell_ref)

        session.update!(setup_cell_evaluated: true) if result.success?
      else
        result = runtime.evaluate(code, cell_ref: cell_ref)
      end

      session.update!(
        last_evaluation_at: Time.current,
        evaluation_count: session.evaluation_count + 1
      )

      html = render_to_string(
        partial: "sessions/ruby_cell_output",
        locals: { result: result_to_hash(result) },
        formats: [ :html ]
      )

      render json: {
        html: html,
        ok: result.success?,
        metadata: result.to_h[:metadata]
      }

    rescue => e
      html = render_error("Runtime error: #{e.class}: #{e.message}")
      render json: { html: html, ok: false }
    end
  rescue => e
    render json: {
      html: "<div class='text-error'>Fatal error: #{e.class}: #{e.message}</div>",
      ok: false
    }, status: 500
  end

  private

  def parse_gem_specifications(code)
    gems = []

    code.scan(/gem\s+['"]([^'"]+)['"]\s*(?:,\s*['"]([^'"]+)['"])?/) do |name, version|
      gems << { name: name, version: version }
    end

    gems
  end

  def result_to_hash(result)
    {
      ok: result.success?,
      stdout: result.stdout,
      stderr: result.error || result.stderr,
      result: result.value
    }
  end

  def render_error(message)
    render_to_string(
      partial: "sessions/ruby_cell_output",
      locals: {
        result: {
          ok: false,
          stdout: "",
          stderr: message,
          result: nil
        }
      },
      formats: [ :html ]
    )
  end
end
