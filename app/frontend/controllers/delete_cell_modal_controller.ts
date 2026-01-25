import { Controller } from "@hotwired/stimulus";

export default class extends Controller<HTMLDialogElement> {
  static targets = ["dialog"] as const;

  declare readonly dialogTarget: HTMLDialogElement;

  private onConfirm?: () => void;

  connect() {
    // If the dialog was left open in a previous state, ensure it starts closed
    if (this.dialogTarget.open) this.dialogTarget.close();
  }

  open(onConfirm: () => void) {
    this.onConfirm = onConfirm;
    this.dialogTarget.showModal();
  }

  confirm() {
    this.onConfirm?.();
    this.close();
  }

  cancel() {
    this.close();
  }

  close() {
    this.dialogTarget.close();
    this.onConfirm = undefined;
  }
}
