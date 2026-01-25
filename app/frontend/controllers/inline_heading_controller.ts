import { Controller } from "@hotwired/stimulus";

export default class extends Controller<HTMLElement> {
  connect() {
    this.element.setAttribute("contenteditable", "");
    this.element.setAttribute("spellcheck", "false");
    this.element.setAttribute("tabindex", "0");
  }

  keydown(event: KeyboardEvent) {
    if (event.key === "Enter") {
      event.preventDefault();
      (this.element as HTMLElement).blur();
    }
  }

  focus() {
    // Deactivate any active cell when focusing headers
    const evt = new CustomEvent("markdown-cell:activate", {
      detail: { id: "__none__" },
    });
    window.dispatchEvent(evt);
  }
}
