# frozen_string_literal: true

class NotebooksController < ApplicationController
  protect_from_forgery with: :exception

  def index
    @notebooks = Notebook.user_persisted.order(updated_at: :desc)
  end

  def update
    @notebook = Notebook.find(params[:id])

    if notebook.update(notebook_params)
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, notice: "Title updated." }
        format.json { head :ok }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, alert: "Could not update title." }
        format.json { render json: { error: "invalid" }, status: :unprocessable_entity }
      end
    end
  end

  private

  def notebook_params
    params.require(:notebook).permit(:title)
  end
end
