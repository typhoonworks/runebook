# frozen_string_literal: true

# ActionCable channel for streaming evaluation outputs to connected clients.
# Each session has its own channel identified by session_token.
#
# Clients subscribe with:
#   consumer.subscriptions.create({ channel: "SessionChannel", session_token: "..." })
#
# Server broadcasts via:
#   ActionCable.server.broadcast("session_#{token}", { type: "output", ... })
class SessionChannel < ApplicationCable::Channel
  def subscribed
    session_token = params[:session_token]

    session = Session.find_by(token: session_token)
    if session.nil?
      reject
      return
    end

    stream_from "session_#{session_token}"
  end

  def unsubscribed
    # Cleanup when client disconnects (if needed)
  end
end
