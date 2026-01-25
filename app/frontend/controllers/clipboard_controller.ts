import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static values = { text: String }
  declare readonly textValue: string
  declare readonly hasTextValue: boolean

  copy(event: Event) {
    event.preventDefault()
    const text = this.hasTextValue ? this.textValue : this.element.textContent || ""
    navigator.clipboard.writeText(text).then(() => {
      this.showCopied()
    })
  }

  private showCopied() {
    const original = this.element.innerHTML
    this.element.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" /></svg>`
    setTimeout(() => {
      this.element.innerHTML = original
    }, 1500)
  }
}
