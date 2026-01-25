# Runebook — AGENTS Guidelines

Scope: Applies to all code in this `runebook` Rails app. Follow these defaults unless there is a clear local reason to deviate. Keep things simple, Basecamp‑style: server‑rendered HTML, small Stimulus controllers, rich Active Record models. This file tailors the Basecamp playbook to Runebook’s purpose and stack.

## Purpose
- Runebook is a Livebook‑like, local‑first Ruby notebook.
- Primary goals: edit `.runemd` files, run Ruby cells with streaming output, and share results — fast, clear, minimal dependencies.
- Trust model: local/trusted code. Provide process isolation, cancel/timeout. No OS/container sandbox guarantees by default.

## Defaults (Runebook Stack)
- Rails 8 + Hotwire (`turbo-rails`, Stimulus).
- Vite (via `vite_ruby`) for JS/CSS bundling — no Importmap.
- Editor: Monaco (Vite plugin), Ruby basic language; optional LSP later.
- CSS: Tailwind + DaisyUI + `@tailwindcss/forms` + `@tailwindcss/typography`.
- DB: SQLite in dev/test; keep it unless production needs PostgreSQL.
- Jobs: `solid_queue` (DB‑backed). Switch only with a concrete need.
- Storage: ActiveStorage (local disk in dev).

## Where We Deviate from Basecamp Patterns
- We use Vite instead of Importmap to support Monaco and TypeScript.
- We avoid ViewComponent; prefer partials/helpers (Basecamp style).
- We ship a small in‑process execution harness for Ruby cells.

## High‑Level Architecture
- Notebook (AR): file_path, title, format (`runemd`), version, dirty flag.
- Notebook (PORO): parsed `.runemd` (sections, cells).
- Session (AR): runtime state per open notebook (status, pid, started_at).
- Execution: forked Ruby subprocess per run/session, streaming stdout/stderr via ActionCable; hard timeouts; rlimits.
- Source of truth for content: `.runemd` files on disk.

## Conventions
- Models own domain logic. Prefer small, intention‑revealing APIs.
- Use concerns under model namespaces (e.g., `Notebook::Parsable`).
- Controllers are thin: load state + call model APIs; `respond_to :html, :turbo_stream`.
- Routes as REST resources; use the “action‑as‑resource” pattern when needed.
- Views are ERB partials optimized for reuse by Turbo Streams.
- Stimulus controllers are tiny, single‑purpose; colocate under `app/frontend/controllers`.
- Keep Ruby and JS files short and readable; prefer clarity over cleverness.

## Frontend (Vite)
- Entry: `app/frontend/entrypoints/application.(ts|js)` loads Turbo, Stimulus, styles.
- Stimulus: generate controllers in `app/frontend/controllers`; auto‑register.
- Monaco: import via `vite-plugin-monaco-editor`; lazy‑load editor code on pages that need it.
- CSP: allow `worker-src 'self'`; avoid `unsafe-eval` in production.

## Styling
- Utility‑first Tailwind. DaisyUI for themes and basic components.
- Use typography plugin only for rendered Markdown/output regions (`.prose`).
- Prefer semantic HTML with minimal custom classes; extract repeated utility sets into small CSS layers with `@apply` sparingly.

## Execution & Security
- Forked subprocess for cell runs; SIGTERM → SIGKILL on cancel/timeout.
- Apply `rlimit` for CPU/file descriptors; consider memory cap if feasible.
- Per‑session temp working directory; explicitly opt‑in mounts for data files.
- Secrets via Rails credentials/ENV; never write secrets into `.runemd`.

## Persistence
- Save and read `.runemd` files atomically (temp file + rename).
- DB stores notebook metadata and session/runtime info, not the source of truth.

## Realtime
- Use Turbo Frames per cell and Turbo Streams for status/log/result updates.
- Broadcast from jobs or models; partials must support both initial render and stream updates.

## Testing
- Minitest with fixtures. Keep tests fast, deterministic, parallel where stable.
- System tests for critical flows: open notebook, edit cell, run cell, stream updates.

## Do / Don’t
- Do keep controllers and Stimulus small and intention‑revealing.
- Do favor ERB partials and helpers over component frameworks.
- Don’t introduce service layers or complex DI without a concrete payoff.
- Don’t promise strong OS/container sandboxing; offer it later as optional.

## Notes for Agents
- Follow these conventions for all changes in this app’s directory tree.
- If you deviate, add a short rationale to this file or the PR description.
