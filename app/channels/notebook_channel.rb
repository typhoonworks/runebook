# frozen_string_literal: true

# ActionCable channel for notebook dirty state and save notifications.
# Each notebook has its own channel identified by notebook_id.
#
# Clients subscribe with:
#   consumer.subscriptions.create({ channel: "NotebookChannel", notebook_id: "..." })
#
# Server broadcasts via:
#   ActionCable.server.broadcast("notebook_#{id}", { type: "dirty_state", dirty: true })
#
# Client can send:
#   subscription.perform("cell_changed") - notify backend a cell was modified
class NotebookChannel < ApplicationCable::Channel
  def subscribed
    notebook_id = params[:notebook_id]

    @notebook = Notebook.find_by(id: notebook_id)
    if @notebook.nil?
      reject
      return
    end

    stream_from "notebook_#{notebook_id}"

    # Send initial dirty state on connection
    transmit(type: "dirty_state", dirty: @notebook.dirty?)
  end

  def unsubscribed
    # Cleanup when client disconnects (if needed)
  end

  # Called when frontend notifies that a cell has been changed
  def cell_changed(_data = {})
    return unless @notebook

    @notebook.mark_dirty!
  end
end
