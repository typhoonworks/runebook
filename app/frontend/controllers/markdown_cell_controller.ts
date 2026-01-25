import * as monaco from "monaco-editor/esm/vs/editor/editor.api";
import BaseEditorController from "./base_editor_controller";

export default class extends BaseEditorController {
  static targets = [
    "editor",
    "editorWrapper",
    "preview",
    "toolbar",
    "gutter",
  ] as const;
  static values = { previewUrl: String };

  declare readonly previewUrlValue: string;
  declare readonly hasPreviewUrlValue: boolean;
  declare readonly editorTarget: HTMLDivElement;
  declare readonly previewTarget: HTMLDivElement;
  declare readonly editorWrapperTarget: HTMLDivElement;
  declare readonly toolbarTarget: HTMLDivElement;
  declare readonly gutterTarget: HTMLDivElement;
  declare readonly hasToolbarTarget: boolean;

  private unsubscribe?: monaco.IDisposable;
  private debounced?: number;
  private editing = false;

  connect() {
    this.setupCellActivation();

    this.editor = monaco.editor.create(this.editorTarget, {
      value: this.initialContent(),
      language: "markdown",
      theme: "vs-dark",
      ...BaseEditorController.baseEditorOptions,
    });

    this.setupAutoGrow();

    this.unsubscribe = this.editor.onDidChangeModelContent(() => {
      this.queueRender();
    });

    this.editor.onDidBlurEditorText(() => {
      if (this.editing) this.stopEditing();
    });
    this.editor.onKeyDown((e) => {
      if (e.keyCode === monaco.KeyCode.Escape) {
        this.stopEditing();
      }
    });

    this.setupHoverTracking();

    // Initial render
    this.queueRender();
    this.stopEditing(); // start in preview mode
    this.updateVisibility();
  }

  disconnect() {
    this.unsubscribe?.dispose();
    this.editor?.dispose();
    this.teardownCellActivation();
  }

  private initialContent(): string {
    const fromAttr = this.editorTarget.dataset.content;
    if (fromAttr !== undefined) return fromAttr;
    const node = this.editorTarget.querySelector('[data-content]');
    if (node) return (node.textContent || "").trimEnd();
    return "";
  }

  private queueRender() {
    if (this.debounced) window.clearTimeout(this.debounced);
    this.debounced = window.setTimeout(() => this.renderPreview(), 200);
  }

  private currentText(): string {
    return this.editor?.getValue() || "";
  }

  private async renderPreview() {
    const text = this.currentText();

    const url = this.hasPreviewUrlValue
      ? this.previewUrlValue
      : "/markdown/preview";
    try {
      const resp = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken(),
          Accept: "text/html",
        },
        body: JSON.stringify({ text }),
      });
      const html = (await resp.text()).trim();
      if (html.length === 0) {
        this.previewTarget.innerHTML =
          '<div class="text-base-content/40 select-none">Empty markdown cell</div>';
      } else {
        this.previewTarget.innerHTML = html;
      }
    } catch (_e) {
      // Keep failure silent to avoid interrupting typing
    }
  }

  startEditing() {
    this.setFocused(true);
    this.activateCell("markdown-cell:activate");
    this.editing = true;
    this.editorWrapperTarget.classList.remove("hidden");
    this.editor?.focus();
  }

  stopEditing() {
    this.editing = false;
    this.editorWrapperTarget.classList.add("hidden");
  }

  activate() {
    this.activateCell("markdown-cell:activate");
  }
}
