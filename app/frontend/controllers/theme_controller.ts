import { Controller } from '@hotwired/stimulus'

// data-controller="theme"
export default class extends Controller {
  static targets: string[] = []

  connect() {
    const stored = window.localStorage.getItem('runebook:theme')
    if (stored) document.documentElement.dataset.theme = stored
  }

  toggle() {
    const current = document.documentElement.dataset.theme || 'runebook'
    const next = current === 'runebook' ? 'runebook-dark' : 'runebook'
    document.documentElement.dataset.theme = next
    window.localStorage.setItem('runebook:theme', next)
  }
}

