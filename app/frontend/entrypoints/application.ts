// Hotwire (Turbo + Stimulus controllers)
import '@hotwired/turbo-rails'
import '../controllers'

// ActionCable for real-time output streaming
import '../channels/consumer'

// Monaco editor (load core API and Ruby language contribution)
// If you only want this on specific pages, consider dynamic import.
import 'monaco-editor/esm/vs/editor/editor.api'
import 'monaco-editor/esm/vs/basic-languages/ruby/ruby.contribution'
import { ensureRubyLanguageConfigured } from '../lib/monaco_ruby_language'

// Ensure Ruby indentation/on-enter rules are active globally
ensureRubyLanguageConfigured()

// CSS loads via a dedicated entrypoint linked in the layout
