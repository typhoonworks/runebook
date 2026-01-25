import * as monaco from "monaco-editor/esm/vs/editor/editor.api";
import {
  subscribeToSession,
  type SessionOutputMessage,
} from "../channels/session_channel";
import BaseEditorController from "./base_editor_controller";

export default class extends BaseEditorController {
  static targets = [
    "editor",
    "editorWrapper",
    "output",
    "statusPill",
    "statusDot",
    "statusText",
    "evaluateButton",
    "evaluateText",
    "primaryActions",
    "gutter",
    "toolbar",
  ] as const;
  static values = { evaluateUrl: String };

  declare readonly editorTarget: HTMLDivElement;
  declare readonly editorWrapperTarget: HTMLDivElement;
  declare readonly outputTarget: HTMLDivElement;
  declare readonly evaluateUrlValue: string;
  declare readonly hasEvaluateUrlValue: boolean;

  declare readonly statusPillTarget: HTMLDivElement;
  declare readonly statusDotTarget: HTMLSpanElement;
  declare readonly statusTextTarget: HTMLSpanElement;
  declare readonly evaluateButtonTarget: HTMLButtonElement;
  declare readonly evaluateTextTarget: HTMLSpanElement;
  declare readonly hasEvaluateTextTarget: boolean;
  declare readonly primaryActionsTarget: HTMLDivElement;
  declare readonly hasPrimaryActionsTarget: boolean;
  declare readonly gutterTarget: HTMLDivElement;
  declare readonly toolbarTarget: HTMLDivElement;
  declare readonly hasToolbarTarget: boolean;

  private unsubscribeFromSession?: () => void;
  private cellRef?: string;
  private isEvaluating: boolean = false;

  connect() {
    this.editor = monaco.editor.create(this.editorTarget, {
      value: this.initialContent(),
      language: "ruby",
      theme: "vs-dark",
      ...BaseEditorController.baseEditorOptions,
      // Ruby-specific options
      autoIndent: "advanced",
      tabSize: 2,
      insertSpaces: true,
      detectIndentation: false,
      trimAutoWhitespace: true,
    });

    this.setupAutoGrow();

    this.editor.onKeyDown((e) => {
      if (e.shiftKey && e.keyCode === monaco.KeyCode.Enter) {
        e.preventDefault();
        this.evaluate();
      }
    });

    this.setupCellActivation();
    this.editor.onDidFocusEditorText(() => {
      this.activate();
    });

    this.setupHoverTracking();
    this.updateVisibility();

    // Subscribe to session channel for streaming outputs
    this.subscribeToSessionChannel();
  }

  disconnect() {
    this.editor?.dispose();
    this.teardownCellActivation();
    this.unsubscribeFromSession?.();
  }

  private subscribeToSessionChannel() {
    const sessionToken = this.getSessionToken();
    if (!sessionToken) return;

    this.unsubscribeFromSession = subscribeToSession(sessionToken, {
      onOutput: (message: SessionOutputMessage) => {
        // Only handle output for this cell
        if (message.cell_ref !== this.cellRef) return;
        if (!this.isEvaluating) return;

        const v = this.outputTarget.querySelector(
          '[data-controller="virtualized-lines"]',
        ) as HTMLElement | null;
        if (!v) return;
        const append = (text: string) =>
          v.dispatchEvent(
            new CustomEvent("virtualized-lines:append", { detail: { text } }),
          );
        if (message.stdout) append(message.stdout);
        if (message.stderr) append(`error: ${message.stderr}`);
      },
      onConnected: () => {
        console.log(`[RubyCell] Connected to session channel`);
      },
      onDisconnected: () => {
        console.log(`[RubyCell] Disconnected from session channel`);
      },
    });
  }

  private initialContent(): string {
    const fromAttr = this.editorTarget.dataset.content;
    if (fromAttr !== undefined) return fromAttr;
    const node = this.editorTarget.querySelector('[data-content]');
    if (node) return (node.textContent || "").trimEnd();
    return "";
  }

  async evaluate() {
    const code = this.editor?.getValue() || "";
    const url = this.hasEvaluateUrlValue
      ? this.evaluateUrlValue
      : "/ruby/evaluate";
    const sessionToken = this.getSessionToken();
    const cellType = this.element.dataset.cellType || "code";

    // Generate unique cell reference for this evaluation
    this.cellRef =
      Math.random().toString(36).slice(2) + Date.now().toString(36);
    this.isEvaluating = true;

    this.outputTarget.innerHTML = `
      <div class="cell-output-region">
        <div class="cell-output-row cell-output-stdout">
          <div data-controller="virtualized-lines" data-virtualized-lines-follow-value="true" data-virtualized-lines-max-height-value="300" data-virtualized-lines-max-lines-value="1000" class="overflow-auto whitespace-pre-wrap font-mono text-sm text-base-content/80 tiny-scrollbar max-h-80" style="width: 100%; position: relative;">
            <div data-virtualized-lines-target="content" style="position: relative;"></div>
          </div>
        </div>
      </div>
    `;
    try {
      const resp = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken(),
          Accept: "application/json",
        },
        credentials: "same-origin",
        body: JSON.stringify({
          code,
          session_token: sessionToken,
          cell_type: cellType,
          cell_ref: this.cellRef,
        }),
      });

      let data: any;
      const ct = resp.headers.get("content-type") || "";

      if (ct.includes("application/json")) {
        data = await resp.json();
      } else {
        // Fallback: try to parse as text and show it
        const text = await resp.text();
        try {
          data = JSON.parse(text);
        } catch {
          const msg =
            text && text.trim().length > 0
              ? text
              : `HTTP ${resp.status} ${resp.statusText} — Failed to evaluate code`;
          this.outputTarget.innerHTML = `<div class="text-error">${this.escapeHtml(msg)}</div>`;
          this.updateStatus(false);
          this.isEvaluating = false;
          return;
        }
      }

      // Final output replaces streaming output
      this.outputTarget.innerHTML = data.html;
      this.updateStatus(Boolean(data.ok));
      this.setButtonsToReevaluate();
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Failed to evaluate code";
      this.outputTarget.innerHTML = `<div class="text-error">${this.escapeHtml(msg)}</div>`;
      this.updateStatus(false);
      this.setButtonsToReevaluate();
    } finally {
      this.isEvaluating = false;
    }
  }

  private updateStatus(ok: boolean) {
    this.statusPillTarget.classList.remove("hidden");
    this.statusTextTarget.textContent = "Evaluated";
    this.statusDotTarget.classList.remove(
      "bg-success",
      "bg-error",
      "bg-base-300",
    );
    this.statusDotTarget.classList.add(ok ? "bg-success" : "bg-error");
  }

  private setButtonsToReevaluate() {
    if (this.hasEvaluateTextTarget) {
      this.evaluateTextTarget.textContent = "Reevaluate";
    }
  }

  private getSessionToken(): string {
    const sessionEl = document.querySelector("[data-session-token]");
    return sessionEl?.getAttribute("data-session-token") || "";
  }

  private escapeHtml(s: string) {
    return s.replace(
      /[&<>"]/g,
      (c) =>
        ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[
          c
        ] as string,
    );
  }

  protected updateVisibility() {
    super.updateVisibility();

    const showPrimary = this.isHovered || this.isFocused;
    if (this.hasPrimaryActionsTarget) {
      this.primaryActionsTarget.classList.toggle("opacity-0", !showPrimary);
      this.primaryActionsTarget.classList.toggle("opacity-100", showPrimary);
    }

    if (this.hasToolbarTarget) {
      this.toolbarTarget.classList.toggle("opacity-0", !this.isFocused);
      this.toolbarTarget.classList.toggle(
        "pointer-events-none",
        !this.isFocused,
      );
      this.toolbarTarget.classList.toggle("opacity-100", this.isFocused);
      this.toolbarTarget.classList.toggle(
        "pointer-events-auto",
        this.isFocused,
      );
    }
  }

  activate() {
    this.activateCell("ruby-cell:activate");
  }
}
