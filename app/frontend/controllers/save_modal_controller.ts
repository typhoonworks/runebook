import { Controller } from "@hotwired/stimulus";

interface DirectoryEntry {
  name: string;
  path: string;
  type: "directory" | "file";
}

interface BrowseResponse {
  ok: boolean;
  current_path: string;
  parent_path: string | null;
  workspace_root: string;
  entries: DirectoryEntry[];
  error?: string;
}

/**
 * Save Modal Controller
 *
 * Manages the "Save to file" modal dialog that appears when saving a new notebook.
 * Provides directory browsing, new folder creation, and file naming.
 */
export default class extends Controller<HTMLDialogElement> {
  static targets = [
    "pathInput",
    "directoryBrowser",
    "newDirectoryModal",
    "newDirectoryInput",
    "filenameInput",
    "filenameError",
    "autosaveSelect",
    "saveButton",
    "loadingOverlay",
  ] as const;

  static values = {
    sessionToken: String,
    defaultFilename: String,
    browseUrl: String,
    createDirectoryUrl: String,
  };

  declare readonly pathInputTarget: HTMLInputElement;
  declare readonly directoryBrowserTarget: HTMLElement;
  declare readonly newDirectoryModalTarget: HTMLDialogElement;
  declare readonly newDirectoryInputTarget: HTMLInputElement;
  declare readonly filenameInputTarget: HTMLInputElement;
  declare readonly filenameErrorTarget: HTMLElement;
  declare readonly autosaveSelectTarget: HTMLSelectElement;
  declare readonly saveButtonTarget: HTMLButtonElement;
  declare readonly loadingOverlayTarget: HTMLElement;

  declare sessionTokenValue: string;
  declare defaultFilenameValue: string;
  declare browseUrlValue: string;
  declare createDirectoryUrlValue: string;

  private currentPath: string = "";
  private parentPath: string | null = null;
  private workspaceRoot: string = "";
  private onSaveCallback?: (data: {
    filePath: string;
    autosaveInterval: number;
  }) => void;

  connect() {
    // Set default filename
    if (this.defaultFilenameValue) {
      this.filenameInputTarget.value = this.defaultFilenameValue;
    }
  }

  /**
   * Open the modal and load the directory listing
   */
  async open(
    onSave?: (data: { filePath: string; autosaveInterval: number }) => void,
  ) {
    this.onSaveCallback = onSave;
    this.element.showModal();
    await this.loadDirectory();
  }

  /**
   * Close the modal
   */
  close() {
    this.element.close();
  }

  /**
   * Load directory contents
   */
  async loadDirectory(path?: string) {
    try {
      this.showLoading(true);

      const params = new URLSearchParams();
      if (path) {
        params.append("path", path);
      }

      const url = params.toString()
        ? `${this.browseUrlValue}?${params}`
        : this.browseUrlValue;

      const response = await fetch(url, {
        headers: {
          Accept: "application/json",
        },
        credentials: "same-origin",
      });

      const data: BrowseResponse = await response.json();

      if (data.ok) {
        this.currentPath = data.current_path;
        this.parentPath = data.parent_path;
        this.workspaceRoot = data.workspace_root;
        this.pathInputTarget.value = this.currentPath;
        this.renderDirectoryListing(data.entries);
      } else {
        this.showError(data.error || "Failed to load directory");
      }
    } catch (error) {
      console.error("[SaveModal] Load directory error:", error);
      this.showError("Failed to load directory");
    } finally {
      this.showLoading(false);
    }
  }

  /**
   * Navigate from path input
   */
  async navigateFromInput() {
    const inputPath = this.pathInputTarget.value.trim();
    if (inputPath && inputPath !== this.currentPath) {
      await this.loadDirectory(inputPath);
    }
  }

  /**
   * Navigate to parent directory
   */
  async navigateToParent() {
    if (this.parentPath) {
      await this.loadDirectory(this.parentPath);
    }
  }

  /**
   * Handle entry click (navigate to directory or select file)
   */
  async selectEntry(event: Event) {
    const target = event.currentTarget as HTMLElement;
    const path = target.dataset.path;
    const type = target.dataset.type;

    if (!path) return;

    if (type === "directory") {
      await this.loadDirectory(path);
    } else if (type === "file") {
      // Set filename to the selected file
      const filename = path.split("/").pop() || "";
      this.filenameInputTarget.value = filename;
      this.validateFilename();
    }
  }

  /**
   * Show new directory modal
   */
  showNewDirectoryModal() {
    this.newDirectoryInputTarget.value = "";
    this.newDirectoryModalTarget.showModal();
    this.newDirectoryInputTarget.focus();
  }

  /**
   * Close new directory modal
   */
  closeNewDirectoryModal() {
    this.newDirectoryModalTarget.close();
  }

  /**
   * Create a new directory
   */
  async createDirectory() {
    const name = this.newDirectoryInputTarget.value.trim();
    if (!name) return;

    try {
      const csrfToken = this.getCSRFToken();

      const response = await fetch(this.createDirectoryUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          Accept: "application/json",
        },
        credentials: "same-origin",
        body: JSON.stringify({
          path: this.currentPath,
          name: name,
        }),
      });

      const data = await response.json();

      if (data.ok) {
        this.closeNewDirectoryModal();
        // Navigate to the new directory
        await this.loadDirectory(data.path);
      } else {
        alert(data.error || "Failed to create directory");
      }
    } catch (error) {
      console.error("[SaveModal] Create directory error:", error);
      alert("Failed to create directory");
    }
  }

  /**
   * Validate the filename input
   */
  validateFilename() {
    const filename = this.filenameInputTarget.value.trim();
    const errorLabel = this.filenameErrorTarget.querySelector("span");

    if (!errorLabel) return true;

    if (!filename) {
      errorLabel.textContent = "Filename is required";
      errorLabel.classList.remove("hidden");
      return false;
    }

    if (!filename.endsWith(".runemd")) {
      errorLabel.textContent = "Filename must end with .runemd";
      errorLabel.classList.remove("hidden");
      return false;
    }

    // Check for invalid characters
    if (!/^[\w\-. ]+\.runemd$/.test(filename)) {
      errorLabel.textContent = "Invalid filename characters";
      errorLabel.classList.remove("hidden");
      return false;
    }

    errorLabel.classList.add("hidden");
    return true;
  }

  /**
   * Save the file
   */
  async save() {
    if (!this.validateFilename()) return;

    const filename = this.filenameInputTarget.value.trim();
    const filePath = `${this.currentPath}/${filename}`;
    const autosaveInterval = parseInt(this.autosaveSelectTarget.value, 10);

    if (this.onSaveCallback) {
      this.onSaveCallback({ filePath, autosaveInterval });
    }

    this.close();
  }

  // Private methods

  private renderDirectoryListing(entries: DirectoryEntry[]) {
    // Build HTML for 3-column grid
    let html = '<div class="grid grid-cols-3 gap-1">';

    // Add parent directory entry (..) if we have a parent
    if (this.parentPath) {
      html += `
        <button type="button"
                class="flex items-center gap-2 px-3 py-2 hover:bg-base-200 rounded text-left transition-colors"
                data-action="click->save-modal#navigateToParent">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-base-content/50" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
          </svg>
          <span class="text-base-content/70">..</span>
        </button>
      `;
    }

    if (entries.length === 0 && !this.parentPath) {
      html += `
        <div class="col-span-3 flex items-center justify-center py-8 text-base-content/60">
          Empty folder
        </div>
      `;
    } else {
      // Add all entries
      for (const entry of entries) {
        const isDirectory = entry.type === "directory";
        const iconClass = isDirectory
          ? "text-base-content/50"
          : "text-base-content/60";

        const icon = isDirectory
          ? `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 ${iconClass}" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
            </svg>`
          : `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 ${iconClass}" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>`;

        html += `
          <button type="button"
                  class="flex items-center gap-2 px-3 py-2 hover:bg-base-200 rounded text-left transition-colors truncate"
                  data-action="click->save-modal#selectEntry"
                  data-path="${entry.path}"
                  data-type="${entry.type}"
                  title="${entry.name}">
            ${icon}
            <span class="truncate">${entry.name}</span>
          </button>
        `;
      }
    }

    html += "</div>";
    this.directoryBrowserTarget.innerHTML = html;
  }

  private showLoading(show: boolean) {
    if (show) {
      this.loadingOverlayTarget.classList.remove("hidden");
    } else {
      this.loadingOverlayTarget.classList.add("hidden");
    }
  }

  private showError(message: string) {
    this.directoryBrowserTarget.innerHTML = `
      <div class="flex items-center justify-center py-8 text-error">
        ${message}
      </div>
    `;
  }

  private getCSRFToken(): string {
    const meta = document.querySelector(
      'meta[name="csrf-token"]',
    ) as HTMLMetaElement | null;
    return meta?.content || "";
  }
}
