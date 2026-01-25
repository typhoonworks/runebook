// Runemd serializer for converting notebook cells to .runemd format
// This is used by the frontend to serialize notebook content for saving

export interface Cell {
  type: "setup" | "ruby" | "markdown";
  content: string;
}

export interface Section {
  title: string;
  cells: Cell[];
}

export interface NotebookData {
  version: number;
  autosave_interval: number;
  title: string;
  setup_cell: Cell | null;
  sections: Section[];
}

/**
 * Serialize notebook cells to the format expected by the save API
 *
 * @param title - The notebook title
 * @param setupCell - The setup cell content (or null if none)
 * @param sections - Array of sections with their cells
 * @returns Object ready to be sent to the save API
 */
export function serializeNotebook(
  title: string,
  setupCell: string | null,
  sections: Section[],
): {
  title: string;
  setup_cell: { type: string; content: string } | null;
  sections: Array<{
    title: string;
    cells: Array<{ type: string; content: string }>;
  }>;
} {
  return {
    title,
    setup_cell: setupCell ? { type: "setup", content: setupCell } : null,
    sections: sections.map((section) => ({
      title: section.title,
      cells: section.cells.map((cell) => ({
        type: cell.type,
        content: cell.content,
      })),
    })),
  };
}

/**
 * Collect all cells from the DOM in order
 *
 * @param container - The container element holding all cells
 * @returns Object with setupCell content and array of sections
 */
export function collectCellsFromDOM(container: HTMLElement): {
  setupCell: string | null;
  sections: Section[];
} {
  // Collect setup cell - both attributes are on the same element (no space in selector)
  const setupElement = container.querySelector(
    '[data-cell-type="setup"][data-controller="ruby-cell"]',
  );
  let setupCell: string | null = null;
  if (setupElement) {
    // Use the proper Stimulus API to get the controller
    const stimulusApp = (window as unknown as { Stimulus?: { getControllerForElementAndIdentifier: (el: HTMLElement, id: string) => { editor?: { getValue: () => string } } } }).Stimulus;
    if (stimulusApp) {
      const controller = stimulusApp.getControllerForElementAndIdentifier(setupElement as HTMLElement, "ruby-cell");
      if (controller?.editor) {
        setupCell = controller.editor.getValue();
      }
    }
    // Fallback: try to get content from data attribute
    if (setupCell === null) {
      const editorEl = setupElement.querySelector("[data-content]");
      if (editorEl) {
        setupCell = editorEl.getAttribute("data-content") || null;
      }
    }
  }

  // Collect sections and cells
  const sections: Section[] = [];
  let currentSection: Section = { title: "Section", cells: [] };

  // Find all cell elements in order (within the list target)
  const cellList = container.querySelector('[data-cells-target="list"]');
  if (!cellList) {
    return { setupCell, sections: [currentSection] };
  }

  const elements = cellList.querySelectorAll(
    '[data-controller="ruby-cell"], [data-controller="markdown-cell"], [data-controller="inline-heading"]',
  );

  elements.forEach((el) => {
    const controller = el.getAttribute("data-controller");

    if (controller === "inline-heading") {
      // Section header - start a new section if current one has cells
      if (currentSection.cells.length > 0) {
        sections.push(currentSection);
      }
      const headingEl = el.querySelector("h2");
      const title = headingEl?.textContent?.trim() || "Section";
      currentSection = { title, cells: [] };
    } else if (controller === "ruby-cell") {
      // Ruby cell - get content from Monaco editor instance
      const content = getCellContent(el as HTMLElement, "ruby");
      currentSection.cells.push({ type: "ruby", content });
    } else if (controller === "markdown-cell") {
      // Markdown cell - get content from Monaco editor instance
      const content = getCellContent(el as HTMLElement, "markdown");
      currentSection.cells.push({ type: "markdown", content });
    }
  });

  // Add the last section
  sections.push(currentSection);

  return { setupCell, sections };
}

/**
 * Get the content from a cell's Monaco editor
 */
function getCellContent(element: HTMLElement, type: string): string {
  // Try to access the Stimulus controller's editor instance
  const stimulusApp = (window as unknown as { Stimulus?: { getControllerForElementAndIdentifier: (el: HTMLElement, id: string) => { editor?: { getValue: () => string } } } }).Stimulus;

  if (stimulusApp) {
    const controllerName = type === "ruby" ? "ruby-cell" : "markdown-cell";
    const controller = stimulusApp.getControllerForElementAndIdentifier(element, controllerName);
    if (controller?.editor) {
      return controller.editor.getValue();
    }
  }

  // Fallback: try to get content from data attribute
  const editorEl = element.querySelector("[data-content]");
  if (editorEl) {
    return editorEl.getAttribute("data-content") || "";
  }

  return "";
}

/**
 * Export notebook to Runebook Markdown format
 *
 * @param title - The notebook title
 * @param setupCell - The setup cell content (or null if none)
 * @param sections - Array of sections with their cells
 * @returns String in .runemd format
 */
export function exportToRunemd(
  title: string,
  setupCell: string | null,
  sections: Section[],
): string {
  const lines: string[] = [];

  // Title
  lines.push(`# ${title}`);
  lines.push("");

  // Setup cell
  if (setupCell && setupCell.trim()) {
    lines.push("```ruby");
    lines.push(setupCell);
    lines.push("```");
    lines.push("");
  }

  // Sections
  for (const section of sections) {
    lines.push(`## ${section.title}`);
    lines.push("");

    for (const cell of section.cells) {
      if (cell.type === "ruby") {
        lines.push("```ruby");
        lines.push(cell.content);
        lines.push("```");
      } else if (cell.type === "markdown") {
        lines.push(cell.content);
      }
      lines.push("");
    }
  }

  return lines.join("\n").trim() + "\n";
}

/**
 * Export notebook to IRB-compatible Ruby format
 *
 * @param title - The notebook title
 * @param setupCell - The setup cell content (or null if none)
 * @param sections - Array of sections with their cells
 * @returns String in .rb format suitable for IRB
 */
export function exportToIrb(
  title: string,
  setupCell: string | null,
  sections: Section[],
): string {
  const lines: string[] = [];

  // Header comment
  lines.push(`# Run as: irb -r ./notebook.rb`);
  lines.push(`#`);
  lines.push(`# Title: ${title}`);
  lines.push("");

  // Setup cell
  if (setupCell && setupCell.trim()) {
    lines.push("# --- Setup ---");
    lines.push(setupCell);
    lines.push("");
  }

  // Sections
  for (const section of sections) {
    lines.push(`# --- ${section.title} ---`);
    lines.push("");

    for (const cell of section.cells) {
      if (cell.type === "ruby") {
        lines.push(cell.content);
        lines.push("");
      } else if (cell.type === "markdown" && cell.content.trim()) {
        // Convert markdown to Ruby comments
        const commentLines = cell.content
          .split("\n")
          .map((line) => `# ${line}`)
          .join("\n");
        lines.push(commentLines);
        lines.push("");
      }
    }
  }

  return lines.join("\n").trim() + "\n";
}

export default {
  serializeNotebook,
  collectCellsFromDOM,
  exportToRunemd,
  exportToIrb,
};
