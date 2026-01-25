class HomeController < ApplicationController
  def index
    @starred = []
    @notebooks = Notebook.user_persisted.order(updated_at: :desc).limit(3)
    @sessions = Session.running
  end
end
