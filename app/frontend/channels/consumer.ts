// ActionCable consumer for Runebook
// Provides WebSocket connection for real-time output streaming

import { createConsumer } from "@rails/actioncable"

// Create a single consumer instance for the application
export const consumer = createConsumer()

export default consumer
