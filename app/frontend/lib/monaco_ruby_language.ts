import * as monaco from "monaco-editor/esm/vs/editor/editor.api";

let configured = false;

export function ensureRubyLanguageConfigured() {
  if (configured) return;
  configured = true;

  // Basic indentation and on-enter rules for Ruby blocks.
  // Keep it conservative: no auto-insert of `end`.
  const blockOpen =
    /^(\s*)(?:class|module|def|if|unless|case|while|until|for|begin|do)\b.*$/;
  const blockMiddle = /^(\s*)(?:else|elsif|when|rescue|ensure)\b.*$/;
  const blockClose = /^(\s*)(?:end)\b.*$/;

  monaco.languages.setLanguageConfiguration("ruby", {
    indentationRules: {
      // Increase after openers (class/def/if/...) and middle keywords (else/elsif/when/rescue/ensure)
      increaseIndentPattern: new RegExp(
        [blockOpen.source, blockMiddle.source].map((s) => `(?:${s})`).join("|"),
      ),
      // Decrease on closers
      decreaseIndentPattern: blockClose,
      // Don't change indent for pure comment lines
      unIndentedLinePattern: /^\s*#.*$/,
    },
    onEnterRules: [
      // For middle keywords (else/elsif/when/rescue/ensure), outdent the keyword itself
      // to align with its matching opener, and indent the following line.
      {
        beforeText: blockMiddle,
        action: { indentAction: monaco.languages.IndentAction.IndentOutdent },
      },
      // If the current line is just 'end', outdent the next line (common flow)
      {
        beforeText: blockClose,
        action: { indentAction: monaco.languages.IndentAction.Outdent },
      },
    ],
    autoClosingPairs: [
      { open: "(", close: ")" },
      { open: "[", close: "]" },
      { open: "{", close: "}" },
      { open: '"', close: '"' },
      { open: "'", close: "'" },
    ],
    surroundingPairs: [
      { open: "(", close: ")" },
      { open: "[", close: "]" },
      { open: "{", close: "}" },
      { open: '"', close: '"' },
      { open: "'", close: "'" },
      { open: "`", close: "`" },
    ],
  });
}
