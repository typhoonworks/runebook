// NotebookChannel subscription for dirty state tracking and save notifications
// Subscribes to notebook-specific channel for collaborative dirty state

import consumer from "./consumer";
import type { Subscription } from "@rails/actioncable";

export interface NotebookDirtyMessage {
  type: "dirty_state";
  dirty: boolean;
}

export interface NotebookChannelCallbacks {
  onDirtyState?: (dirty: boolean) => void;
  onConnected?: () => void;
  onDisconnected?: () => void;
}

const subscriptions = new Map<number, Subscription>();
const callbacks = new Map<number, Set<NotebookChannelCallbacks>>();

/**
 * Subscribe to notebook channel for dirty state updates
 *
 * @param notebookId - The notebook ID to subscribe to
 * @param channelCallbacks - Callbacks for channel events
 * @returns Unsubscribe function
 */
export function subscribeToNotebook(
  notebookId: number,
  channelCallbacks: NotebookChannelCallbacks,
): () => void {
  if (!callbacks.has(notebookId)) {
    callbacks.set(notebookId, new Set());
  }
  callbacks.get(notebookId)!.add(channelCallbacks);

  if (!subscriptions.has(notebookId)) {
    const subscription = consumer.subscriptions.create(
      { channel: "NotebookChannel", notebook_id: notebookId },
      {
        connected() {
          console.log(`[NotebookChannel] Connected to notebook ${notebookId}`);
          callbacks.get(notebookId)?.forEach((cb) => cb.onConnected?.());
        },

        disconnected() {
          console.log(
            `[NotebookChannel] Disconnected from notebook ${notebookId}`,
          );
          callbacks.get(notebookId)?.forEach((cb) => cb.onDisconnected?.());
        },

        received(data: NotebookDirtyMessage) {
          console.log(`[NotebookChannel] Received:`, data);
          if (data.type === "dirty_state") {
            callbacks
              .get(notebookId)
              ?.forEach((cb) => cb.onDirtyState?.(data.dirty));

            // Dispatch a custom event for other components to listen to
            const event = new CustomEvent("notebook:dirty_state", {
              detail: { notebookId, dirty: data.dirty },
            });
            window.dispatchEvent(event);
          }
        },
      },
    );

    subscriptions.set(notebookId, subscription);
  }

  return () => {
    const cbs = callbacks.get(notebookId);
    if (cbs) {
      cbs.delete(channelCallbacks);

      if (cbs.size === 0) {
        const subscription = subscriptions.get(notebookId);
        if (subscription) {
          subscription.unsubscribe();
          subscriptions.delete(notebookId);
        }
        callbacks.delete(notebookId);
      }
    }
  };
}

/**
 * Notify the backend that a cell has been changed
 *
 * @param notebookId - The notebook ID
 */
export function notifyCellChanged(notebookId: number): void {
  const subscription = subscriptions.get(notebookId);
  if (subscription) {
    subscription.perform("cell_changed", {});
  }
}

export default { subscribeToNotebook, notifyCellChanged };
