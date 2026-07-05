# Project
Hermes Agent — a self-improving AI agent (creates skills from experience, improves them during use, runs anywhere) with a flexible tool-calling/toolsets system and chat-platform gateways. It is NOT a hosted SaaS, a web framework, or a model — it is the agent runtime + CLI you install and run yourself.

# Stack
- Language: Python 3.11–3.13 (`requires-python = ">=3.11,<3.14"`), packaged with setuptools + uv (`uv.lock`).
- Core libs: openai SDK, fire (CLI), httpx, rich, pydantic, prompt_toolkit, jinja2, croniter, pyyaml/ruamel.yaml.
- Node side: npm workspaces (`web`, `ui-tui`, `apps/desktop`), Node ≥20, `agent-browser`. Use **npm** (the committed `package-lock.json`); untracked `web/pnpm-*.yaml` are not yet the adopted standard — confirm before switching package managers.
- Dev tooling: pytest (per-file isolation), ruff (PLW1514 only), ty (typecheck), Docker, Nix flake.

# Commands
- build: `uv build` (wheel/sdist via setuptools; no compile step). Python package, not a native app.
- test: `scripts/run_tests.sh` — canonical, per-file-isolated; never call `pytest` directly. CI mirror: `python scripts/run_tests_parallel.py --slice N/6`. Full suite is slow.
- lint: `ruff check .` (only PLW1514 enabled) + typecheck `ty check`.
- dev: `python run_agent.py --help`, or the installed CLI `./hermes` (→ `hermes_cli.main:main`; subcommands `gateway`, `cron`, `doctor`).
- install: `./setup-hermes.sh` (full env); Node workspaces via `npm run install:web` / `install:tui` / `install:desktop`.
- release: PyPI (`.github/workflows/upload_to_pypi.yml`), Docker (`docker-publish.yml`), site (`deploy-site.yml`), Windows installer (`build-windows-installer.yml`).

# Structure
- `agent/` — agent core (chat-completion dispatch, loop helpers). `run_agent.py`, `cli.py`, `hermes_state.py` — top-level runtime modules.
- `hermes_cli/` — installed `hermes` CLI (subcommands, doctor, gateway, cron). `acp_adapter/`, `acp_registry/` — Agent Client Protocol.
- `tools/` — individual agent tools; `toolsets.py` / `toolset_distributions.py` group and distribute them.
- `gateway/` — chat-platform gateways (Matrix, Telegram, Teams, …) under `gateway/platforms/`.
- `skills/` + `optional-skills/` — shipped self-improving skills; `plugins/` — plugin packs; `providers/` — model provider backends.
- `cron/` — built-in scheduler jobs. `tests/` — pytest suite (run via `scripts/run_tests.sh`). `scripts/` — dev/CI scripts.
- `web/`, `ui-tui/`, `apps/` — Node workspaces. `docs/`, `website/` — docs site. `locales/` — i18n catalogs.

# Git workflow
Default/integration branch: **main** (repo default / `origin` HEAD; `origin` = NousResearch, `fork` = marcosvasili-coder).

- **Integration branch:** **main** — merge finished work here; keep it shippable.
- **Feature branches:** short-lived, one purpose each; clear names (`feat/…`, `fix/…`); delete after merge.
- **After merge:** `git checkout main` && `git pull`, then delete the finished feature branch (local + remote tracking when applicable).
- **Sync:** prefer `git pull --rebase` on a feature branch before opening or updating a PR (optional: `git config pull.rebase true`).
- **Agents / automation:** do not leave the checkout on incidental `cursor/…` or unnamed branches without intent; return to **main** when a task is complete unless deliberately continuing feature work.
- **Cursor parity:** the same policy lives in `.cursor/rules/git-workflow.mdc` (already names `main`) — keep the integration branch name consistent if you edit either file.

<!-- setup-ai-context-git-workflow v1 -->

# Agent surfaces (Cursor, Claude, Codex, iTerm)

Keep wording aligned with `.cursor/rules/cursor-agent-cli-workflow.mdc` and `~/.claude/CLAUDE.md`.

- **Cursor Agents:** IDE-tight work, MCP/browser, short steering cycles, UI iteration.
- **Claude Code CLI:** long batch passes, wide refactors, long shell/git/test chains.
- **Codex CLI:** read-only `codex review` — paste approve/changes-needed back to Cursor; Codex does not commit.
- **iTerm (human):** runner singleton checks, install smoke, manual `gh` — not an autonomous driver.
- **Start non-trivial work with:** (1) surface + why, (2) one write driver (Cursor vs `claude`), (3) constraints (branch, must-not-touch, verify command), (4) optional Codex review scope, (5) HANDOFF if switching to Claude.
- **One driver per branch:** never run Cursor Agent and Claude Code on the same task pass; clean `git status` or a commit before switching.
- **Claude Code subagents:** use for scoped delegation inside the CLI; do not split write ownership without a handoff summary.
- **Subscriptions:** Claude Max vs Cursor billing are separate; do not assume `ANTHROPIC_API_KEY` for subscription auth.

<!-- setup-ai-context-agent-surfaces v1 -->

# Rules
- Never edit: `.env` / `*.env` (use `.env.example`), `cli-config.yaml` (use `cli-config.yaml.example`), lockfiles (`uv.lock`, `package-lock.json`, `flake.lock` — regenerate, don't hand-edit), generated `hermes_agent.egg-info/`, runtime state (`.hermes/`, `.hermes-bootstrap-complete`), and any credential/keystore (`.credentials*`, `*.p12`, `*.mobileprovision`).
- **Always run `scripts/run_tests.sh` before committing** — never `pytest` directly (CI parity, credential isolation, hermetic per-file subprocesses; see AGENTS.md Testing).
- **Code review gate:** every non-trivial change passes a strict pre-commit review (Codex-style) before commit. Route through `/code-review`, resolve all HOLDs first. Enforce all-or-nothing per-row gating on imports + atomic transactions on the first pass, not as a retrofit.
- **Response style:** keep responses concise. Split long output (diffs, logs, plans) across messages and pause for "continue" — never dump a wall of output.
- **Git push:** may run when the user asks or when completing ship/PR. Use the correct remote (`fork` vs `origin`). `GIT_GUARD` still blocks `--force` / `reset --hard` on main / tag deletion.
- **Plan-then-build:** don't implement until the user confirms; finish and save the plan file before any code change.
- **Conventions inferred from the code:** exact-pin every direct Python dep (`==X.Y.Z`, no ranges) and regenerate `uv.lock` on bump (supply-chain blast radius); always pass explicit `encoding=` to `open()`/`read_text()`/`write_text()` (PLW1514 — Windows cp1252 corruption); put provider-specific deps in extras + lazy-install via `tools/lazy_deps.py`, not core `dependencies`; match the repo's heavy "why" comments on non-obvious pins/config.

# Patterns
- `agent/chat_completion_helpers.py` — canonical model-call dispatch.
- `toolsets.py` + `tools/` — how a tool is defined and grouped into a toolset.
- `hermes_cli/main.py` — CLI subcommand entrypoint (`hermes` console script).

# Imports
@CLAUDE.local.md

# Self-Maintenance
When you discover a pattern, gotcha, or convention that would help future work in this repo, add it here under the relevant section. One line where possible. If CLAUDE.md exceeds 200 lines, move the content to `.claude/skills/` instead.

---

## Claude Insights Applied — 2026-06-10
- **Code Review / Quality Gates** — Codex-style pre-commit gate (caught S1 dedup-key + import-gating bugs before merge).
- **Response Style** — chunking rule (8+ sessions lost to output token-limit errors).
- **Git** — documented git push policy (claude-auto allowed, bare claude ask-first) (recurring blocked-push friction).
- **Workflow** — plan-before-implement gate (premature starts + lost plan files).
- **Skills** — `.claude/skills/gated-ship/SKILL.md` encodes the design→implement→review→commit cycle.
- **Hooks** — `.claude/settings.json` carries a pre-commit ruff lint hook.
- **AGENTS.md** — `## Review learnings` Codex-facing bullets (marker: setup-ai-context-codex-learnings v1).

# Runner
Self-hosted GitHub Actions runner ops (location, start, status, logs, pre-CI check): see `.claude/skills/runner/SKILL.md`. Always verify the runner is online before triggering any workflow.
