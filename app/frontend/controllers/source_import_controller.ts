import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["textarea", "submitButton"] as const;

  declare readonly textareaTarget: HTMLTextAreaElement;
  declare readonly submitButtonTarget: HTMLButtonElement;

  connect() {
    this.validate();
  }

  validate() {
    const content = this.textareaTarget.value.trim();
    this.submitButtonTarget.disabled = content.length === 0;
  }
}
