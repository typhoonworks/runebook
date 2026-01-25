import { Controller } from "@hotwired/stimulus";

// A lightweight virtualized lines viewer for large, streaming outputs.
// Root element is the scroll container; it should have monospaced styles.
// Provide a child with `data-virtualized-lines-target="content"`.
// Supports appending text via custom events:
//   el.dispatchEvent(new CustomEvent('virtualized-lines:append', { detail: { text } }))

export default class extends Controller<HTMLDivElement> {
  static targets = ["content"] as const;
  static values = {
    initialText: String,
    maxHeight: { type: Number, default: 300 },
    maxLines: { type: Number, default: 1000 },
    follow: { type: Boolean, default: true },
    ignoreTrailingEmptyLine: { type: Boolean, default: true },
  };

  declare readonly contentTarget: HTMLDivElement;
  declare readonly hasInitialTextValue: boolean;
  declare initialTextValue: string;
  declare maxHeightValue: number;
  declare maxLinesValue: number;
  declare followValue: boolean;
  declare ignoreTrailingEmptyLineValue: boolean;

  private lines: string[] = [];
  private buffer: string = "";
  private lineHeight = 20; // will be measured on first render
  private onScroll = () => this.render();
  private onResize = () => this.render();

  connect() {
    // Ensure scroll container constraints
    this.element.style.maxHeight = `${this.maxHeightValue}px`;
    this.element.style.position = this.element.style.position || "relative";
    this.element.style.overflow = this.element.style.overflow || "auto";

    // Listen for append events
    this.element.addEventListener(
      "virtualized-lines:append",
      this.appendEvent as any,
    );

    // Initialize from initial text
    if (this.hasInitialTextValue && this.initialTextValue) {
      this.appendText(this.initialTextValue);
    } else {
      this.render();
    }

    this.element.addEventListener("scroll", this.onScroll);
    window.addEventListener("resize", this.onResize);
  }

  disconnect() {
    this.element.removeEventListener(
      "virtualized-lines:append",
      this.appendEvent as any,
    );
    this.element.removeEventListener("scroll", this.onScroll);
    window.removeEventListener("resize", this.onResize);
  }

  private appendEvent = (e: CustomEvent<{ text: string }>) => {
    if (!e.detail || typeof e.detail.text !== "string") return;
    const nearBottom = this.isNearBottom();
    this.appendText(e.detail.text);
    if (this.followValue && nearBottom) this.scrollToBottom();
  };

  // Public API (can be called via getControllerForElementAndIdentifier)
  append(text: string) {
    const nearBottom = this.isNearBottom();
    this.appendText(text);
    if (this.followValue && nearBottom) this.scrollToBottom();
  }

  private appendText(text: string) {
    if (!text) return;
    this.buffer += text;
    const parts = this.buffer.split(/\r?\n/);
    // Keep the last partial line in buffer
    this.buffer = parts.pop() || "";
    for (const line of parts) this.lines.push(line);

    // Optionally drop a trailing empty line
    if (this.ignoreTrailingEmptyLineValue && this.buffer === "") {
      // Do nothing; the empty trailing segment stays buffered
    }

    // Enforce max lines
    if (this.lines.length > this.maxLinesValue) {
      this.lines.splice(0, this.lines.length - this.maxLinesValue);
    }
    this.render();
  }

  private measureLineHeight() {
    if (this.lineHeightMeasured()) return;
    const probe = document.createElement("div");
    probe.textContent = "A";
    probe.style.visibility = "hidden";
    probe.style.position = "absolute";
    probe.style.whiteSpace = "pre";
    probe.style.font = getComputedStyle(this.element).font;
    this.contentTarget.appendChild(probe);
    this.lineHeight = probe.getBoundingClientRect().height || 20;
    this.contentTarget.removeChild(probe);
  }

  private lineHeightMeasured() {
    return this.lineHeight && this.lineHeight > 0;
  }

  private render() {
    this.measureLineHeight();
    const total = this.lines.length + (this.buffer ? 1 : 0);
    const scrollTop = this.element.scrollTop;
    const viewport = this.element.clientHeight;
    const start = Math.max(0, Math.floor(scrollTop / this.lineHeight) - 2);
    const count = Math.ceil(viewport / this.lineHeight) + 6;
    const end = Math.min(total, start + count);

    // Prepare container height
    this.contentTarget.style.position = "relative";
    this.contentTarget.style.height = `${total * this.lineHeight}px`;

    // Build visible rows
    const frag = document.createDocumentFragment();
    const makeRow = (text: string, idx: number) => {
      const row = document.createElement("div");
      row.className = "vrow";
      row.style.position = "absolute";
      row.style.top = `${idx * this.lineHeight}px`;
      row.textContent = text;
      return row;
    };

    for (let i = start; i < end; i++) {
      if (i < this.lines.length) {
        frag.appendChild(makeRow(this.lines[i], i));
      } else if (i === this.lines.length && this.buffer) {
        frag.appendChild(makeRow(this.buffer, i));
      }
    }

    // Replace content
    this.contentTarget.replaceChildren(frag);
  }

  private isNearBottom(): boolean {
    const epsilon = this.lineHeight * 2;
    return (
      this.element.scrollTop + this.element.clientHeight >=
      this.element.scrollHeight - epsilon
    );
  }

  private scrollToBottom() {
    this.element.scrollTop = this.element.scrollHeight;
  }
}
