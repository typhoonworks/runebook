import { Controller } from "@hotwired/stimulus";
import * as monaco from "monaco-editor/esm/vs/editor/editor.api";

/**
 * Base controller for Monaco editor cells.
 * Provides common functionality: auto-grow, hover/focus state, cell activation.
 */
export default class BaseEditorController extends Controller<HTMLDivElement> {
  protected editor?: monaco.editor.IStandaloneCodeEditor;
  protected cellId = "";
  protected isHovered = false;
  protected isFocused = false;

  // Subclasses must provide these targets
  declare readonly editorTarget: HTMLDivElement;
  declare readonly gutterTarget: HTMLDivElement;
  declare readonly toolbarTarget: HTMLDivElement;
  declare readonly hasToolbarTarget: boolean;

  private onGlobalActivate = (e: Event) => {
    const detail = (e as CustomEvent).detail as { id: string };
    if (!detail) return;
    if (detail.id !== this.cellId) this.setFocused(false);
  };

  /**
   * Monaco options for auto-growing editors (no scrollbars, no scroll beyond last line)
   */
  protected static autoGrowOptions: monaco.editor.IStandaloneEditorConstructionOptions = {
    scrollBeyondLastLine: false,
    scrollbar: { vertical: "hidden", horizontal: "hidden" },
  };

  /**
   * Common Monaco options shared across all editor cells
   */
  protected static baseEditorOptions: monaco.editor.IStandaloneEditorConstructionOptions = {
    minimap: { enabled: false },
    lineNumbers: "on",
    automaticLayout: true,
    fontSize: 14,
    padding: { top: 8, bottom: 8 },
    renderLineHighlight: "none",
    fixedOverflowWidgets: true, // Render autocomplete/hover widgets outside editor bounds
    ...BaseEditorController.autoGrowOptions,
  };

  /**
   * Call in subclass connect() to set up cell ID and activation listeners
   */
  protected setupCellActivation() {
    this.cellId = this.element.dataset.cellId || Math.random().toString(36).slice(2);
    this.element.dataset.cellId = this.cellId;
    window.addEventListener("markdown-cell:activate", this.onGlobalActivate);
    window.addEventListener("ruby-cell:activate", this.onGlobalActivate);
  }

  /**
   * Call in subclass connect() to set up hover tracking
   */
  protected setupHoverTracking() {
    this.element.addEventListener("mouseenter", () => this.setHovered(true));
    this.element.addEventListener("mouseleave", () => this.setHovered(false));
  }

  /**
   * Call in subclass disconnect() to clean up activation listeners
   */
  protected teardownCellActivation() {
    window.removeEventListener("markdown-cell:activate", this.onGlobalActivate);
    window.removeEventListener("ruby-cell:activate", this.onGlobalActivate);
  }

  /**
   * Set up auto-grow behavior: call after editor creation
   */
  protected setupAutoGrow() {
    if (!this.editor) return;
    this.updateEditorHeight();
    // Ensure DOM carries a snapshot of the current content so serializers
    // can read it without needing direct access to Stimulus controllers.
    this.storeContentSnapshot();
    this.editor.onDidChangeModelContent(() => {
      this.updateEditorHeight();
      this.storeContentSnapshot();
      this.dispatchCellChanged();
    });
  }

  /**
   * Dispatch a cell changed event to notify the notebook controller
   * that content has been modified
   */
  protected dispatchCellChanged() {
    const event = new CustomEvent("notebook:cell-changed", {
      bubbles: true,
      detail: { cellId: this.cellId },
    });
    this.element.dispatchEvent(event);
  }

  /**
   * Update editor container height based on content
   */
  protected updateEditorHeight() {
    if (!this.editor) return;
    const contentHeight = this.editor.getContentHeight();
    const minHeight = 100;
    const height = Math.max(contentHeight, minHeight);
    this.editorTarget.style.height = `${height}px`;
    this.editor.layout();
  }

  /**
   * Mirror the current editor content into a data attribute so other
   * controllers/utilities (like the save/export serializer) can read
   * content reliably without coupling to Stimulus internals.
   */
  protected storeContentSnapshot() {
    try {
      const value = this.editor?.getValue() || "";
      this.editorTarget.setAttribute("data-content", value);
    } catch {
      // Best-effort; ignore failures to avoid interrupting typing
    }
  }

  /**
   * Get CSRF token from meta tag
   */
  protected csrfToken(): string {
    const meta = document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement | null;
    return meta?.content || "";
  }

  /**
   * Activate this cell and notify others to deactivate
   */
  protected activateCell(eventName: string) {
    this.setFocused(true);
    const evt = new CustomEvent(eventName, { detail: { id: this.cellId } });
    window.dispatchEvent(evt);
    // Notify other cell types to deactivate
    const crossEvent = eventName === "ruby-cell:activate" ? "markdown-cell:activate" : "ruby-cell:activate";
    window.dispatchEvent(new CustomEvent(crossEvent, { detail: { id: this.cellId } }));
  }

  protected setHovered(hovered: boolean) {
    this.isHovered = hovered;
    this.updateVisibility();
  }

  protected setFocused(focused: boolean) {
    this.isFocused = focused;
    this.updateVisibility();
  }

  /**
   * Update gutter and toolbar visibility based on hover/focus state.
   * Subclasses can override to add custom visibility behavior.
   */
  protected updateVisibility() {
    // Gutter colors
    this.gutterTarget.classList.remove("bg-primary/20", "bg-primary/50");
    if (this.isFocused) {
      this.gutterTarget.classList.add("bg-primary/50");
    } else if (this.isHovered) {
      this.gutterTarget.classList.add("bg-primary/20");
    }

    // Toolbar visibility - subclasses may override this behavior
    if (this.hasToolbarTarget) {
      const showToolbar = this.isHovered || this.isFocused;
      this.toolbarTarget.classList.toggle("opacity-0", !showToolbar);
      this.toolbarTarget.classList.toggle("pointer-events-none", !showToolbar);
      this.toolbarTarget.classList.toggle("opacity-100", showToolbar);
      this.toolbarTarget.classList.toggle("pointer-events-auto", showToolbar);
    }
  }

  // Placeholder actions for cell reordering/deletion
  moveUp() {
    this.reorder(-1)
  }
  moveDown() {
    this.reorder(1)
  }
  delete() {
    const cellContainer = this.element.closest(
      '[data-controller="ruby-cell"], [data-controller="markdown-cell"]',
    ) as HTMLElement | null;
    if (!cellContainer) return;

    const modalEl = document.getElementById("delete-cell-modal");
    const modalController =
      modalEl &&
      (this.application.getControllerForElementAndIdentifier(
        modalEl,
        "delete-cell-modal",
      ) as any);

    if (modalController?.open) {
      modalController.open(() => {
        this.removeCell(cellContainer);
      });
    } else {
      this.removeCell(cellContainer);
    }
  }

  private removeCell(container: HTMLElement) {
    container.remove();
    this.dispatchCellChanged();
  }

  private reorder(offset: number) {
    const container = this.element.closest(
      '[data-controller="ruby-cell"], [data-controller="markdown-cell"]',
    ) as HTMLElement | null
    if (!container) return

    const list = container.closest('[data-cells-target="list"]') as HTMLElement | null
    if (!list) return

    const items = Array.from(list.children)
    const currentIndex = items.indexOf(container)
    if (currentIndex === -1) return

    const firstHeaderIndex = items.findIndex((el) =>
      el.querySelector('[data-controller="inline-heading"]'),
    )

    const targetIndex = currentIndex + offset

    // Boundary checks
    if (targetIndex < 0 || targetIndex >= items.length) return

    // Do not move anything above the first section header (if present)
    if (firstHeaderIndex !== -1 && targetIndex < firstHeaderIndex) return

    const targetItem = items[targetIndex]
    if (!targetItem || targetItem === container) return

    if (offset < 0) {
      list.insertBefore(container, targetItem)
    } else {
      list.insertBefore(container, targetItem.nextSibling)
    }

    this.dispatchCellChanged()
  }
}
