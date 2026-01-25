import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["title", "warning", "info", "filePath", "confirmBtn"];

  declare titleTarget: HTMLElement;
  declare warningTarget: HTMLElement;
  declare infoTarget: HTMLElement;
  declare filePathTarget: HTMLElement;
  declare confirmBtnTarget: HTMLButtonElement;

  private sessionToken: string = "";
  private isPersisted: boolean = false;

  open(token: string, title: string, persisted: boolean, filePath: string) {
    this.sessionToken = token;
    this.isPersisted = persisted;

    this.titleTarget.textContent = title;

    // Show appropriate message based on persistence state
    if (persisted) {
      this.warningTarget.classList.add("hidden");
      this.infoTarget.classList.remove("hidden");
      this.filePathTarget.textContent = filePath;
      this.filePathTarget.title = filePath;
    } else {
      this.warningTarget.classList.remove("hidden");
      this.infoTarget.classList.add("hidden");
    }

    const modal = this.element as HTMLDialogElement;
    modal.showModal();
  }

  cancel() {
    const modal = this.element as HTMLDialogElement;
    modal.close();
  }

  async confirm() {
    this.confirmBtnTarget.disabled = true;
    this.confirmBtnTarget.textContent = "Closing...";

    try {
      const csrfToken = document.querySelector<HTMLMetaElement>(
        'meta[name="csrf-token"]'
      )?.content;

      const response = await fetch(`/sessions/${this.sessionToken}`, {
        method: "DELETE",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken || "",
          Accept: "application/json",
        },
        body: JSON.stringify({
          delete_file: !this.isPersisted,
        }),
      });

      if (response.ok) {
        const data = await response.json();
        window.location.href = data.redirect_to || "/";
      } else {
        throw new Error("Failed to close session");
      }
    } catch (error) {
      console.error("Error closing session:", error);
      this.confirmBtnTarget.disabled = false;
      this.confirmBtnTarget.textContent = "Close session";
    }
  }
}
