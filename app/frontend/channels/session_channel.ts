// SessionChannel subscription for real-time evaluation output streaming
// Subscribes to session-specific channel and dispatches events for cell controllers

import consumer from "./consumer";
import type { Subscription } from "@rails/actioncable";

export interface SessionOutputMessage {
  type: "output";
  cell_ref: string;
  stdout?: string;
  stderr?: string;
  timestamp: number;
}

export interface SessionChannelCallbacks {
  onOutput?: (message: SessionOutputMessage) => void;
  onConnected?: () => void;
  onDisconnected?: () => void;
}

const subscriptions = new Map<string, Subscription>();
const callbacks = new Map<string, Set<SessionChannelCallbacks>>();

export function subscribeToSession(
  sessionToken: string,
  channelCallbacks: SessionChannelCallbacks,
): () => void {
  if (!callbacks.has(sessionToken)) {
    callbacks.set(sessionToken, new Set());
  }
  callbacks.get(sessionToken)!.add(channelCallbacks);

  if (!subscriptions.has(sessionToken)) {
    const subscription = consumer.subscriptions.create(
      { channel: "SessionChannel", session_token: sessionToken },
      {
        connected() {
          console.log(`[SessionChannel] Connected to session ${sessionToken}`);
          callbacks.get(sessionToken)?.forEach((cb) => cb.onConnected?.());
        },

        disconnected() {
          console.log(
            `[SessionChannel] Disconnected from session ${sessionToken}`,
          );
          callbacks.get(sessionToken)?.forEach((cb) => cb.onDisconnected?.());
        },

        received(data: SessionOutputMessage) {
          console.log(`[SessionChannel] Received:`, data);
          if (data.type === "output") {
            callbacks.get(sessionToken)?.forEach((cb) => cb.onOutput?.(data));

            const event = new CustomEvent("session:output", {
              detail: { ...data, sessionToken },
            });
            window.dispatchEvent(event);
          }
        },
      },
    );

    subscriptions.set(sessionToken, subscription);
  }

  return () => {
    const cbs = callbacks.get(sessionToken);
    if (cbs) {
      cbs.delete(channelCallbacks);

      if (cbs.size === 0) {
        const subscription = subscriptions.get(sessionToken);
        if (subscription) {
          subscription.unsubscribe();
          subscriptions.delete(sessionToken);
        }
        callbacks.delete(sessionToken);
      }
    }
  };
}

export default { subscribeToSession };
