import { Controller } from "@hotwired/stimulus";

export default class extends Controller<HTMLElement> {
  static values = {
    updateUrl: String,
    token: String,
  };

  declare readonly updateUrlValue: string;
  declare readonly tokenValue: string;

  private original = "";
  private saving = false;

  connect() {
    this.element.setAttribute("contenteditable", "");
    this.element.setAttribute("spellcheck", "false");
    this.element.setAttribute("tabindex", "0");

    this.original = (this.element.textContent || "").trim();
  }

  disconnect() {}

  // Prevent newline; save on Enter
  keydown(event: KeyboardEvent) {
    if (event.key === "Enter") {
      event.preventDefault();
      (this.element as HTMLElement).blur();
    }
  }

  async blur() {
    await this.saveIfChanged();
  }

  focus() {
    // Deactivate any active cell when focusing notebook title
    const evt = new CustomEvent("markdown-cell:activate", { detail: { id: "__none__" } })
    window.dispatchEvent(evt)
  }

  private async saveIfChanged() {
    const title = (this.element.textContent || "").trim();
    if (!title || title === this.original || this.saving) return;
    this.saving = true;

    try {
      await fetch(this.updateUrlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.tokenValue,
          Accept: "application/json, text/html, */*",
        },
        body: JSON.stringify({ document: { title } }),
      });
      this.original = title;
    } catch (e) {
      // Swallow errors for now; keep UX simple.
    } finally {
      this.saving = false;
    }
  }
}
