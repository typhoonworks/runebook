import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "runemdTab",
    "irbTab",
    "runemdContent",
    "irbContent",
    "runemdPreview",
    "irbPreview",
    "runemdFilename",
    "irbFilename",
    "copyRunemdBtn",
    "copyIrbBtn",
  ];
  static values = {
    title: String,
  };

  declare runemdTabTarget: HTMLButtonElement;
  declare irbTabTarget: HTMLButtonElement;
  declare runemdContentTarget: HTMLElement;
  declare irbContentTarget: HTMLElement;
  declare runemdPreviewTarget: HTMLPreElement;
  declare irbPreviewTarget: HTMLPreElement;
  declare runemdFilenameTarget: HTMLElement;
  declare irbFilenameTarget: HTMLElement;
  declare copyRunemdBtnTarget: HTMLButtonElement;
  declare copyIrbBtnTarget: HTMLButtonElement;
  declare titleValue: string;

  private runemdContent: string = "";
  private irbContent: string = "";

  open(runemdContent: string, irbContent: string, title: string) {
    this.runemdContent = runemdContent;
    this.irbContent = irbContent;

    // Update title-based filenames
    const slug = this.slugify(title);
    this.runemdFilenameTarget.textContent = `${slug}.runemd`;
    this.irbFilenameTarget.textContent = `${slug}.rb`;

    // Set preview content
    this.runemdPreviewTarget.textContent = runemdContent;
    this.irbPreviewTarget.textContent = irbContent;

    // Reset to first tab
    this.showRunemd();

    const modal = this.element as HTMLDialogElement;
    modal.showModal();
  }

  close() {
    const modal = this.element as HTMLDialogElement;
    modal.close();
  }

  showRunemd() {
    this.runemdTabTarget.classList.add("tab-active");
    this.irbTabTarget.classList.remove("tab-active");
    this.runemdContentTarget.classList.remove("hidden");
    this.irbContentTarget.classList.add("hidden");
  }

  showIrb() {
    this.runemdTabTarget.classList.remove("tab-active");
    this.irbTabTarget.classList.add("tab-active");
    this.runemdContentTarget.classList.add("hidden");
    this.irbContentTarget.classList.remove("hidden");
  }

  async copyRunemd() {
    await this.copyToClipboard(this.runemdContent, this.copyRunemdBtnTarget);
  }

  async copyIrb() {
    await this.copyToClipboard(this.irbContent, this.copyIrbBtnTarget);
  }

  private async copyToClipboard(content: string, button: HTMLButtonElement) {
    try {
      await navigator.clipboard.writeText(content);

      // Show success feedback
      const originalHtml = button.innerHTML;
      button.innerHTML = `
        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-5 h-5 text-success"><path d="M20 6 9 17l-5-5"/></svg>
      `;

      setTimeout(() => {
        button.innerHTML = originalHtml;
      }, 2000);
    } catch (error) {
      console.error("Failed to copy to clipboard:", error);
    }
  }

  private slugify(text: string): string {
    return text
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "_")
      .replace(/^_+|_+$/g, "")
      .replace(/_+/g, "_");
  }
}
