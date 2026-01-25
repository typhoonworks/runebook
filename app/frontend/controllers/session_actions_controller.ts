import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  openCloseModal(event: Event) {
    const button = event.currentTarget as HTMLButtonElement;
    const token = button.dataset.sessionToken || "";
    const title = button.dataset.sessionTitle || "";
    const persisted = button.dataset.sessionPersisted === "true";
    const filePath = button.dataset.sessionFilePath || "";

    const modal = document.getElementById("close-session-modal");
    if (modal) {
      const modalController = (
        this.application.getControllerForElementAndIdentifier(
          modal,
          "close-session-modal"
        ) as any
      );
      if (modalController) {
        modalController.open(token, title, persisted, filePath);
      }
    }
  }
}
