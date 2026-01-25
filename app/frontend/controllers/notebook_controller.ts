import { Controller } from "@hotwired/stimulus";
import {
  subscribeToNotebook,
  notifyCellChanged,
} from "../channels/notebook_channel";
import {
  collectCellsFromDOM,
  serializeNotebook,
  exportToRunemd,
  exportToIrb,
} from "../lib/runemd";

/**
 * Notebook controller for managing autosave, manual save, and dirty state
 *
 * Handles:
 * - Autosave timer (default 30s)
 * - Manual save via button or Cmd/Ctrl+S
 * - Dirty state indicator updates
 * - ActionCable subscription for collaborative dirty state
 */
export default class extends Controller<HTMLDivElement> {
  static targets = ["dirtyIndicator", "saveButton", "saveStatus"] as const;
  static values = {
    notebookId: Number,
    sessionToken: String,
    autosaveInterval: { type: Number, default: 30000 },
    dirty: { type: Boolean, default: false },
    persistedToUserPath: { type: Boolean, default: false },
    filePath: { type: String, default: "" },
  };

  declare readonly dirtyIndicatorTarget: HTMLElement;
  declare readonly hasDirtyIndicatorTarget: boolean;
  declare readonly saveButtonTarget: HTMLButtonElement;
  declare readonly hasSaveButtonTarget: boolean;
  declare readonly saveStatusTarget: HTMLElement;
  declare readonly hasSaveStatusTarget: boolean;

  declare notebookIdValue: number;
  declare sessionTokenValue: string;
  declare autosaveIntervalValue: number;
  declare dirtyValue: boolean;
  declare persistedToUserPathValue: boolean;
  declare filePathValue: string;

  private autosaveTimer?: number;
  private unsubscribeFromNotebook?: () => void;
  private isSaving = false;

  connect() {
    // Subscribe to notebook channel for dirty state updates
    this.unsubscribeFromNotebook = subscribeToNotebook(this.notebookIdValue, {
      onDirtyState: (dirty: boolean) => {
        this.dirtyValue = dirty;
        this.updateDirtyIndicator();
      },
      onConnected: () => {
        console.log("[NotebookController] Connected to notebook channel");
      },
    });

    // Listen for cell changes from child controllers
    this.element.addEventListener("notebook:cell-changed", this.onCellChanged);

    // Set up keyboard shortcut for save
    document.addEventListener("keydown", this.onKeyDown);

    // Start autosave timer
    this.startAutosaveTimer();

    // Initial UI state
    this.updateDirtyIndicator();
  }

  disconnect() {
    this.unsubscribeFromNotebook?.();
    this.element.removeEventListener(
      "notebook:cell-changed",
      this.onCellChanged,
    );
    document.removeEventListener("keydown", this.onKeyDown);
    this.stopAutosaveTimer();
  }

  // Event handlers
  private onCellChanged = () => {
    // Notify backend that a cell changed
    notifyCellChanged(this.notebookIdValue);

    // Restart autosave timer on change
    this.restartAutosaveTimer();
  };

  private onKeyDown = (event: KeyboardEvent) => {
    // Cmd+S (Mac) or Ctrl+S (Windows/Linux)
    if ((event.metaKey || event.ctrlKey) && event.key === "s") {
      event.preventDefault();
      this.save();
    }
  };

  // Autosave timer management
  private startAutosaveTimer() {
    if (this.autosaveIntervalValue <= 0) return;

    this.autosaveTimer = window.setInterval(() => {
      if (this.dirtyValue && !this.isSaving) {
        this.autosave();
      }
    }, this.autosaveIntervalValue);
  }

  private stopAutosaveTimer() {
    if (this.autosaveTimer) {
      window.clearInterval(this.autosaveTimer);
      this.autosaveTimer = undefined;
    }
  }

  private restartAutosaveTimer() {
    this.stopAutosaveTimer();
    this.startAutosaveTimer();
  }

  // Save actions
  async save() {
    if (this.isSaving) return;

    // If document doesn't have a user-chosen path, show save modal
    if (!this.persistedToUserPathValue) {
      this.openSaveModal();
      return;
    }

    await this.performSave();
  }

  /**
   * Open the export modal
   */
  openExportModal() {
    const modal = document.getElementById("export-modal") as HTMLDialogElement;
    if (!modal) {
      console.error("[NotebookController] Export modal not found");
      return;
    }

    const exportModalController = this.application.getControllerForElementAndIdentifier(
      modal,
      "export-modal",
    ) as any;

    if (!exportModalController) {
      console.error("[NotebookController] Export modal controller not found");
      return;
    }

    // Get title and cells
    const titleEl = document.getElementById("notebook-heading");
    const title = titleEl?.textContent?.trim() || "Untitled notebook";
    const { setupCell, sections } = collectCellsFromDOM(this.element);

    // Generate export content
    const runemdContent = exportToRunemd(title, setupCell, sections);
    const irbContent = exportToIrb(title, setupCell, sections);

    exportModalController.open(runemdContent, irbContent, title);
  }

  /**
   * Close the current session
   */
  close() {
    const modal = document.getElementById("close-session-modal") as HTMLDialogElement;
    if (!modal) {
      console.error("[NotebookController] Close session modal not found");
      return;
    }

    const closeModalController = this.application.getControllerForElementAndIdentifier(
      modal,
      "close-session-modal",
    ) as any;

    if (!closeModalController) {
      console.error("[NotebookController] Close session modal controller not found");
      return;
    }

    // Get session info from data attributes
    const titleEl = document.getElementById("notebook-heading");
    const title = titleEl?.textContent?.trim() || "Untitled notebook";

    closeModalController.open(
      this.sessionTokenValue,
      title,
      this.persistedToUserPathValue,
      this.filePathValue,
    );
  }

  /**
   * Open the save modal for first-time save
   */
  private openSaveModal() {
    const modal = document.getElementById("save-modal") as HTMLDialogElement;
    if (!modal) {
      console.error("[NotebookController] Save modal not found");
      return;
    }

    // Get the save-modal controller
    const saveModalController = this.application.getControllerForElementAndIdentifier(
      modal,
      "save-modal",
    ) as any;

    if (!saveModalController) {
      console.error("[NotebookController] Save modal controller not found");
      return;
    }

    saveModalController.open(
      async (data: { filePath: string; autosaveInterval: number }) => {
        await this.performSave(data.filePath, data.autosaveInterval);
      },
    );
  }

  /**
   * Perform the actual save operation
   */
  private async performSave(newFilePath?: string, autosaveInterval?: number) {
    this.isSaving = true;
    this.updateSaveStatus("saving");

    try {
      const data = this.collectNotebookData();
      const csrfToken = this.getCSRFToken();

      const body: Record<string, unknown> = { ...data };

      if (newFilePath) {
        body.new_file_path = newFilePath;
      }

      if (autosaveInterval !== undefined) {
        body.autosave_interval = autosaveInterval;
      }

      const response = await fetch(`/sessions/${this.sessionTokenValue}/save`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          Accept: "application/json",
        },
        credentials: "same-origin",
        body: JSON.stringify(body),
      });

      const result = await response.json();

      if (result.ok) {
        this.dirtyValue = false;
        this.persistedToUserPathValue = result.persisted_to_user_path;

        // Update autosave interval if changed
        if (result.autosave_interval !== undefined) {
          this.autosaveIntervalValue = result.autosave_interval;
          this.restartAutosaveTimer();
        }

        this.updateDirtyIndicator();
        this.updateSaveStatus("saved");
      } else {
        console.error("[NotebookController] Save failed:", result.error);
        this.updateSaveStatus("error");
      }
    } catch (error) {
      console.error("[NotebookController] Save error:", error);
      this.updateSaveStatus("error");
    } finally {
      this.isSaving = false;
    }
  }

  async autosave() {
    if (this.isSaving) return;

    try {
      const data = this.collectNotebookData();
      const csrfToken = this.getCSRFToken();

      const response = await fetch(`/sessions/${this.sessionTokenValue}/autosave`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          Accept: "application/json",
        },
        credentials: "same-origin",
        body: JSON.stringify(data),
      });

      const result = await response.json();

      if (!result.ok) {
        console.error("[NotebookController] Autosave failed:", result.error);
      }
    } catch (error) {
      console.error("[NotebookController] Autosave error:", error);
    }
  }

  // Data collection
  private collectNotebookData(): {
    title: string;
    setup_cell: { type: string; content: string } | null;
    sections: Array<{
      title: string;
      cells: Array<{ type: string; content: string }>;
    }>;
  } {
    // Get title from the heading
    const titleEl = document.getElementById("notebook-heading");
    const title = titleEl?.textContent?.trim() || "Untitled notebook";

    // Collect cells from DOM
    const { setupCell, sections } = collectCellsFromDOM(this.element);

    return serializeNotebook(title, setupCell, sections);
  }

  // UI updates
  private updateDirtyIndicator() {
    if (!this.hasDirtyIndicatorTarget) return;

    const indicator = this.dirtyIndicatorTarget;

    if (this.dirtyValue) {
      // Yellow/warning color for dirty state
      indicator.classList.remove("bg-success", "bg-base-300");
      indicator.classList.add("bg-warning");
      indicator.setAttribute("title", "Unsaved changes");
    } else {
      // Green/success color for clean state
      indicator.classList.remove("bg-warning", "bg-base-300");
      indicator.classList.add("bg-success");
      indicator.setAttribute("title", "All changes saved");
    }
  }

  private updateSaveStatus(status: "saving" | "saved" | "error") {
    if (this.hasSaveButtonTarget) {
      this.saveButtonTarget.disabled = status === "saving";
    }

    if (this.hasSaveStatusTarget) {
      switch (status) {
        case "saving":
          this.saveStatusTarget.textContent = "Saving...";
          this.saveStatusTarget.classList.remove("text-success", "text-error");
          this.saveStatusTarget.classList.add("text-base-content/60");
          break;
        case "saved":
          this.saveStatusTarget.textContent = "Saved";
          this.saveStatusTarget.classList.remove(
            "text-base-content/60",
            "text-error",
          );
          this.saveStatusTarget.classList.add("text-success");
          // Clear "Saved" message after a delay
          setTimeout(() => {
            if (this.hasSaveStatusTarget) {
              this.saveStatusTarget.textContent = "";
            }
          }, 2000);
          break;
        case "error":
          this.saveStatusTarget.textContent = "Save failed";
          this.saveStatusTarget.classList.remove(
            "text-base-content/60",
            "text-success",
          );
          this.saveStatusTarget.classList.add("text-error");
          break;
      }
    }
  }

  private getCSRFToken(): string {
    const meta = document.querySelector(
      'meta[name="csrf-token"]',
    ) as HTMLMetaElement | null;
    return meta?.content || "";
  }
}
