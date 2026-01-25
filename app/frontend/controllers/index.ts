import { Application } from "@hotwired/stimulus";

const application = Application.start();

export { application };

// Register controllers explicitly for now
import ThemeController from "./theme_controller";
application.register("theme", ThemeController);
import DocumentTitleController from "./document_title_controller";
application.register("document-title", DocumentTitleController);
import MarkdownCellController from "./markdown_cell_controller";
application.register("markdown-cell", MarkdownCellController);
import InlineHeadingController from "./inline_heading_controller";
application.register("inline-heading", InlineHeadingController);
import CellsController from "./cells_controller";
application.register("cells", CellsController);
import RubyCellController from "./ruby_cell_controller";
application.register("ruby-cell", RubyCellController);
import VirtualizedLinesController from "./virtualized_lines_controller";
application.register("virtualized-lines", VirtualizedLinesController);
import ClipboardController from "./clipboard_controller";
application.register("clipboard", ClipboardController);
import NotebookController from "./notebook_controller";
application.register("notebook", NotebookController);
import SaveModalController from "./save_modal_controller";
application.register("save-modal", SaveModalController);
import CloseSessionModalController from "./close_session_modal_controller";
application.register("close-session-modal", CloseSessionModalController);
import SessionActionsController from "./session_actions_controller";
application.register("session-actions", SessionActionsController);
import ExportModalController from "./export_modal_controller";
application.register("export-modal", ExportModalController);
import FileBrowserController from "./file_browser_controller";
application.register("file-browser", FileBrowserController);
import TabsController from "./tabs_controller";
application.register("tabs", TabsController);
import SourceImportController from "./source_import_controller";
application.register("source-import", SourceImportController);
import DeleteCellModalController from "./delete_cell_modal_controller";
application.register("delete-cell-modal", DeleteCellModalController);
