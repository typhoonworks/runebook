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
  entries: DirectoryEntry[];
  error?: string;
}

interface CreateResponse {
  ok: boolean;
  path?: string;
  name?: string;
  error?: string;
}

export default class extends Controller {
  static targets = [
    "pathInput",
    "directoryBrowser",
    "browserContainer",
    "loadingOverlay",
    "openButton",
    "newDirectoryModal",
    "newDirectoryInput",
  ] as const;

  static values = {
    browseUrl: String,
    openUrl: String,
    createDirectoryUrl: String,
    createNotebookUrl: String,
    initialPath: String,
  };

  declare readonly pathInputTarget: HTMLInputElement;
  declare readonly directoryBrowserTarget: HTMLElement;
  declare readonly browserContainerTarget: HTMLElement;
  declare readonly loadingOverlayTarget: HTMLElement;
  declare readonly openButtonTarget: HTMLButtonElement;
  declare readonly newDirectoryModalTarget: HTMLDialogElement;
  declare readonly newDirectoryInputTarget: HTMLInputElement;

  declare browseUrlValue: string;
  declare openUrlValue: string;
  declare createDirectoryUrlValue: string;
  declare createNotebookUrlValue: string;
  declare initialPathValue: string;

  private currentPath: string = "";
  private parentPath: string | null = null;

  connect() {
    this.currentPath = this.initialPathValue;
    this.pathInputTarget.value = this.currentPath;
    this.loadDirectory(this.currentPath);
  }

  async loadDirectory(path: string) {
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
        headers: { Accept: "application/json" },
        credentials: "same-origin",
      });

      const data: BrowseResponse = await response.json();

      if (data.ok) {
        this.currentPath = data.current_path;
        this.parentPath = data.parent_path;
        this.pathInputTarget.value = this.currentPath;
        this.renderDirectoryListing(data.entries);
      } else {
        this.showError(data.error || "Failed to load directory");
      }
    } catch (error) {
      console.error("[FileBrowser] Load directory error:", error);
      this.showError("Failed to load directory");
    } finally {
      this.showLoading(false);
    }
  }

  async navigateFromInput() {
    const inputPath = this.pathInputTarget.value.trim();
    if (!inputPath) return;

    // Check if it looks like a directory (no .runemd extension)
    if (!inputPath.endsWith(".runemd")) {
      await this.loadDirectory(inputPath);
    }
  }

  async selectEntry(event: Event) {
    const target = event.currentTarget as HTMLElement;
    const path = target.dataset.path;
    const type = target.dataset.type;

    if (!path) return;

    if (type === "directory") {
      await this.loadDirectory(path);
    } else if (type === "file") {
      // Set the file path in the input
      this.pathInputTarget.value = path;
    }
  }

  async navigateToParent() {
    if (this.parentPath) {
      await this.loadDirectory(this.parentPath);
    }
  }

  openFromInput() {
    const filePath = this.pathInputTarget.value.trim();
    if (!filePath) return;

    // Only open if it's a .runemd file
    if (!filePath.endsWith(".runemd")) {
      // If it's a directory, just navigate to it
      this.loadDirectory(filePath);
      return;
    }

    this.openFile(filePath);
  }

  private openFile(filePath: string) {
    const form = document.createElement("form");
    form.method = "POST";
    form.action = this.openUrlValue;

    const csrfToken = this.getCSRFToken();
    const csrfInput = document.createElement("input");
    csrfInput.type = "hidden";
    csrfInput.name = "authenticity_token";
    csrfInput.value = csrfToken;
    form.appendChild(csrfInput);

    const filePathInput = document.createElement("input");
    filePathInput.type = "hidden";
    filePathInput.name = "file_path";
    filePathInput.value = filePath;
    form.appendChild(filePathInput);

    document.body.appendChild(form);
    form.submit();
  }

  showNewDirectoryModal() {
    this.newDirectoryInputTarget.value = "";
    this.newDirectoryModalTarget.showModal();
    this.newDirectoryInputTarget.focus();
  }

  closeNewDirectoryModal() {
    this.newDirectoryModalTarget.close();
  }

  async createDirectory() {
    const name = this.newDirectoryInputTarget.value.trim();
    if (!name) return;

    try {
      const response = await fetch(this.createDirectoryUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.getCSRFToken(),
          Accept: "application/json",
        },
        credentials: "same-origin",
        body: JSON.stringify({
          path: this.currentPath,
          name: name,
        }),
      });

      const data: CreateResponse = await response.json();

      if (data.ok && data.path) {
        this.closeNewDirectoryModal();
        await this.loadDirectory(data.path);
      } else {
        alert(data.error || "Failed to create directory");
      }
    } catch (error) {
      console.error("[FileBrowser] Create directory error:", error);
      alert("Failed to create directory");
    }
  }

  async createNewNotebook() {
    const name = prompt("Enter notebook name:");
    if (!name) return;

    try {
      const response = await fetch(this.createNotebookUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.getCSRFToken(),
          Accept: "application/json",
        },
        credentials: "same-origin",
        body: JSON.stringify({
          path: this.currentPath,
          name: name,
        }),
      });

      const data: CreateResponse = await response.json();

      if (data.ok && data.path) {
        // Open the newly created notebook
        this.openFile(data.path);
      } else {
        alert(data.error || "Failed to create notebook");
      }
    } catch (error) {
      console.error("[FileBrowser] Create notebook error:", error);
      alert("Failed to create notebook");
    }
  }

  private renderDirectoryListing(entries: DirectoryEntry[]) {
    // Build HTML for 3-column grid
    let html = '<div class="grid grid-cols-3 gap-1">';

    // Add parent directory entry (..) if we have a parent
    if (this.parentPath) {
      html += `
        <button type="button"
                class="flex items-center gap-2 px-3 py-2 hover:bg-base-200 rounded text-left transition-colors"
                data-action="click->file-browser#navigateToParent">
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
                  data-action="click->file-browser#selectEntry"
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
