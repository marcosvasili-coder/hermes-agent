#!/usr/bin/env bash
# =============================================================================
# repo-init.sh
# Full Cursor + Claude Code context setup for an existing repo.
# Solo developer edition — Phases 1, 2, 2b, 3, 4, 5, weekly, 6, 7.
#
# Canonical master copy (edit here, then copy into any repo root that uses it):
#   scripts/repo-init.sh in the dev-dock repo
#
# ---------------------------------------------------------------------------
# FULL RUN (recommended) — one terminal, all phases
# ---------------------------------------------------------------------------
# Run from the repo root with default phases (omit SETUP_AI_CONTEXT_PHASES, or use "all").
# Phases 1–4, 6, and phase 2 when SETUP_AI_CONTEXT_STAGE2=claude are driven by Claude Code
# (this script calls `claude`); Cursor is not required except for manual phase 2 if you
# leave SETUP_AI_CONTEXT_STAGE2 unset. Shell handles MCP + weekly + cron.
# Unattended phase 2:  SETUP_AI_CONTEXT_STAGE2=claude ./repo-init.sh
# Intentional phase-1-only rerun:  SETUP_AI_CONTEXT_PHASES=1 ./repo-init.sh
#
# ---------------------------------------------------------------------------
# LITERAL CHECKLIST — what runs vs what YOU do (read this once)
# ---------------------------------------------------------------------------
# At start: this script truncates .claude/setup-log.txt (fresh log for this run).
#
# Phase 1 — Runner (optional) + Claude project brain
#   AUTOMATIC: find actions-runner (in-repo, ~/actions-runners/<repo>, or ~/.../actions-runner/.../run.sh);
#     if found, write runner skill,
#     runner.mdc, CLAUDE.md runner section, settings.json runner hook + GIT_GUARD hook;
#     always write .claude/skills/git/SKILL.md when phase 1 runs.
#     Phase 2 writes cursor-agent-cli-workflow.mdc (Cursor vs Claude Code). Then Claude
#     Opus (re)writes CLAUDE.md, CLAUDE.local.md (still rough until Phase 6),
#     .claude/settings.json, .claude/skills/*.md, gitignore lines from prompt.
#   YOU: wait in this terminal (often 10–40+ minutes). Approve Claude if prompted.
#
# Phase 2 — Cursor rules under .cursor/rules/
#   AUTOMATIC: writes .claude/cursor-stage2-prompt.txt (includes runner warning if needed).
#   THEN EITHER:
#     SETUP_AI_CONTEXT_STAGE2=claude (or export it): Claude Opus writes .mdc files; YOU wait.
#     default (manual): script prints the prompt — YOU copy → Cursor → Agents → paste → run
#       → return here and press ENTER when .cursor/rules is updated.
#
# Phase 2b — Agents (.claude/agents/ + .cursor/agents/)
#   AUTOMATIC: writes generic agent stubs if missing; Opus pass customizes them to this repo.
#   YOU: wait in this terminal.
#
# Phase 3 — Cross-check (read-only audit)
#   AUTOMATIC: Claude Opus reads CLAUDE*.md, skills, agents, .cursor/rules; writes
#     .claude/crosscheck-report.md (conflicts, redundancy, gaps, stale, fixes).
#   YOU: nothing; read the report later if you want.
#
# Phase 4 — Auto-apply fixes
#   AUTOMATIC: Claude applies "Recommended Fixes" from the cross-check (edits repo files).
#   YOU: review git diff afterwards if you care; runner.mdc / runner skill are protected.
#
# Phase 5 — MCP servers (machine-wide + Claude; not per-repo)
#   AUTOMATIC: merges context7 / GitHub / Playwright (browser) / Memory into ~/.cursor/mcp.json
#     and Claude MCP. Drops `xcode-tools` if present (xcrun mcpbridge fatals unless Xcode is running).
#   YOU: restart Cursor when the script says so.
#        If npx is missing, stdio MCPs are skipped (script warns).
#        GitHub: GITHUB_PAT, or `gh auth token` when logged in, else TTY prompt.
#        SKIP_PLAYWRIGHT=1 / SKIP_GITHUB=1 to skip those servers.
#
# Phase Weekly — .claude/weekly-maintenance.sh + crontab
#   AUTOMATIC: writes the weekly bash script (Sonnet: health report then auto-fix),
#     installs ONE Monday 09:00 cron line tagged with this repo path.
#   AUTOMATIC: weekly phase strips legacy ai-context-weekly-review lines for this repo path.
#   YOU: open crontab -e only if you still see duplicates from manual edits or mismatched paths.
#
# Phase 6 — CLAUDE.local.md
#   AUTOMATIC: Claude Opus overwrites CLAUDE.local.md with inferred personal prefs.
#   YOU: open CLAUDE.local.md and fix anything marked (inferred) or wrong.
#
# Stage 2 modes (summary):
#   A) export SETUP_AI_CONTEXT_STAGE2=claude  →  unattended .cursor/rules via Claude Code
#   B) unset / manual  →  Cursor Agents paste + ENTER in this terminal
#   C) @cursor/sdk + CURSOR_API_KEY  →  not bundled; insert your own runner between 1 and 3
#
# Partial re-run (only listed phases; log is appended, not cleared):
#   SETUP_AI_CONTEXT_PHASES=2b,3 ./repo-init.sh
#   SETUP_AI_CONTEXT_PHASES=4,5,weekly,6,7 ./repo-init.sh
#   Values: 1, 2, 2b, 3, 4, 5, weekly, 6, 7  or  all  (default).
#
# Stage 5 GitHub MCP (non-interactive / agent / CI):
#   export GITHUB_PAT=ghp_...   →  install GitHub MCP without prompting
#   Or: `gh auth login` — script falls back to `gh auth token` when GITHUB_PAT is unset.
#   SKIP_GITHUB=1               →  skip GitHub MCP
#   SKIP_PLAYWRIGHT=1         →  skip Playwright browser MCP
#   SKIP_CLAUDE_MCP_CLI=1     →  only merge ~/.cursor/mcp.json; skip `claude mcp add` (no hangs in automation)
#   If stdin is not a TTY and no PAT/gh token, GitHub MCP is skipped with a warning (no hang).
#
# Node / npx (Stage 5 stdio MCPs):
#   SETUP_AI_CONTEXT_SKIP_NODE_INSTALL=1  →  never run `brew install node`; skip MCP if npx absent.
#
# Usage:
#   ./repo-init.sh --help
#   chmod +x repo-init.sh && ./repo-init.sh
#   SETUP_AI_CONTEXT_STAGE2=claude ./repo-init.sh
#   SETUP_AI_CONTEXT_PHASES=2b,3 ./repo-init.sh
#   SETUP_AI_CONTEXT_PHASES=4,5,weekly,6 ./repo-init.sh
# After editing the master, copy into repo roots, e.g.:
#   cp scripts/repo-init.sh ./repo-init.sh && chmod +x ./repo-init.sh
#
# ---------------------------------------------------------------------------
# Git workflow (convention across all your repos — also injected into CLAUDE.md)
# ---------------------------------------------------------------------------
# - One integration branch (usually main): merge finished work there; keep it shippable.
# - Short-lived feature branches, one purpose each; clear names (feat/…, fix/…).
# - After merge: checkout main, pull, delete the old branch (local + remote when done).
# - Prefer git pull --rebase on feature work before PR (optional: git config pull.rebase true).
# - Agents: do not leave the repo on stray cursor/… branches without intent; return to
#   the integration branch when a task is done unless continuing deliberate feature work.
#
# Roll out master script + Git workflow to every known repo (edit list in sync-copies):
#   - copies repo-init.sh
#   - writes/refreshes .cursor/rules/git-workflow.mdc (Cursor) with detected integration branch
#   - writes/refreshes .cursor/rules/cursor-agent-cli-workflow.mdc (Cursor / Claude / Codex / iTerm)
#   - appends # Git workflow to CLAUDE.md (Claude) once (marker), if CLAUDE.md exists
#   bash scripts/repo-init.sh sync-copies
# Or override paths (colon-separated):
#   SETUP_AI_CONTEXT_REPO_PATHS="/path/a:/path/b" bash scripts/repo-init.sh sync-copies
#
# Requirements:
#   - claude CLI installed and authenticated
#   - node / npx (for GitHub + Memory MCPs). On macOS + Homebrew: if npx is missing, the script
#     runs `brew install node` unless SETUP_AI_CONTEXT_SKIP_NODE_INSTALL=1. Other OSes: install Node from nodejs.org.
#   - python3 installed (standard on macOS)
#   - Run from your repo root (directory containing .git)
#
# CI convention (your machine): GitHub Actions jobs that should use this Mac’s runner pool should set
#   runs-on: [self-hosted, macOS, ARM64]
# and skip fork PRs on self-hosted (if: github.event_name != 'pull_request' || head repo == github.repository).
# =============================================================================

# Write Cursor Agents vs Claude Code vs Codex vs iTerm rule (single source — phase 2 + sync-copies).
write_cursor_agent_cli_workflow_mdc() {
  local dir="${1:?rules dir}"
  mkdir -p "$dir"
  cat > "$dir/cursor-agent-cli-workflow.mdc" <<'CURSORCLIAUDEOF'
---
description: Cursor Agents only — routing vs Claude Code, Codex, iTerm; handoffs, subagents.
alwaysApply: true
---

> **Repo rule.** Same text in **User rules:** paste from `~/.cursor/USER-RULES-PASTE-FOR-CURSOR-AGENTS.md` (**Cursor → Settings → Rules**). **Canonical source:** edit **`scripts/repo-init.sh`** in the dev-dock repo (`write_cursor_agent_cli_workflow_mdc`). Then re-run **phase 2**, **`sync-copies`**, or **`scripts/fleet-sync-agent-workflow.sh`**. New repo: copy `repo-init.sh` into the repo root, run **`./repo-init.sh`** (full or at least phases **2+**).

# Cursor Agents view — workflow

**Scope:** These rules apply **only** in **Cursor Agent** (Agents side view / agent chat, e.g. Cmd+I). They do **not** apply to Cursor Tab, Cmd/Ctrl+K inline edit, or the terminal by themselves.

**Outside this view:** Long or wide work may belong in **Claude Code** (`claude` in the terminal). **Read-only review** may belong in **Codex CLI** (`codex review` in the terminal). **Live ops** (runner start, install smoke, manual `gh`) often run in **iTerm** beside Cursor — not an autonomous agent.

## What each surface is best at

| Surface | Best for |
|---------|----------|
| **Cursor Agents** (+ subagents) | IDE-tight work (navigation, diffs, diagnostics), MCP/browser, short steering cycles, UI/layout |
| **Claude Code CLI** (`claude` at repo root) | Long linear passes, wide refactors, long shell/git/test chains, sustained batch work |
| **Codex CLI** (`run-codex-review.sh` / `codex review …`) | Read-only scoped review (security, side effects, script audit). Prefer the logged gate `bash ~/actions-runners/bin/run-codex-review.sh "$PWD" --vs-main`. **Paste verdict back to Cursor** — Codex does not own commits |
| **iTerm** (human) | Runner singleton checks, `./scripts/install-app.sh`, live smoke, `gh` you want visible — **not** a fourth autonomous driver |

**Rule of thumb:** IDE-shaped → Cursor. Batch-shaped → Claude. Review-before-merge → Codex → Cursor implements. Runner/CI smoke → you in iTerm.

## Roles (while in Agents view)

- You are the agent in **Cursor Agents view**; coordinate **Claude Code** for batch work and **Codex** for review passes.
- **Before non-trivial work**, state explicitly: (1) recommended surface + one sentence why; (2) **one write driver** for this branch — Cursor **or** `claude` (not both); (3) constraints (branch, must-not-touch, verify command); (4) optional **Codex review** scope before/after edits; (5) **HANDOFF** block if switching to Claude.
- **Codex:** suggest `bash ~/actions-runners/bin/run-codex-review.sh "$PWD" --vs-main` (or `--uncommitted`; logged gate) — raw `codex review --base main "…"` as fallback; user runs in terminal; user pastes **approve / changes-needed** here; you implement fixes.
- **iTerm:** call out when the human should run pre-CI checks (e.g. `./scripts/check-runner-singletons.sh`) or install smoke — do not spawn Terminal.app as primary UX unless user asks.
- Human is final decision maker on merges. `claude-auto` may push on request or ship/PR; bare `claude` asks first.
- Keep changes small and reviewable.

## Subagents (Cursor)

Use **subagents** for scoped side quests (read-only exploration, parallel lookups). Do **not** split **write ownership** between subagents and the main agent on the same branch without an explicit **handoff** summary.

## Session bias (this chat)

Use subagents to reduce thrash. If the task becomes a **long terminal-driven pass**, stop extending here — output a **HANDOFF** block for **Claude Code** instead of grinding in Agents.

## One driver per branch (Cursor vs Claude)

- Only **one autonomous write driver** per branch at a time: Cursor Agent **or** `claude`, not both editing the same pass. Codex is review-only. iTerm is human-only.
- Before switching, leave a clean story (`git status` understandable, or a commit).
- Run `claude` from the repo root (`git rev-parse --show-toplevel`). Prefer one Cursor window = one repo root aligned with that cwd.

**HANDOFF block** — when switching to Claude Code, output this **filled in** for the user to paste:

```
HANDOFF — read first, then continue.

Goal:
Non-goals / do not touch:
Branch:  (who owns this pass: Cursor vs claude)
Already done:  (files + summary)
Commands already run:  (with outcomes if relevant)
Current state:  (tests/lint, open errors)
Codex review:  (paste approve/changes-needed if any)
Next steps:  (3–5 ordered)
Open questions / risks:
```

## Chat and session hygiene

- **One chat per task.** When done, say: "Start a new chat for the next task — cleaner context."
- **Context degrading.** After 8+ exchanges without resolution, suggest a new chat.
- **Wrong surface.** Terminal-driven or 5+ files → HANDOFF to Claude; review-only → Codex first.
- **Model.** Always use Auto. Never suggest switching to a specific model.

## Verification and scope

- Before claiming done, run this repo’s usual checks (README, Makefile, `package.json` / `pyproject.toml`, or CI workflow). If none exist, say what you verified manually.
- Do not expand scope: no unrelated refactors, no new dependencies, no extra files unless the user asked or required.
- No drive-by formatting or renames outside the requested change.

## Security

- Never commit secrets or paste production credentials into chat. Follow existing env / secret patterns in the repo.

## Subscription vs API (Claude Code)

- When the user intends **Claude Max** subscription billing for the CLI, do not assume `ANTHROPIC_API_KEY` in the shell; subscription auth is separate. If a key is set and they want subscription, call it out.

<!-- setup-ai-context-cursor-cli-workflow v3 -->
CURSORCLIAUDEOF
}

# CLAUDE.md snippet appended by sync-copies when marker absent (keeps Claude CLI aligned with .mdc).
write_claude_agent_surfaces_append() {
  local claude_md="${1:?CLAUDE.md path}"
  local marker='<!-- setup-ai-context-agent-surfaces v1 -->'
  grep -qF "$marker" "$claude_md" 2>/dev/null && return 0
  cat >>"$claude_md" <<'EOF'

# Agent surfaces (Cursor, Claude, Codex, iTerm)

Keep wording aligned with `.cursor/rules/cursor-agent-cli-workflow.mdc`.

- **Cursor Agents:** IDE-tight work, MCP/browser, short cycles, UI iteration.
- **Claude Code CLI:** long batch passes, wide refactors, long shell/git/test chains.
- **Codex CLI:** read-only `codex review` — paste approve/changes-needed back to Cursor; Codex does not commit.
- **iTerm (human):** runner singleton checks, install smoke, manual `gh` — not an autonomous driver.
- **One write driver per branch:** Cursor **or** `claude`, not both on the same pass; clean handoff before switching.
- **Start non-trivial work with:** surface + why, one driver, constraints, verify command, optional Codex scope, HANDOFF if switching.

<!-- setup-ai-context-agent-surfaces v1 -->
EOF
}

# In-session self-learning for Cursor (repo-specific domain rules grow via weekly + tasks).
write_self_improvement_mdc() {
  local dir="${1:?rules dir}"
  mkdir -p "$dir"
  cat > "$dir/self-improvement.mdc" <<'EOF'
---
description: Repo-specific self-learning — update rules, skills, and Codex learnings after tasks
alwaysApply: true
---

# Self-learning (this repo only)

Learnings stay **in this repository** — not in global Cursor/Claude/Codex config. Global files are for personal style only.

## After completing a task

1. **Repeated explanation** already covered elsewhere → add or extend `.cursor/rules/[domain].mdc` (with `description` frontmatter) or `.claude/skills/<name>/SKILL.md`.
2. **Clarifying question answerable from code** → add one line to the nearest domain rule or `CLAUDE.md` `# Self-Maintenance`.
3. **Better pattern found** → update the relevant rule/skill; note what changed in the PR or commit message.
4. **Rule caused a mistake** → add a `REVIEW:` comment in that rule for the human, or flag in `.claude/weekly-review.md`.
5. **Codex review pasted** (approve / changes-needed) → distill durable bullets into `AGENTS.md` **## Review learnings** (marker `setup-ai-context-codex-learnings v1`). Skip one-off nits; keep side effects, invariants, protected paths.

## Do not learn into (script-owned — edit `scripts/repo-init.sh` master instead)

- `cursor-agent-cli-workflow.mdc`, `runner.mdc`, `git-workflow.mdc`

## Codex is not autonomous

Codex reads **`AGENTS.md`** at repo root. You maintain **## Review learnings** so `codex review` gets smarter over time. Weekly cron also refreshes that section from drift scans.

<!-- setup-ai-context-self-improvement v1 -->
EOF
}

# Codex reads AGENTS.md — give it review scope + a section weekly maintenance can grow.
write_agents_codex_learnings_append() {
  local agents_md="${1:?AGENTS.md path}"
  local marker='<!-- setup-ai-context-codex-learnings v1 -->'
  if grep -qF "$marker" "$agents_md" 2>/dev/null; then
    # v1 block present — migrate only the Commands bullet inside ## Codex (review-only)
    # to the run-codex-review.sh wrapper. Guard on that line itself (a Review-learnings
    # bullet mentioning run-codex-review must not mask an un-migrated Commands line).
    python3 - "$agents_md" <<'PY'
import sys
path = sys.argv[1]
lines = open(path, encoding="utf-8").read().splitlines(keepends=True)
new_cmd = '- **Commands:** `bash ~/actions-runners/bin/run-codex-review.sh "$PWD" --vs-main` (vs integration branch) or `bash ~/actions-runners/bin/run-codex-review.sh "$PWD" --uncommitted` (working tree) — logged gate. **Claude Code:** run from session after commit (network; disable sandbox if blocked). **Codex 0.137+:** no custom prompt with `--base`/`--uncommitted` — standing focus in **## Review learnings**; bare `codex review --uncommitted` or `--base main` only.\n'
in_codex = False
for i, line in enumerate(lines):
    if line.startswith("## "):
        in_codex = line.startswith("## Codex (review-only)")
        continue
    if in_codex and line.startswith("- **Commands:**"):
        needs = "run-codex-review" not in line or "Codex 0.137+" not in line
        if needs and line != new_cmd:
            lines[i] = new_cmd
            open(path, "w", encoding="utf-8").write("".join(lines))
        break
PY
    return 0
  fi
  local block='

## Codex (review-only)

- **Role:** read-only `codex review`; you do not commit, push, or edit files.
- **Read first:** `CLAUDE.md` autonomy constraints and this file **## Review learnings**.
- **Typical scope:** side effects (`gh api`, `git push`, `rm -rf`, LaunchAgent writes), protected paths, exit codes, idempotency.
- **Commands:** `bash ~/actions-runners/bin/run-codex-review.sh "$PWD" --vs-main` (vs integration branch) or `bash ~/actions-runners/bin/run-codex-review.sh "$PWD" --uncommitted` (working tree) — logged gate. **Claude Code:** run from session after commit (network; disable sandbox if blocked). **Codex 0.137+:** no custom prompt with `--base`/`--uncommitted` — standing focus in **## Review learnings**; bare `codex review --uncommitted` or `--base main` only.
- **Output:** bullet verdict — approve / changes-needed; human pastes into Cursor Agents for fixes.

## Review learnings (repo-specific, auto-maintained)

Durable patterns for **this repo** worth checking on every review. Weekly maintenance and agents append here after Codex feedback or incidents. Keep one line per bullet; max ~25. Do not duplicate full `CLAUDE.md`.

- (none yet — weekly maintenance and post-review agent tasks populate this section)

<!-- setup-ai-context-codex-learnings v1 -->'
  local phase7='<!-- repo-init-phase-7'
  if grep -qF "$phase7" "$agents_md" 2>/dev/null; then
    python3 - "$agents_md" "$block" <<'PY'
import sys
path, block = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
needle = "<!-- repo-init-phase-7"
idx = text.find(needle)
if idx == -1:
    open(path, "a", encoding="utf-8").write(block)
else:
    open(path, "w", encoding="utf-8").write(text[:idx].rstrip() + block + "\n\n" + text[idx:])
PY
  else
    printf '%s\n' "$block" >>"$agents_md"
  fi
}

refresh_repos_txt_from_cursor() {
  local repos_file="${1:?repos file path}"
  local discovered
  discovered=$(python3 - << 'PYEOF'
import json, os, subprocess, urllib.parse
from pathlib import Path

def file_uri_to_path(uri):
    if not uri or not isinstance(uri, str) or not uri.startswith("file://"):
        return None
    parsed = urllib.parse.urlparse(uri)
    path = urllib.parse.unquote(parsed.path)
    return path.rstrip("/") or None

def add_folder_paths(blob, acc):
    for key in ("folder", "workspace"):
        uri = blob.get(key)
        p = file_uri_to_path(uri) if isinstance(uri, str) else None
        if not p:
            continue
        if p.endswith(".code-workspace") and os.path.isfile(p):
            try:
                w = json.loads(Path(p).read_text(encoding="utf-8"))
                for f in w.get("folders") or []:
                    fp = f.get("path")
                    if isinstance(fp, str) and fp:
                        rp = fp if os.path.isabs(fp) else str(Path(p).parent / fp)
                        acc.add(os.path.realpath(rp))
            except Exception:
                pass
        else:
            acc.add(os.path.realpath(p))

roots = set()
ws_base = Path.home() / "Library/Application Support/Cursor/User/workspaceStorage"
if ws_base.is_dir():
    for wp in ws_base.glob("*/workspace.json"):
        try:
            add_folder_paths(json.loads(wp.read_text(encoding="utf-8")), roots)
        except Exception:
            pass

storage = Path.home() / "Library/Application Support/Cursor/User/globalStorage/storage.json"
if storage.is_file():
    try:
        data = json.loads(storage.read_text(encoding="utf-8"))
        wmap = data.get("profileAssociations", {}).get("workspaces") or {}
        for uri in wmap:
            if not isinstance(uri, str):
                continue
            p = file_uri_to_path(uri)
            if not p:
                continue
            if p.endswith(".code-workspace") and os.path.isfile(p):
                try:
                    w = json.loads(Path(p).read_text(encoding="utf-8"))
                    for f in w.get("folders") or []:
                        fp = f.get("path")
                        if isinstance(fp, str) and fp:
                            rp = fp if os.path.isabs(fp) else str(Path(p).parent / fp)
                            roots.add(os.path.realpath(rp))
                except Exception:
                    pass
            elif os.path.isdir(p):
                roots.add(os.path.realpath(p))
    except Exception:
        pass

git_toplevels = set()
for r in sorted(roots):
    if not os.path.isdir(r):
        continue
    try:
        out = subprocess.run(
            ["git", "-C", r, "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=15,
        )
        if out.returncode == 0 and out.stdout.strip():
            git_toplevels.add(os.path.realpath(out.stdout.strip()))
    except Exception:
        pass

for p in sorted(git_toplevels):
    print(p)
PYEOF
  )

  if [[ -z "$discovered" ]]; then
    echo "refresh_repos_txt: no repos discovered from Cursor workspace storage"
    return 0
  fi

  local _refresh_lib
  _refresh_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/registry-lib.sh"
  if [[ -f "$_refresh_lib" ]]; then
    # shellcheck source=registry-lib.sh
    source "$_refresh_lib"
  fi

  # Tagged registries (# work / # personal): append only — full rewrite would drop sections.
  if [[ -f "$repos_file" ]] \
    && grep -qiE '^#[[:space:]]*(work|personal)[[:space:]]*$' "$repos_file" \
    && declare -F registry_append_entry >/dev/null 2>&1; then
    local p
    while IFS= read -r p || [[ -n "$p" ]]; do
      [[ -z "$p" ]] && continue
      registry_append_entry "$repos_file" "$p" "untagged"
    done <<< "$discovered"
    local tagged_count
    tagged_count="$(registry_paths_only "$repos_file" 2>/dev/null | grep -c '.' || true)"
    echo "refresh_repos_txt: appended discoveries to tagged registry ($tagged_count paths in $repos_file)"
    return 0
  fi

  # Flat registry: merge discovered paths with existing entries, deduplicate
  local existing=""
  if [[ -f "$repos_file" ]]; then
    if declare -F registry_paths_only >/dev/null 2>&1; then
      existing="$(registry_paths_only "$repos_file")"
    else
      existing="$(grep -v '^\s*$\|^\s*#' "$repos_file" 2>/dev/null || true)"
    fi
  fi

  local merged
  merged=$(printf '%s\n%s\n' "$discovered" "$existing" \
    | grep -v '^\s*$' \
    | sort -u)

  mkdir -p "$(dirname "$repos_file")"
  printf '%s\n' "$merged" > "$repos_file"
  local count
  count=$(printf '%s\n' "$merged" | grep -c '.' || true)
  echo "refresh_repos_txt: refreshed $repos_file ($count repos)"
}

case "${1:-}" in
  -h|--help)
    cat <<'HELPEOF'
repo-init.sh — bootstrap Cursor + Claude Code context (phases 1–7 + weekly).

Run from a git repo root:
  ./repo-init.sh
  SETUP_AI_CONTEXT_STAGE2=claude ./repo-init.sh
  SETUP_AI_CONTEXT_PHASES=2b,3 ./repo-init.sh
  SETUP_AI_CONTEXT_PHASES=4,5,weekly,6,7 ./repo-init.sh
  SETUP_AI_CONTEXT_PHASES=7 ./repo-init.sh          # regenerate AGENTS.md only
  ./repo-init.sh --help

Roll out (from any cwd): copy master script; refresh .cursor/rules/git-workflow.mdc and
  cursor-agent-cli-workflow.mdc (Cursor); append # Git workflow to CLAUDE.md (Claude) once if missing:
  bash scripts/repo-init.sh sync-copies
  SETUP_AI_CONTEXT_REPO_PATHS="/a:/b" bash scripts/repo-init.sh sync-copies

Phases (SETUP_AI_CONTEXT_PHASES)
  Comma-separated: 1, 2, 2b, 3, 4, 5, weekly, 6, 7  or  all  (default: all)
  1       Runner (optional) + CLAUDE.md, skills, settings, gitignore hints
  2       Writes .claude/cursor-stage2-prompt.txt; then Cursor paste OR claude (see STAGE2)
  2b      Agent definitions (.claude/agents/ + .cursor/agents/) with per-repo enhancement
  3       Cross-check report → .claude/crosscheck-report.md
  4       Apply Recommended Fixes from that report
  5       MCP: context7, GitHub, Playwright (browser), Memory (~/.cursor/mcp.json + claude mcp)
  weekly  .claude/weekly-maintenance.sh + Monday crontab line
  6       Auto-fill CLAUDE.local.md (Opus)
  7       Generate AGENTS.md — brief agent-ready summary of the repo (Opus)

Environment
  SETUP_AI_CONTEXT_STAGE2=claude          Phase 2 via Claude Code (no Cursor paste)
  SETUP_AI_CONTEXT_PHASES=1,2,2b,3,...    Partial re-run (log appended unless all)
  GITHUB_PAT=ghp_...                      GitHub MCP without TTY prompt
  SKIP_GITHUB=1                           Skip GitHub MCP entirely
  SKIP_PLAYWRIGHT=1                       Skip Playwright browser MCP
  SKIP_CLAUDE_MCP_CLI=1                  Skip claude mcp add (Cursor mcp.json only)
  SETUP_AI_CONTEXT_SKIP_NODE_INSTALL=1    Do not run brew install node when npx is missing
  (Partial runs: phase 4 requires an existing non-empty .claude/crosscheck-report.md — run phase 3 first.)

Master copy (edit, then cp into repos):
  scripts/repo-init.sh in the dev-dock repo
HELPEOF
    exit 0
    ;;
  sync-copies)
    MASTER="${SETUP_AI_CONTEXT_MASTER:-${BASH_SOURCE[0]}}"
    if [[ ! -f "$MASTER" ]]; then
      echo "sync-copies: master not found: $MASTER" >&2
      exit 1
    fi
    REPOS_FILE_PATH="${AI_CONTEXT_REPOS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/dev-dock/registry.txt}"
    echo "sync-copies: refreshing registry.txt from Cursor workspace storage..."
    refresh_repos_txt_from_cursor "$REPOS_FILE_PATH"
    _REGISTRY_LIB="$(dirname "$MASTER")/registry-lib.sh"
    if [[ -f "$_REGISTRY_LIB" ]]; then
      # shellcheck source=registry-lib.sh
      source "$_REGISTRY_LIB"
    fi
    if [[ -n "${SETUP_AI_CONTEXT_REPO_PATHS:-}" ]]; then
      IFS=':' read -ra REPOS <<< "$SETUP_AI_CONTEXT_REPO_PATHS"
      USE_REGISTRY_LIB=false
    else
      USE_REGISTRY_LIB=false
      if declare -F registry_each_entry >/dev/null 2>&1 && [[ -f "$REPOS_FILE_PATH" ]]; then
        USE_REGISTRY_LIB=true
      elif [[ -f "$REPOS_FILE_PATH" ]]; then
        REPOS=()
        while IFS= read -r line || [[ -n "$line" ]]; do
          line="${line#"${line%%[![:space:]]*}"}"
          line="${line%"${line##*[![:space:]]}"}"
          [[ -z "$line" ]] && continue
          [[ "$line" == \#* ]] && continue
          REPOS+=("$line")
        done < "$REPOS_FILE_PATH"
      else
        echo "sync-copies: registry.txt not found at $REPOS_FILE_PATH" >&2
        echo "Create it with one repo path per line, or use SETUP_AI_CONTEXT_REPO_PATHS." >&2
        exit 1
      fi
    fi
    marker='setup-ai-context-git-workflow v1'
    mdc_marker='<!-- setup-ai-context-git-workflow-mdc v1 -->'
    _sync_copies_one_root() {
      local root="$1"
      [[ -n "$root" ]] || return 0
      if [[ ! -d "$root/.git" ]]; then
        echo "sync-copies: skip (not a git repo): $root"
        return 0
      fi
      cp "$MASTER" "$root/repo-init.sh"
      chmod +x "$root/repo-init.sh"
      echo "sync-copies: updated repo-init.sh → $root"

      def_branch="main"
      # Prefer "remote show origin" (true default on host); symbolic-ref can be stale after renames.
      if ob=$(git -C "$root" remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p' | head -1); then
        [[ -n "$ob" ]] && def_branch="$ob"
      elif sym=$(git -C "$root" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null); then
        def_branch="${sym#refs/remotes/origin/}"
      fi

      rules_dir="$root/.cursor/rules"
      mkdir -p "$rules_dir"
      git_mdc="$rules_dir/git-workflow.mdc"
      cat >"$git_mdc" <<EOF
---
description: "When branching, merging, PRs, or post-task git cleanup — match CLAUDE.md Git workflow"
---

# Git workflow (Cursor)

Integration branch for this repo: **${def_branch}** (detected from \`origin\`; fallback \`main\`). Keep this file aligned with the \`# Git workflow\` section in \`CLAUDE.md\`.

- **Integration branch:** merge finished work to **${def_branch}**; keep it shippable.
- **Feature branches:** short-lived, one purpose each; prefer clear names (\`feat/…\`, \`fix/…\`).
- **After merge:** \`git checkout ${def_branch}\` && \`git pull\`, then delete the finished feature branch (and remote tracking branch when applicable).
- **Sync:** prefer \`git pull --rebase\` on a feature branch before opening or updating a PR (optional: \`git config pull.rebase true\`).
- **Agents / automation:** do not leave the checkout on incidental \`cursor/…\` branches without intent; return to **${def_branch}** when a task is complete unless deliberately continuing feature work.

${mdc_marker}
EOF
      echo "sync-copies: wrote $git_mdc (integration branch: $def_branch)"

      write_cursor_agent_cli_workflow_mdc "$rules_dir"
      echo "sync-copies: wrote $rules_dir/cursor-agent-cli-workflow.mdc"
      write_self_improvement_mdc "$rules_dir"
      echo "sync-copies: wrote $rules_dir/self-improvement.mdc"

      claude_md="$root/CLAUDE.md"
      # AGENTS.md — write a pointer stub if the file doesn't exist yet.
      # Full generation requires Phase 7 (Opus call per repo); stub covers the common case.
      agents_md_stub_marker='<!-- repo-init-phase-7-stub v1 -->'
      agents_md_path="$root/AGENTS.md"
      if [[ ! -f "$agents_md_path" ]]; then
        repo_name_for_stub=$(basename "$root")
        cat > "$agents_md_path" <<EOF
# ${repo_name_for_stub}

> Read \`CLAUDE.md\` for full project conventions before acting.

## Key files (read before acting)
- \`CLAUDE.md\` — must-read conventions and workflow
- \`.claude/agents/\` — repo agents (check what exists)
- \`.cursor/rules/cursor-agent-cli-workflow.mdc\` — Cursor / Claude / Codex / iTerm routing

## Autonomy constraints
- May push, merge, or open PRs when the user asks or when completing ship/PR; confirm before force-push or merging to main
- Do not commit secrets or production credentials
- Check \`CLAUDE.md\` for repo-specific do-not-touch patterns

${agents_md_stub_marker}
<!-- Run SETUP_AI_CONTEXT_PHASES=7 ./repo-init.sh for a full Opus-generated AGENTS.md -->
EOF
        echo "sync-copies: wrote AGENTS.md stub → $root"
      elif grep -qF "$agents_md_stub_marker" "$agents_md_path" 2>/dev/null; then
        echo "sync-copies: AGENTS.md is a stub → $root (run Phase 7 to upgrade)"
      else
        echo "sync-copies: AGENTS.md already present (phase-7 or manual) → $root"
      fi
      write_agents_codex_learnings_append "$agents_md_path"
      echo "sync-copies: ensured Codex learnings section in AGENTS.md → $root"

      if [[ ! -f "$claude_md" ]]; then
        echo "sync-copies: skip CLAUDE.md append (missing): $claude_md"
        return 0
      fi

      if grep -qF "$marker" "$claude_md" 2>/dev/null; then
        echo "sync-copies: CLAUDE.md already has Git workflow marker → $root"
      else
        cat >>"$claude_md" <<EOF

# Git workflow

- **Integration branch:** **${def_branch}** (repo default / \`origin\` HEAD; treat as source of truth).
- **Feature branches:** short-lived, one purpose each; prefer clear names (\`feat/…\`, \`fix/…\`).
- **After merge:** \`git checkout ${def_branch}\` && \`git pull\`, then delete the finished feature branch (and remote tracking branch when applicable).
- **Sync:** prefer \`git pull --rebase\` while on a feature branch before opening or updating a PR (optional: \`git config pull.rebase true\`).
- **Agents / automation:** do not leave the checkout on incidental \`cursor/…\` or unnamed branches without intent; return to **${def_branch}** when a task is complete unless explicitly continuing feature work.
- **Cursor parity:** the same policy lives in \`.cursor/rules/git-workflow.mdc\` — keep the integration branch name consistent if you edit either file.

<!-- setup-ai-context-git-workflow v1 -->
EOF
        echo "sync-copies: appended # Git workflow to CLAUDE.md → $root"
      fi
      write_claude_agent_surfaces_append "$claude_md"
      echo "sync-copies: ensured # Agent surfaces in CLAUDE.md → $root"
    }
    if [[ -n "${SETUP_AI_CONTEXT_REPO_PATHS:-}" ]]; then
      for root in "${REPOS[@]}"; do
        _sync_copies_one_root "$root"
      done
    elif $USE_REGISTRY_LIB; then
      while IFS=$'\t' read -r _tag root; do
        _sync_copies_one_root "$root"
      done < <(registry_each_entry "$REPOS_FILE_PATH")
    else
      for root in "${REPOS[@]}"; do
        _sync_copies_one_root "$root"
      done
    fi
    echo "sync-copies: done."
    exit 0
    ;;
esac

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${BLUE}[setup]${NC} $1"; }
success() { echo -e "${GREEN}[ok]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[x]${NC} $1"; exit 1; }
divider() { echo -e "\n${BOLD}----------------------------------------${NC}\n"; }

# ── Dependency guards + repo paths ────────────────────────────────────────────
command -v claude  &>/dev/null || error "claude CLI not found. Install from: https://claude.ai/code"
command -v python3 &>/dev/null || error "python3 not found. Install Xcode Command Line Tools: xcode-select --install"
[[ -d .git ]]                  || error "Not a git repo. Run from your project root."

REPO_ROOT=$(pwd)
CLAUDE_DIR="$REPO_ROOT/.claude"
CURSOR_DIR="$REPO_ROOT/.cursor/rules"
CURSOR_MCP_FILE="$HOME/.cursor/mcp.json"
LOG_FILE="$CLAUDE_DIR/setup-log.txt"
REPORT_FILE="$CLAUDE_DIR/crosscheck-report.md"
STAGE2_FILE="$CLAUDE_DIR/cursor-stage2-prompt.txt"
WEEKLY_SCRIPT="$CLAUDE_DIR/weekly-maintenance.sh"
# Partial runs that skip phase 1 still reference RUNNER_PATH in phase 2 (set -u).
RUNNER_PATH="${RUNNER_PATH:-}"

# Auto-register this repo in registry.txt so sync-copies includes it automatically.
# Skip when REPO_ROOT is under a temp dir (/tmp, /private/tmp, or $TMPDIR) —
# test fixtures shouldn't leak into the registry. macOS /tmp is a symlink to
# /private/tmp and $TMPDIR is typically under /var/folders/.../T/, so all three
# need explicit coverage.
MASTER_REPOS_FILE="${AI_CONTEXT_REPOS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/dev-dock/registry.txt}"
if [[ "$REPO_ROOT" == /tmp/* \
   || "$REPO_ROOT" == /private/tmp/* \
   || ( -n "${TMPDIR:-}" && "$REPO_ROOT" == "${TMPDIR%/}"/* ) ]]; then
  echo "[setup] Skipping registry registration (REPO_ROOT under temp dir: $REPO_ROOT)"
else
  _register_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/registry-lib.sh"
  if [[ -f "$_register_lib" ]]; then
    # shellcheck source=registry-lib.sh
    source "$_register_lib"
  fi
  mkdir -p "$(dirname "$MASTER_REPOS_FILE")"
  if declare -F registry_append_entry >/dev/null 2>&1; then
    registry_append_entry "$MASTER_REPOS_FILE" "$REPO_ROOT" "untagged"
  else
    touch "$MASTER_REPOS_FILE"
    if ! grep -Fxq "$REPO_ROOT" "$MASTER_REPOS_FILE" 2>/dev/null; then
      echo "$REPO_ROOT" >> "$MASTER_REPOS_FILE"
      echo "[setup] Registered $REPO_ROOT in registry.txt"
    fi
  fi
fi

mkdir -p "$CLAUDE_DIR/skills"
mkdir -p "$CURSOR_DIR"
mkdir -p "$HOME/.cursor"

HAS_NPX=false

# If npx is missing, try Homebrew `node` on macOS (includes npx). Opt out: SETUP_AI_CONTEXT_SKIP_NODE_INSTALL=1
ensure_npx_for_mcp() {
  command -v npx &>/dev/null && return 0
  if [[ "${SETUP_AI_CONTEXT_SKIP_NODE_INSTALL:-0}" == "1" ]]; then
    warn "npx not found — skipping auto-install (SETUP_AI_CONTEXT_SKIP_NODE_INSTALL=1). GitHub + Memory MCP steps will be skipped."
    return 1
  fi
  if [[ "$(uname -s)" != "Darwin" ]]; then
    warn "npx not found — auto-install is only wired for macOS + Homebrew. Install Node.js from https://nodejs.org (includes npx)."
    return 1
  fi
  if ! command -v brew &>/dev/null; then
    warn "npx not found — Homebrew not in PATH. Install Node.js from https://nodejs.org (includes npx)."
    return 1
  fi
  log "Installing Node.js via Homebrew (provides npx for GitHub + Memory MCPs)..."
  if ! HOMEBREW_NO_ANALYTICS=1 brew list node &>/dev/null; then
    HOMEBREW_NO_ANALYTICS=1 brew install node || {
      warn "brew install node failed. Install Node.js manually from https://nodejs.org"
      return 1
    }
  fi
  # Ensure this shell sees Homebrew's npx (Apple Silicon vs Intel default prefixes).
  [[ -d /opt/homebrew/bin ]] && PATH="/opt/homebrew/bin:$PATH"
  [[ -d /usr/local/bin ]] && PATH="/usr/local/bin:$PATH"
  export PATH
  hash -r 2>/dev/null || true
  if command -v npx &>/dev/null; then
    success "npx is available ($(command -v npx))."
    return 0
  fi
  warn "npx still not on PATH after brew install node. Open a new terminal or run: hash -r"
  return 1
}

ensure_npx_for_mcp || true
command -v npx &>/dev/null && HAS_NPX=true

# Global ~/.claude/settings.json often sets advisorModel "sonnet". Opus -p runs then fail with:
#   tools.N.model: 'claude-sonnet-4-6' cannot be used as an advisor when the request model is 'claude-opus-4-7'
# Merge this on every Opus print session so advisor matches the executor model family.
CLAUDE_CODE_OPUS_SESSION_SETTINGS='{"advisorModel":"opus"}'

# Partial runs: comma-separated phases: 1,2,2b,3,4,5,weekly,6,7  (default all)
# Example — only missing tail:  SETUP_AI_CONTEXT_PHASES=4,5,weekly,6,7 ./repo-init.sh
SETUP_AI_CONTEXT_PHASES="${SETUP_AI_CONTEXT_PHASES:-all}"

run_phase() {
  local n="$1"
  [[ "$SETUP_AI_CONTEXT_PHASES" == "all" ]] && return 0
  [[ ",$SETUP_AI_CONTEXT_PHASES," == *",$n,"* ]]
}

# Partial runs: fail fast if a phase depends on missing artifacts.
preflight_partial_phases() {
  [[ "$SETUP_AI_CONTEXT_PHASES" == "all" ]] && return 0
  local ph=",${SETUP_AI_CONTEXT_PHASES},"
  if [[ "$ph" == *",4,"* ]]; then
    if [[ ! -f "$REPORT_FILE" || ! -s "$REPORT_FILE" ]]; then
      error "Phase 4 is listed but $REPORT_FILE is missing or empty. Run phase 3 first, e.g.: SETUP_AI_CONTEXT_PHASES=3 ./repo-init.sh"
    fi
    if ! grep -qiE 'recommended[[:space:]]+fixes|##[[:space:]]*recommended' "$REPORT_FILE"; then
      warn "crosscheck-report.md may not contain a clear \"Recommended Fixes\" section — phase 4 may do little."
    fi
  fi
  if [[ "$ph" == *",3,"* ]]; then
    local n=0
    shopt -s nullglob
    local mdc=( "$CURSOR_DIR"/*.mdc )
    shopt -u nullglob
    n=${#mdc[@]}
    if [[ "$n" -eq 0 ]]; then
      warn "Phase 3: no .mdc files under $CURSOR_DIR — run phases 1–2 (or add rules) for a meaningful audit."
    fi
  fi
  if [[ "$ph" == *",6,"* ]]; then
    if [[ ! -f "$REPO_ROOT/CLAUDE.md" || ! -s "$REPO_ROOT/CLAUDE.md" ]]; then
      error "Phase 6 is listed but CLAUDE.md is missing or empty. Run phase 1 first, e.g.: SETUP_AI_CONTEXT_PHASES=1 ./repo-init.sh"
    fi
  fi
  if [[ "$ph" == *",2,"* ]] && [[ "${SETUP_AI_CONTEXT_STAGE2:-manual}" == "claude" ]]; then
    if [[ ! -f "$REPO_ROOT/CLAUDE.md" || ! -s "$REPO_ROOT/CLAUDE.md" ]]; then
      warn "Phase 2 (claude): CLAUDE.md is missing or empty — Opus will have little project context. Run phase 1 first if this is a fresh repo."
    fi
  fi
  if [[ "$ph" == *",2b,"* ]]; then
    if [[ ! -f "$REPO_ROOT/CLAUDE.md" || ! -s "$REPO_ROOT/CLAUDE.md" ]]; then
      warn "Phase 2b: CLAUDE.md is missing or empty — agent definitions will stay generic unless you run phase 1 first."
    fi
  fi
  if [[ "$ph" == *",7,"* ]]; then
    if [[ ! -f "$REPO_ROOT/CLAUDE.md" || ! -s "$REPO_ROOT/CLAUDE.md" ]]; then
      error "Phase 7 is listed but CLAUDE.md is missing or empty. Run phase 1 first, e.g.: SETUP_AI_CONTEXT_PHASES=1 ./repo-init.sh"
    fi
  fi
}

if [[ "$SETUP_AI_CONTEXT_PHASES" == "all" ]]; then
  : > "$LOG_FILE"  # initialise / clear log
else
  echo "" >> "$LOG_FILE"
  echo "=== Partial run SETUP_AI_CONTEXT_PHASES=$SETUP_AI_CONTEXT_PHASES at $(date) ===" >> "$LOG_FILE"
fi

preflight_partial_phases

echo -e "\n${BOLD}Cursor + Claude Code Context Setup${NC}"
echo "Repo: $REPO_ROOT"
echo "Log:  $LOG_FILE"
echo "Phases: $SETUP_AI_CONTEXT_PHASES"
echo ""
if [[ "$SETUP_AI_CONTEXT_PHASES" == "all" ]]; then
  echo -e "${YELLOW}[notice]${NC} Full run: log file was cleared at start."
else
  echo -e "${YELLOW}[notice]${NC} Partial run: log is appended (not cleared). Skipped phases are not executed."
fi
echo -e "${YELLOW}[notice]${NC} Stage 2 mode (only if phase 2 runs): ${SETUP_AI_CONTEXT_STAGE2:-manual}  (use ${BOLD}SETUP_AI_CONTEXT_STAGE2=claude${NC} for unattended rules)."
divider

# =============================================================================
# STAGE 1 — Runner detection + Claude Code context files
# =============================================================================

if run_phase 1; then

cat <<EOF

================================================================
PHASE 1 — Runner (optional) + Claude Code project context
================================================================
AUTOMATIC:
  - Find self-hosted runner: in-repo actions-runner/, ~/actions-runners/<repo>/run.sh, or ~/.../actions-runner/.../run.sh.
  - If found: write .claude/skills/runner/SKILL.md, .cursor/rules/runner.mdc,
    append "# Runner" to CLAUDE.md, merge runner PreToolUse + GIT_GUARD hooks in .claude/settings.json.
  - Always write .claude/skills/git/SKILL.md (git workflow skill).
  - Run Claude Code (Opus) to generate or refresh CLAUDE.md, CLAUDE.local.md (template),
    .claude/settings.json, .claude/skills/*.md, and gitignore lines from the embedded prompt.
YOU DO NOW:
  - Stay in this terminal. Do not expect to use Cursor during Phase 1.
  - If Claude Code asks for login or tool approval, complete it where prompted.
WHERE OUTPUT GOES:
  - Stdout below + appended to: $LOG_FILE
DURATION:
  - Often 10–40+ minutes depending on repository size.

EOF

log "Stage 1 — Detecting runner and generating Claude Code context..."

# ── 1a. Auto-detect self-hosted GitHub Actions runner ─────────────────────────
log "Scanning for self-hosted GitHub Actions runner..."

RUNNER_PATH=""
REPO_BASE=$(basename "$REPO_ROOT")

# Prefer: in-repo install, then ~/actions-runners/<repo>/ (common on this machine),
# then any run.sh under ~/actions-runners, then legacy ~/.../actions-runner/... paths.
if [[ -x "$REPO_ROOT/actions-runner/run.sh" ]]; then
  RUNNER_PATH="$REPO_ROOT/actions-runner"
elif [[ -n "${HOME:-}" && -x "$HOME/actions-runners/$REPO_BASE/run.sh" ]]; then
  RUNNER_PATH="$HOME/actions-runners/$REPO_BASE"
else
  RUNNER_SCRIPT=""
  if [[ -n "${HOME:-}" && -d "$HOME/actions-runners" ]]; then
    RUNNER_SCRIPT=$(find "$HOME/actions-runners" -type f -name "run.sh" ! -path "*/.git/*" 2>/dev/null | head -1 || true)
  fi
  if [[ -z "$RUNNER_SCRIPT" ]]; then
    RUNNER_SCRIPT=$(find "$HOME" -maxdepth 8 -type f -name "run.sh" -path "*/actions-runner/*" ! -path "*/.git/*" 2>/dev/null | head -1 || true)
  fi
  if [[ -n "$RUNNER_SCRIPT" ]]; then
    RUNNER_PATH=$(dirname "$RUNNER_SCRIPT")
  fi
fi

if [[ -n "$RUNNER_PATH" ]]; then
  success "Runner found: $RUNNER_PATH"
else
  warn "No runner found. Runner setup skipped. Rerun after installing."
fi

# ── 1b. Write runner files if found ──────────────────────────────────────────
if [[ -n "$RUNNER_PATH" ]]; then

  RUNNER_START="cd $RUNNER_PATH && ./run.sh"
  RUNNER_STATUS="pgrep -f 'Runner.Listener' > /dev/null && echo online || echo offline"
  RUNNER_LOGS="ls -t $RUNNER_PATH/_diag/*.log 2>/dev/null | head -1 | xargs tail -50"

  # .claude/skills/runner/SKILL.md
  mkdir -p "$CLAUDE_DIR/skills/runner"
  cat > "$CLAUDE_DIR/skills/runner/SKILL.md" << RUNNEREOF
---
name: runner
description: Managing the local self-hosted GitHub Actions runner
---

# Runner Skill

## When to use
Before any task that triggers a GitHub Actions workflow.
When debugging CI failures. When the runner appears offline.

## Status check
$RUNNER_STATUS

## Start runner
$RUNNER_START
Run in a separate terminal — it stays in foreground.
Wait ~10 seconds after starting before triggering any workflow.

## Read latest log
$RUNNER_LOGS

## Pre-CI checklist
1. Check status: $RUNNER_STATUS
2. If offline: open a new terminal and run: $RUNNER_START
3. Wait 10 seconds
4. Confirm online: $RUNNER_STATUS
5. Proceed with the workflow-triggering task

## Gotchas
- Runner runs in the foreground — needs its own terminal tab
- Never close the runner terminal while a job is running
- Runner must be online BEFORE pushing commits that trigger workflows
- If a job hangs, read the latest log for the real error
RUNNEREOF
  success "Runner skill written."

  # .cursor/rules/runner.mdc
  cat > "$CURSOR_DIR/runner.mdc" << RULEEOF
---
description: "When working on CI, GitHub Actions, workflows, or any task that triggers a runner"
---

# Self-Hosted Runner

Location: $RUNNER_PATH
Start:    $RUNNER_START
Status:   $RUNNER_STATUS
Logs:     $RUNNER_LOGS

## Rules
- ALWAYS check runner status before triggering any GitHub Actions workflow
- If offline, tell the developer to start it in a new terminal — never assume it is online
- Never push commits that trigger workflows without confirming the runner is up
- If a workflow fails unexpectedly, check the runner log first

## Pre-CI steps
1. Run status check
2. If offline: open new terminal, run start command, wait 10 seconds
3. Confirm online, then proceed
RULEEOF
  success "Runner Cursor rule written."

  # Append # Runner section to CLAUDE.md if not already present
  if ! grep -q "^# Runner" "$REPO_ROOT/CLAUDE.md" 2>/dev/null; then
    cat >> "$REPO_ROOT/CLAUDE.md" << CLAUDERUNEOF

# Runner
Self-hosted GitHub Actions runner — started manually before CI tasks.
- Location: $RUNNER_PATH
- Start:    $RUNNER_START
- Status:   $RUNNER_STATUS
- Logs:     $RUNNER_LOGS
- Rule: Always verify runner is online before triggering any workflow.
  If offline, start it in a separate terminal and wait 10 seconds.
CLAUDERUNEOF
    success "Runner section appended to CLAUDE.md."
    # Warn if CLAUDE.md is now over 200 lines
    LINE_COUNT=$(wc -l < "$REPO_ROOT/CLAUDE.md")
    if [[ "$LINE_COUNT" -gt 200 ]]; then
      warn "CLAUDE.md is now $LINE_COUNT lines (over 200). Consider moving some sections to .claude/skills/."
    fi
  else
    success "Runner section already in CLAUDE.md — skipping."
  fi

  # Add runner status PreToolUse hook to .claude/settings.json
  log "Adding runner status hook to .claude/settings.json..."
  python3 - << PYEOF
import json, os, sys

path = '$CLAUDE_DIR/settings.json'
settings = {}

if os.path.exists(path):
    try:
        with open(path) as f:
            settings = json.load(f)
    except Exception as e:
        print(f'Warning: could not parse existing settings.json: {e}')
        sys.exit(0)

settings.setdefault('hooks', {}).setdefault('PreToolUse', [])

already = any(
    'Runner.Listener' in str(h)
    for h in settings['hooks']['PreToolUse']
)

if not already:
    settings['hooks']['PreToolUse'].append({
        "matcher": "Bash",
        "hooks": [{
            "type": "command",
            "command": (
                "INPUT=\${CLAUDE_TOOL_INPUT:-}; "
                "if echo \"\$INPUT\" | grep -qiE 'gh workflow|git push|act |workflow_dispatch'; then "
                "  STATUS=\$(pgrep -f 'Runner.Listener' > /dev/null 2>&1 && echo online || echo offline); "
                "  if [ \"\$STATUS\" = 'offline' ]; then "
                "    echo 'WARNING: Self-hosted runner is OFFLINE.'; "
                "    echo 'Start it first: $RUNNER_START'; "
                "  fi; "
                "fi || true"
            )
        }]
    })
    with open(path, 'w') as f:
        json.dump(settings, f, indent=2)
    print('Runner hook added to settings.json')
else:
    print('Runner hook already present — skipping.')
PYEOF

  log "Adding GIT_GUARD hook to .claude/settings.json..."
  CLAUDE_DIR="$CLAUDE_DIR" python3 - << 'GITGUARDEOF'
import json, os

path = os.path.join(os.environ.get("CLAUDE_DIR", ".claude"), "settings.json")
settings = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            settings = json.load(f)
    except Exception:
        pass

settings.setdefault("hooks", {}).setdefault("PreToolUse", [])

raw = json.dumps(settings)
if "GIT_GUARD" in raw:
    print("GIT_GUARD hook already present — skipping.")
else:
    settings["hooks"]["PreToolUse"].append({
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": (
            "# GIT_GUARD\n"
            "INPUT=\"${CLAUDE_TOOL_INPUT:-}\"; BLOCK=0; MSG=''; "
            "if echo \"$INPUT\" | grep -qE 'git push.*--force(\\s|$)' && ! echo \"$INPUT\" | grep -q 'force-with-lease'; "
            "then BLOCK=1; MSG='BLOCKED: git push --force forbidden. Use --force-with-lease.'; fi; "
            "if echo \"$INPUT\" | grep -qE 'git push.*--force.*\\b(main|master)\\b'; "
            "then BLOCK=1; MSG='BLOCKED: force-push to main/master never allowed.'; fi; "
            "if echo \"$INPUT\" | grep -qE 'git reset --hard' && git rev-parse --abbrev-ref HEAD 2>/dev/null | grep -qE '^(main|master)$'; "
            "then BLOCK=1; MSG='BLOCKED: git reset --hard on main/master. Switch branches first.'; fi; "
            "if echo \"$INPUT\" | grep -qE 'git tag -d|git tag.*-f'; "
            "then BLOCK=1; MSG='BLOCKED: tag deletion or force-update. Confirm with developer first.'; fi; "
            "if [ \"$BLOCK\" -eq 1 ]; then echo \"$MSG\"; exit 1; fi; exit 0"
        )}]
    })
    with open(path, "w") as f:
        json.dump(settings, f, indent=2)
    print("GIT_GUARD hook added.")
GITGUARDEOF

fi  # end runner block

mkdir -p "$CLAUDE_DIR/skills/git"
cat > "$CLAUDE_DIR/skills/git/SKILL.md" << 'GITSKILLEOF'
---
name: git
description: Solo developer hybrid git workflow — branch when it matters, commit direct when it doesn't
---

# Git Skill

## When to use
Any task involving commits, branches, merges, pushes, or releases.

## Branching policy
**Commit direct to `main`** for: typos, comment fixes, version bumps,
config tweaks, documentation, single-line obvious fixes.

**Branch first** for: new features, bug fixes with logic changes,
refactors, multi-file changes, anything that could break the build.

## Branch naming
- `feat/short-description`
- `fix/short-description`
- `refactor/short-description`
- `chore/short-description`
- `docs/short-description`
Kebab-case, under 40 chars.

## Commit messages — conventional commits, mandatory
- `feat: add X`
- `fix: prevent Y when Z`
- `refactor: extract X from Y`
- `chore: bump dependency X`
- `docs: clarify X`
- `test: cover X case`
- `ci: fix workflow Y`
Imperative mood. Subject under 72 chars. One concept per commit.

## Merging
Squash merge feature branches into `main`. After merge: delete local and remote branch.

## Pushing
- Push only after local tests pass
- Never `git push --force` — use `--force-with-lease` if needed
- Never force-push to `main` under any circumstance

## Releases
- Build from `main` only
- Annotated tags only: `git tag -a v1.2.3 -m "release notes"`
- Semver strict

## Forbidden without explicit confirmation
- `git push --force` (use `--force-with-lease`)
- `git reset --hard` on `main`
- `git rebase` on any branch already pushed
- Deleting unmerged branches
- Modifying or recreating an existing tag
GITSKILLEOF
success "Git skill written."

# ── 1c. Claude Code analyses repo and writes remaining context files ──────────
log "Claude Code analysing repo (Opus — takes a few minutes)..."

claude -p \
'Analyse this entire repository thoroughly before writing anything.

Read: directory structure, source files, package files (package.json,
Gemfile, pyproject.toml, go.mod, Cargo.toml, Package.swift etc),
existing config, test setup, build system, CI files (.github/workflows),
and any existing CLAUDE.md or .claude/ directory.

Then generate or overwrite the following files. Every value must reflect
the actual repo. No placeholders. No invented examples.
Do NOT overwrite files that already contain rich repo-specific content
unless they are structurally wrong or contain only placeholders.
Do NOT overwrite any runner skill or runner-related content already written.
Do NOT create or overwrite .cursor/rules/cursor-agent-cli-workflow.mdc — repo-init phase 2 writes that file deterministically.

FILE 1: CLAUDE.md (project root)

Structure (preserve any existing # Runner section if present):

# Project
[What this repo is and does. What it is NOT. 2-3 sentences max.]

# Stack
[Actual language, framework, key libs - one line each]

# Commands
- build: [real command or "Open in Xcode" for native apps]
- test: [real command or note if slow/manual]
- lint: [real command or "none configured"]
- dev: [real command or "Open in Xcode"]
[add others found: deploy, release, archive, distribute, sign]

# Structure
[Actual key directories only — what lives in each]

# Git workflow
State the actual default branch name (from git: symbolic-ref refs/remotes/origin/HEAD, else remote show origin, else main).
Then bullets (adapt to this repo reality):
- Integration branch: [name] — merge finished work here; keep it shippable.
- Feature branches: short-lived, one purpose; clear names (feat/…, fix/…); delete after merge.
- After merge: checkout default branch, pull, delete the old branch (local + remote when applicable).
- Prefer pull --rebase on feature branches before PR.
- Agents: return to the integration branch when a task is done unless deliberately continuing feature work.
- Cursor parity: ensure .cursor/rules/git-workflow.mdc names the same integration branch and the same rules (create or update it; it may already exist from repo-init sync-copies).

# Agent surfaces (Cursor, Claude, Codex, iTerm)
Ground this in how this repo is actually worked. Keep wording aligned with `.cursor/rules/cursor-agent-cli-workflow.mdc` and `~/.claude/CLAUDE.md`.

- **Cursor Agents:** IDE-tight work, MCP/browser, short steering cycles, UI iteration.
- **Claude Code CLI:** long batch passes, wide refactors, long shell/git/test chains.
- **Codex CLI:** read-only `codex review` — paste approve/changes-needed back to Cursor; Codex does not commit.
- **iTerm (human):** runner singleton checks, install smoke, manual `gh` — not an autonomous driver.
- **Start non-trivial work with:** (1) surface + why, (2) one write driver (Cursor vs `claude`), (3) constraints (branch, must-not-touch, verify command), (4) optional Codex review scope, (5) HANDOFF if switching to Claude.
- **One driver per branch:** Never run Cursor Agent and Claude Code on the same task pass in parallel; before switching, clean `git status` or a commit.
- **Claude Code subagents:** Use for scoped delegation inside the CLI; do not split write ownership without a handoff summary.
- **Subscriptions:** Claude Max vs Cursor billing are separate; do not assume `ANTHROPIC_API_KEY` for subscription auth.

# Rules
- Never edit [actually protected files from repo: .p12, .env,
  xcconfig locals, mobileprovision, lockfiles, generated files]
- Always run tests before committing
- [3-5 conventions inferred from actual code style in the repo]

# Patterns
[Reference 2-3 real files as canonical examples with actual paths]

# Imports
@CLAUDE.local.md

# Self-Maintenance
When you discover a pattern, gotcha, or convention that would help
future work in this repo, add it here under the relevant section.
One line where possible. If CLAUDE.md exceeds 200 lines, move the
content to .claude/skills/ instead.

FILE 2: CLAUDE.local.md (only if it does not exist or is empty)

# Personal Overrides
## Never do (personal)
[placeholder]
## Local environment notes
[placeholder]

FILE 3: .claude/settings.json
Only modify if hooks are missing or wrong.
Preserve any existing runner hook already written.
PostToolUse hook: run actual lint command after Write/Edit.
PreToolUse hook: block protected files without confirmation.
Stop hook: only add if a sub-30-second test command exists.

FILE 4: .claude/skills/[domain]/SKILL.md — one per domain found
Nested format with YAML frontmatter:
---
name: [domain]
description: [one line trigger description]
---
Sections: When to use / Steps (real commands) / Gotchas / Files
Only create if filled with real content. Never overwrite runner skill.

GITIGNORE — append if missing:
CLAUDE.local.md
.claude/setup-log.txt
.claude/crosscheck-report.md
.claude/weekly-review.md
.claude/cursor-stage2-prompt.txt

SUMMARY after writing:
1. Files written and reasoning
2. Files kept unchanged and why
3. Assumptions made
4. Anything needing manual input' \
  --model opus \
  --settings "$CLAUDE_CODE_OPUS_SESSION_SETTINGS" \
  --permission-mode auto \
  --allowedTools "Read,Write,Edit,Glob,Grep,Bash" \
  --max-turns 30 \
  2>&1 | tee -a "$LOG_FILE"

success "Stage 1 complete."
fi

divider

# =============================================================================
# STAGE 2 — Cursor: generate .cursor/rules/ files
# =============================================================================

if run_phase 2; then

cat <<EOF

================================================================
PHASE 2 — Project Cursor rules (.cursor/rules/*.mdc)
================================================================
AUTOMATIC (always):
  - Build $STAGE2_FILE with the full Cursor-rules prompt (includes runner note if applicable).
YOU — depends on SETUP_AI_CONTEXT_STAGE2 (current: ${SETUP_AI_CONTEXT_STAGE2:-manual}):
  - If claude: Claude Code will run the same text and write .mdc files — you only wait.
  - If manual: (1) Open Cursor → Agents with THIS repo as root. (2) Open $STAGE2_FILE,
    copy all, paste into the agent, run until files exist. (3) Return HERE and press ENTER.
WHY THIS PHASE EXISTS:
  - Cursor and Claude each have their own "always-on" context files; this phase creates
    the Cursor side from the real tree.

EOF

log "Stage 2 — Preparing Cursor rules prompt..."

log "Writing .cursor/rules/cursor-agent-cli-workflow.mdc..."
write_cursor_agent_cli_workflow_mdc "$CURSOR_DIR"
success "Cursor ↔ Claude workflow rule written."

log "Writing .cursor/rules/self-improvement.mdc..."
write_self_improvement_mdc "$CURSOR_DIR"
success "Self-improvement rule written."

# Determine whether runner.mdc was already written
RUNNER_NOTE=""
if [[ -n "$RUNNER_PATH" ]]; then
  RUNNER_NOTE="
IMPORTANT: .cursor/rules/runner.mdc has already been written by the
setup script with the correct runner path and commands. Do NOT
overwrite or recreate it."
fi

WORKFLOW_NOTE="
IMPORTANT: .cursor/rules/cursor-agent-cli-workflow.mdc has already been written by the
setup script (Cursor Agents vs Claude Code CLI). Do NOT overwrite or recreate it."

SELF_IMPROVE_NOTE="
IMPORTANT: .cursor/rules/self-improvement.mdc has already been written by the
setup script (repo-specific self-learning + Codex learnings loop). Do NOT overwrite or recreate it."

cat > "$STAGE2_FILE" << CURSOREOF
Analyse this entire repository thoroughly before doing anything.
Read the directory structure, source files, package files, existing
config, and any existing .cursor/ or .cursorrules files.
$RUNNER_NOTE
$WORKFLOW_NOTE
$SELF_IMPROVE_NOTE
Then generate or overwrite ALL of the following files. Every rule must
be grounded in what you actually find. No placeholders.

FILE 1: .cursor/rules/git-workflow.mdc (Rule Type: Auto Attached — use description below)

If this file already exists with HTML comment <!-- setup-ai-context-git-workflow-mdc v1 --> at the end,
it was written by repo-init sync-copies: keep the integration branch name identical to
CLAUDE.md # Git workflow; only update if you detect origin/HEAD changed vs both files.
If missing or has no marker, create it with YAML frontmatter:

---
description: "When branching, merging, PRs, or post-task git cleanup — match CLAUDE.md Git workflow"
---

Body: name the real integration branch (from git), then the same discipline as CLAUDE.md
(integration branch, short-lived feature branches, after-merge checkout + pull + delete branch,
pull --rebase before PR, agents return to integration branch when done). End the file with:
<!-- setup-ai-context-git-workflow-mdc v1 -->

FILE 2: .cursor/rules/index.mdc (Rule Type: Always)

- Project overview (2-3 sentences, actual repo)
- Actual stack and key libraries
- Protected files: never delete or overwrite without confirmation
  (signing certs, provisioning profiles, .p12, .env files,
  lockfiles, xcconfig local files, generated files)
- Core conventions from existing code: naming, imports,
  file organisation, error handling patterns
- References to 2-3 canonical files for patterns with actual paths
- Guardrails: never assume a package exists without checking;
  never commit without review; never run destructive commands
  without confirmation; never touch signing or secrets files

Keep under 200 lines. Move overflow to dynamic rule files.
Add one line pointing agents to .cursor/rules/git-workflow.mdc for branch/merge policy.
Add one line pointing agents to .cursor/rules/cursor-agent-cli-workflow.mdc for Cursor / Claude / Codex / iTerm routing (do not duplicate that policy here).

Add one line pointing agents to .cursor/rules/self-improvement.mdc for repo-specific learning (do not duplicate that policy here).

FILE 4+: .cursor/rules/[domain].mdc - one per domain found
(skip runner.mdc, git-workflow.mdc, cursor-agent-cli-workflow.mdc, and self-improvement.mdc if script-managed — already written)

Format for each file:
---
description: "When working on [domain] - [specific task triggers]"
---

[Actual conventions from the codebase for this domain]
[Real canonical file references with actual paths]
[Gotchas specific to how this repo handles this domain]

Only create a file if you can fill it with real content.
Skip any file you cannot ground in actual code.

CLEANUP:
If a legacy .cursorrules file exists at repo root, migrate valid
content into the appropriate .mdc files, then delete it.

SUMMARY:
1. Files written and reasoning behind each rule
2. Rules confirmed from code vs inferred assumptions
3. Anything that needs manual input from the developer
CURSOREOF

success "Cursor prompt saved to .claude/cursor-stage2-prompt.txt"

STAGE2_MODE="${SETUP_AI_CONTEXT_STAGE2:-manual}"
if [[ "$STAGE2_MODE" == "claude" ]]; then
  log "Stage 2 — Generating .cursor/rules/ via Claude Code (SETUP_AI_CONTEXT_STAGE2=claude)..."
  claude -p "$(cat "$STAGE2_FILE")" \
    --model opus \
    --settings "$CLAUDE_CODE_OPUS_SESSION_SETTINGS" \
    --permission-mode auto \
    --allowedTools "Read,Write,Edit,Glob,Grep,Bash" \
    --max-turns 35 \
    2>&1 | tee -a "$LOG_FILE"
  success "Stage 2 complete — .cursor/rules/ generated via Claude Code."
else
  echo ""
  echo -e "${BOLD}========================================${NC}"
  echo -e "${BOLD}  STAGE 2 — COPY THIS INTO CURSOR${NC}"
  echo -e "${BOLD}========================================${NC}"
  echo ""
  cat "$STAGE2_FILE"
  echo ""
  echo -e "${BOLD}========================================${NC}"
  echo -e "${BOLD}  END OF CURSOR PROMPT${NC}"
  echo -e "${BOLD}========================================${NC}"
  echo ""
  echo -e "${YELLOW}Steps:${NC}"
  echo "  1. Select all text between the === lines above"
  echo "  2. Copy it"
  echo "  3. Open Cursor Agents Window"
  echo "  4. Start a new local agent"
  echo "  5. Paste and run"
  echo ""
  echo "  Prompt also saved at: .claude/cursor-stage2-prompt.txt"
  echo ""
  echo -e "${YELLOW}Tip:${NC} rerun with SETUP_AI_CONTEXT_STAGE2=claude to skip this step."
  echo ""
  if [[ -t 0 ]]; then
    read -rp "Press ENTER when the Cursor agent has finished... "
  else
    warn "stdin is not a TTY — skipping wait for ENTER. Finish .cursor/rules in Cursor using $STAGE2_FILE, or rerun with SETUP_AI_CONTEXT_STAGE2=claude."
  fi
  success "Stage 2 manual step finished (prompt is in $STAGE2_FILE)."
fi
fi

divider

# =============================================================================
# STAGE 3 — Cross-check: audit both systems
# =============================================================================

if run_phase 3; then

cat <<EOF

================================================================
PHASE 3 — Cross-check (read-only audit)
================================================================
AUTOMATIC:
  - Claude Opus reads CLAUDE.md, CLAUDE.local.md, all .claude/skills/, all .claude/agents/,
    all .cursor/rules/, all .cursor/agents/.
  - Writes .claude/crosscheck-report.md — Conflicts, Redundancy, Gaps, Stale rules,
    Recommended fixes. It must NOT edit other files in this phase.
YOU DO NOW:
  - Nothing — wait for "[ok] Cross-check saved ..."

EOF

log "Stage 3 — Auditing Claude Code and Cursor rules and agents for conflicts..."

CROSSCHECK=$(claude -p \
'Read ALL of the following files in full:
- CLAUDE.md and CLAUDE.local.md (if exists)
- All files under .claude/skills/
- All files under .claude/agents/
- All files under .cursor/rules/
- All files under .cursor/agents/

Perform a thorough audit. Do NOT make any changes — report only.

Note: **Intentional overlap** between `CLAUDE.md` (# Agent surfaces) and `.cursor/rules/cursor-agent-cli-workflow.mdc` is expected (Claude reads the former; Cursor Agents read the latter). Flag only **contradictions**, not duplicate themes.

## Conflicts
Rules or conventions that contradict between CLAUDE.md and
.cursor/rules/. For each: what it is, which tool should own it,
recommended resolution.

## Redundancy
Rules duplicated across both systems. Where each should live
exclusively and which copy to remove.

## Gaps
Domains or tasks where neither system has guidance but should,
inferred from the actual codebase.

## Stale Rules
References to files, commands, or patterns that no longer exist.

## Agents
Agent files that reference commands, paths, or tools that do not exist in this repo.
Agent files with missing or incorrect model selections.

## Recommended Fixes
Prioritised. For each: file, section, exact change. Most impactful first.' \
  --model opus \
  --settings "$CLAUDE_CODE_OPUS_SESSION_SETTINGS" \
  --permission-mode default \
  --allowedTools "Read,Glob,Grep" \
  --max-turns 15 \
  2>&1)

echo "$CROSSCHECK" | tee -a "$LOG_FILE"

{
  echo "# Cross-Check Report"
  echo "Generated: $(date)"
  echo ""
  echo "$CROSSCHECK"
} > "$REPORT_FILE"

success "Cross-check saved to .claude/crosscheck-report.md"
fi

divider

# =============================================================================
# STAGE 4 — Auto-apply fixes from the cross-check report
# =============================================================================

if run_phase 4; then

cat <<EOF

================================================================
PHASE 4 — Auto-apply cross-check fixes
================================================================
AUTOMATIC:
  - Claude reads .claude/crosscheck-report.md and edits the repo to apply
    "Recommended Fixes" (and related conflict/redundancy guidance from the prompt).
  - Will NOT modify runner.mdc, the runner skill, or cursor-agent-cli-workflow.mdc (per prompt rules).
YOU DO AFTER:
  - git diff — sanity-check what changed; revert anything you disagree with.

EOF

log "Stage 4 — Auto-applying cross-check fixes..."

claude -p \
'Read .claude/crosscheck-report.md in full.

Apply every fix listed under "Recommended Fixes" in priority order.
Make the actual changes to the actual files.

Rules:
- Conflicts: edit the file that should NOT own the rule
- Redundancy: remove duplicate from lower-priority location
  (Claude Code owns behaviour/autonomy; Cursor owns style/convention)
- Gaps: add missing coverage to the most appropriate file
- Stale: remove or update references that no longer resolve
- Never touch runner.mdc, the runner skill, or cursor-agent-cli-workflow.mdc — these are system-managed by repo-init.sh
- Agents: update stale commands/paths; keep frontmatter intact

After applying, output a summary:
1. Every change made: file, section, what and why
2. Anything skipped and why
3. Confirm CLAUDE.md is under 200 lines
4. Flag any .cursor/rules/ file over 200 lines

Append to .claude/crosscheck-report.md:
## Fixes Applied
Date: [date]
[list of every change]' \
  --model opus \
  --settings "$CLAUDE_CODE_OPUS_SESSION_SETTINGS" \
  --permission-mode auto \
  --allowedTools "Read,Write,Edit,Glob,Grep" \
  --max-turns 60 \
  2>&1 | tee -a "$LOG_FILE"

success "Stage 4 complete."
fi

divider

# =============================================================================
# STAGE 5 — MCP: context7, GitHub, Memory
# =============================================================================

if run_phase 5; then

cat <<EOF

================================================================
PHASE 5 — MCP servers (Claude Code + Cursor, machine-wide)
================================================================
AUTOMATIC:
  - Ensures $CURSOR_MCP_FILE exists; merges context7, GitHub, Playwright (browser), Memory;
    removes xcode-tools (mcpbridge breaks MCP startup unless Xcode is running).
  - GitHub token: GITHUB_PAT, else gh auth token (if gh is logged in), else TTY prompt.
  - Runs claude mcp add for new stdio/HTTP MCPs where missing.
YOU MUST DO AFTER THIS PHASE:
  - Quit and reopen Cursor so it reloads $CURSOR_MCP_FILE.
UNATTENDED: GITHUB_PAT=... and/or run gh auth login; or SKIP_GITHUB=1. SKIP_PLAYWRIGHT=1 / SKIP_CLAUDE_MCP_CLI=1 optional.
IF npx WAS MISSING AT START:
  - Some MCP installs were skipped — install Node.js, re-run this script later.

EOF

log "Stage 5 — Installing MCP servers..."

CURSOR_MCP_FILE="$HOME/.cursor/mcp.json"
[[ -f "$CURSOR_MCP_FILE" ]] || echo '{"mcpServers":{}}' > "$CURSOR_MCP_FILE"

# xcrun mcpbridge exits with Swift fatalError when Xcode is not running — breaks whole MCP host.
log "Removing xcode-tools MCP from Cursor config if present (use Xcode MCP only while Xcode is open; add manually then)."
python3 - << 'PYRMX'
import json, os
p = os.path.expanduser("~/.cursor/mcp.json")
try:
    with open(p) as f:
        c = json.load(f)
except Exception:
    raise SystemExit(0)
srv = c.get("mcpServers") or {}
if "xcode-tools" in srv:
    del srv["xcode-tools"]
    with open(p, "w") as f:
        json.dump(c, f, indent=2)
    print("Removed xcode-tools from ~/.cursor/mcp.json")
PYRMX

# ── Helper: add HTTP MCP to Claude Code ──────────────────────────────────────
add_claude_mcp_http() {
  local name="$1" url="$2"
  if claude mcp list 2>/dev/null | grep -q "^$name"; then
    success "$name already in Claude Code."
  else
    if claude mcp add --transport http "$name" "$url" >> "$LOG_FILE" 2>&1; then
      success "$name added to Claude Code."
    else
      warn "$name failed — add manually: claude mcp add --transport http $name $url"
    fi
  fi
}

# ── Helper: add stdio MCP to Claude Code ─────────────────────────────────────
add_claude_mcp_stdio() {
  local name="$1"; shift; local args=("$@")
  if claude mcp list 2>/dev/null | grep -q "^$name"; then
    success "$name already in Claude Code."
  else
    if claude mcp add "$name" "${args[@]}" >> "$LOG_FILE" 2>&1; then
      success "$name added to Claude Code."
    else
      warn "$name failed — check log: $LOG_FILE"
    fi
  fi
}

# ── Helper: add HTTP MCP to Cursor ───────────────────────────────────────────
add_cursor_mcp_http() {
  local name="$1" url="$2"
  if python3 - << PYEOF 2>/dev/null; then
import json, sys
with open('$CURSOR_MCP_FILE') as f:
    c = json.load(f)
if '$name' in c.get('mcpServers', {}):
    sys.exit(0)
sys.exit(1)
PYEOF
    success "$name already in Cursor."
  else
    cp "$CURSOR_MCP_FILE" "${CURSOR_MCP_FILE}.backup"
    python3 - << PYEOF
import json
with open('$CURSOR_MCP_FILE') as f:
    c = json.load(f)
c.setdefault('mcpServers', {})['$name'] = {"url": "$url", "transport": "http"}
with open('$CURSOR_MCP_FILE', 'w') as f:
    json.dump(c, f, indent=2)
PYEOF
    success "$name added to Cursor."
  fi
}

# ── Helper: add stdio MCP to Cursor ──────────────────────────────────────────
add_cursor_mcp_stdio() {
  local name="$1" cmd="$2"; shift 2
  local args_json="$1"; shift
  # Default must be "${1:-"{}"}" — "${1:-{}}" is parsed wrong (first } closes :-).
  local env_json="${1:-"{}"}"

  if python3 - << PYEOF 2>/dev/null; then
import json, sys
with open('$CURSOR_MCP_FILE') as f:
    c = json.load(f)
if '$name' in c.get('mcpServers', {}):
    sys.exit(0)
sys.exit(1)
PYEOF
    success "$name already in Cursor."
  else
    cp "$CURSOR_MCP_FILE" "${CURSOR_MCP_FILE}.backup"
    python3 - << PYEOF
import json
with open('$CURSOR_MCP_FILE') as f:
    c = json.load(f)
c.setdefault('mcpServers', {})['$name'] = {
    "command": "$cmd",
    "args": $args_json,
    "env": $env_json
}
with open('$CURSOR_MCP_FILE', 'w') as f:
    json.dump(c, f, indent=2)
PYEOF
    success "$name added to Cursor."
  fi
}

run_claude_mcp_install() {
  if [[ "${SKIP_CLAUDE_MCP_CLI:-0}" == "1" || "${SKIP_CLAUDE_MCP_CLI:-}" == "true" ]]; then
    log "SKIP_CLAUDE_MCP_CLI=1 — skipping Claude-side: $1"
    return 0
  fi
  shift
  "$@"
}

# ── context7: live library docs (HTTP) ───────────────────────────────────────
log "Installing context7..."
run_claude_mcp_install context7 add_claude_mcp_http "context7" "https://mcp.context7.com/mcp"
add_cursor_mcp_http "context7" "https://mcp.context7.com/mcp"

# ── GitHub MCP (stdio via npx, requires PAT) ─────────────────────────────────
log "Installing GitHub MCP..."

if [[ "$HAS_NPX" == "true" ]]; then
  GITHUB_PAT_RESOLVED=""
  if [[ "${SKIP_GITHUB:-0}" == "1" || "${SKIP_GITHUB:-}" == "true" ]]; then
    log "SKIP_GITHUB set — GitHub MCP skipped."
  elif [[ -n "${GITHUB_PAT:-}" ]]; then
    GITHUB_PAT_RESOLVED="$GITHUB_PAT"
    log "GITHUB_PAT is set in the environment — using it for GitHub MCP (no prompt)."
  elif command -v gh &>/dev/null && gh auth status &>/dev/null; then
    GITHUB_PAT_RESOLVED="$(gh auth token 2>/dev/null || true)"
    if [[ -n "$GITHUB_PAT_RESOLVED" ]]; then
      log "GitHub MCP: using token from gh auth token (gh is logged in)."
    fi
  fi
  if [[ -z "$GITHUB_PAT_RESOLVED" ]] && [[ "${SKIP_GITHUB:-0}" != "1" && "${SKIP_GITHUB:-}" != "true" ]]; then
    if [[ -t 0 ]]; then
      echo ""
      echo -e "${YELLOW}GitHub MCP needs a Personal Access Token.${NC}"
      echo "  Prefer: gh auth login, or export GITHUB_PAT=..."
      echo "  Or create at: https://github.com/settings/tokens (scopes: repo, workflow, read:org)"
      echo "  Empty line skips; or SKIP_GITHUB=1."
      echo ""
      read -rsp "  Paste your GitHub PAT (input hidden): " GITHUB_PAT_RESOLVED
      echo ""
    else
      warn "No GITHUB_PAT and no gh token — GitHub MCP skipped."
      warn "Set GITHUB_PAT, run gh auth login, SKIP_GITHUB=1, or use an interactive terminal."
    fi
  fi

  if [[ -n "$GITHUB_PAT_RESOLVED" ]]; then
    run_claude_mcp_install github add_claude_mcp_stdio "github" \
      -e "GITHUB_PERSONAL_ACCESS_TOKEN=$GITHUB_PAT_RESOLVED" \
      -- npx -y @modelcontextprotocol/server-github

    add_cursor_mcp_stdio "github" "npx" \
      '["-y", "@modelcontextprotocol/server-github"]' \
      "{\"GITHUB_PERSONAL_ACCESS_TOKEN\": \"$GITHUB_PAT_RESOLVED\"}"
  elif [[ -t 0 ]] && [[ "${SKIP_GITHUB:-0}" != "1" && "${SKIP_GITHUB:-}" != "true" ]]; then
    warn "No PAT entered — GitHub MCP skipped."
    warn "Add later: claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=<token> -- npx -y @modelcontextprotocol/server-github"
  fi
else
  warn "npx not found — GitHub MCP skipped. Install Node.js then rerun."
fi

# ── Memory MCP (stdio via npx) ───────────────────────────────────────────────
log "Installing Memory MCP..."

if [[ "$HAS_NPX" == "true" ]]; then
  run_claude_mcp_install memory add_claude_mcp_stdio "memory" \
    -- npx -y @modelcontextprotocol/server-memory

  add_cursor_mcp_stdio "memory" "npx" \
    '["-y", "@modelcontextprotocol/server-memory"]' \
    '{}'
else
  warn "npx not found — Memory MCP skipped."
fi

# ── Playwright MCP (browser automation via MCP; stdio via npx) ─────────────────
log "Installing Playwright (browser) MCP..."

if [[ "$HAS_NPX" == "true" ]]; then
  if [[ "${SKIP_PLAYWRIGHT:-0}" == "1" || "${SKIP_PLAYWRIGHT:-}" == "true" ]]; then
    log "SKIP_PLAYWRIGHT set — Playwright MCP skipped."
  else
    run_claude_mcp_install playwright add_claude_mcp_stdio "playwright" \
      -- npx -y @playwright/mcp@latest

    add_cursor_mcp_stdio "playwright" "npx" \
      '["-y", "@playwright/mcp@latest"]' \
      '{}'
  fi
else
  warn "npx not found — Playwright MCP skipped."
fi

# Hermes Agent gateway (if installed)
HERMES_BIN=""
if [[ -x "$HOME/.local/bin/hermes" ]]; then
  HERMES_BIN="$HOME/.local/bin/hermes"
elif command -v hermes &>/dev/null; then
  HERMES_BIN="$(command -v hermes)"
fi
if [[ -n "$HERMES_BIN" ]]; then
  log "Installing Hermes MCP..."
  run_claude_mcp_install hermes add_claude_mcp_stdio "hermes" \
    -- hermes mcp serve

  add_cursor_mcp_stdio "hermes" "hermes" \
    '["mcp", "serve"]' \
    '{}'
fi

# ── Verify ────────────────────────────────────────────────────────────────────
echo ""
log "Claude Code MCP servers:"
claude mcp list 2>/dev/null | sed 's/^/  /' || echo "  (run: claude mcp list)"
echo ""
log "Cursor MCP config (secrets redacted):"
python3 - << 'PYREDACT' 2>/dev/null | sed 's/^/  /' || true
import json, os
p = os.path.expanduser("~/.cursor/mcp.json")
try:
    with open(p) as f:
        c = json.load(f)
except Exception:
    raise SystemExit(0)
def redact(d):
    if isinstance(d, dict):
        out = {}
        for k, v in d.items():
            if k == "env" and isinstance(v, dict):
                out[k] = {ek: ("***" if "TOKEN" in ek.upper() or "SECRET" in ek.upper() or "KEY" in ek.upper() else ev) for ek, ev in v.items()}
            else:
                out[k] = redact(v)
        return out
    return d
print(json.dumps(redact(c), indent=2))
PYREDACT
echo ""

success "Stage 5 complete."
echo -e "  ${YELLOW}Restart Cursor to load the new MCP servers.${NC}"
if [[ "${SKIP_CLAUDE_MCP_CLI:-0}" == "1" || "${SKIP_CLAUDE_MCP_CLI:-}" == "true" ]]; then
  echo -e "  ${YELLOW}SKIP_CLAUDE_MCP_CLI was set — run \`claude mcp add\` for context7 / github / memory / playwright if you want the same servers in Claude Code.${NC}"
fi
fi

divider

# =============================================================================
# WEEKLY MAINTENANCE — self-applying cron job
# =============================================================================

if run_phase weekly; then

cat <<EOF

================================================================
PHASE WEEKLY — Monday automation script + crontab
================================================================
AUTOMATIC:
  - Writes $WEEKLY_SCRIPT (Sonnet: writes .claude/weekly-review.md, runs AGENTS.md ↔ CLAUDE.md drift check, then auto-applies fixes).
  - Drift check skips repos still on the phase-7 stub or with CLAUDE.md untracked on HEAD — both are logged in weekly-review.md.
  - Installs ONE crontab line: Mondays 09:00, tagged with this repo path (see CRON_TAG).
  - Removes the same line if already present (idempotent) and strips legacy
    # ai-context-weekly-review repo=... for this repo so cron does not double-run.

EOF

log "Writing weekly maintenance script..."

# Capture PATH so cron can find claude
CURRENT_PATH="$PATH"

cat > "$WEEKLY_SCRIPT" << WEEKLYEOF
#!/usr/bin/env bash
# Auto-generated — runs every Monday 09:00
export PATH="$CURRENT_PATH"

REPO="$REPO_ROOT"
LOG="$LOG_FILE"

cd "\$REPO" || exit 1
echo "" >> "\$LOG"
echo "=== Weekly Maintenance: \$(date) ===" >> "\$LOG"

# Step 1: health report
claude -p \
'Read ALL context files:
- CLAUDE.md, CLAUDE.local.md
- All files under .claude/skills/
- All files under .claude/agents/
- All files under .cursor/rules/
- All files under .cursor/agents/

Scan the codebase for drift vs the rules.
Save a health report to .claude/weekly-review.md:

## Stale Rules
References to files, commands, or patterns no longer in the repo.

## Bloat
Any context file over 200 lines.

## Conflicts
New contradictions since last review.

## Missing Coverage
New code areas with no rule or skill coverage.

## Recommended Fixes
Prioritised. File, section, exact change per item.

End with: Last reviewed: [current date]' \
  --model sonnet \
  --permission-mode auto \
  --allowedTools "Read,Write,Glob,Grep" \
  --max-turns 15 \
  >> "\$LOG" 2>&1

# Step 1.5: AGENTS.md ↔ CLAUDE.md drift detection
# Skip when AGENTS.md is still a stub OR when CLAUDE.md is not tracked on HEAD —
# both cases mean there is no committed pair to compare. Logs the skip reason
# so weekly-review.md still records the state.
DRIFT_SKIP_REASON=""
if [[ ! -f AGENTS.md ]]; then
  DRIFT_SKIP_REASON="AGENTS.md not present in working tree"
elif grep -qF '<!-- repo-init-phase-7-stub v1 -->' AGENTS.md; then
  DRIFT_SKIP_REASON="AGENTS.md still on phase-7-stub — run SETUP_AI_CONTEXT_PHASES=7 FORCE_AGENTS_MD=1 ./repo-init.sh"
elif ! git ls-tree HEAD CLAUDE.md >/dev/null 2>&1; then
  DRIFT_SKIP_REASON="CLAUDE.md not tracked on HEAD (run Phase 1 or commit CLAUDE.md first)"
fi

if [[ -n "\$DRIFT_SKIP_REASON" ]]; then
  {
    echo ""
    echo "## AGENTS.md ↔ CLAUDE.md Drift"
    echo "Skipped: \$DRIFT_SKIP_REASON"
    echo "Last AGENTS.md drift check: \$(date)"
  } >> .claude/weekly-review.md 2>/dev/null || true
  echo "Drift check skipped: \$DRIFT_SKIP_REASON" >> "\$LOG"
else
  # Report-only: the script writes the heading + footer; claude's stdout supplies
  # the body. Allowlist excludes Write/Edit/Bash so the step physically cannot
  # mutate AGENTS.md, CLAUDE.md, or any other file.
  {
    echo ""
    echo "## AGENTS.md ↔ CLAUDE.md Drift"
    claude -p \
'Read CLAUDE.md and AGENTS.md.
AGENTS.md must be a brief, accurate summary of CLAUDE.md plus repo introspection.
Detect drift between them:
- Stack / integration branch / test / lint commands in AGENTS.md "Quick reference" vs CLAUDE.md.
- Commands referenced in AGENTS.md but no longer present in CLAUDE.md (renamed, removed).
- Protected paths in AGENTS.md "Autonomy constraints" missing from CLAUDE.md never-edit / hook deny lists (or vice versa).
- Files referenced under "Key files" that no longer exist in the repo.
- Repo-specific rules in CLAUDE.md not reflected in AGENTS.md autonomy constraints (high-severity rules only).

Output ONLY the report body as your reply — do NOT write any file. The calling script will write your stdout to .claude/weekly-review.md.
- One bullet per drift item: file, exact line/section, what diverged, suggested fix.
- If no drift, output exactly: "No drift detected."' \
      --model sonnet \
      --permission-mode auto \
      --allowedTools "Read,Glob,Grep" \
      --max-turns 8 \
      2>> "\$LOG"
    echo ""
    echo "Last AGENTS.md drift check: \$(date)"
  } >> .claude/weekly-review.md
fi

# Step 2: auto-apply fixes
claude -p \
'Read .claude/weekly-review.md.
Apply every fix under Recommended Fixes in priority order.
Remove stale rules, trim bloat, resolve conflicts, fill gaps.
Only make changes grounded in the actual repo.
Never modify runner.mdc, the runner skill, cursor-agent-cli-workflow.mdc, self-improvement.mdc, or agent frontmatter.
Append to .claude/weekly-review.md:
## Auto-Applied Fixes
Date: [date]
[list of changes]' \
  --model sonnet \
  --permission-mode auto \
  --allowedTools "Read,Write,Edit,Glob,Grep" \
  --max-turns 20 \
  >> "\$LOG" 2>&1

# Step 3: teach Codex — AGENTS.md Review learnings (Codex reads AGENTS.md every session)
if [[ -f AGENTS.md ]]; then
  claude -p \
'Read .claude/weekly-review.md and scan the repo for review-relevant patterns.
Update AGENTS.md section "## Review learnings" (marker setup-ai-context-codex-learnings v1):
- ADD bullets Codex should check next time (side effects, protected paths, invariants, test gaps)
- REMOVE stale bullets referencing deleted files or fixed issues
- MERGE duplicates; keep max 25 one-line bullets
- Do NOT edit ## Quick reference, ## Autonomy constraints, or ## Codex (review-only) header text
- If the section is missing, create it per repo-init template
Append to .claude/weekly-review.md:
## Codex learnings updated
Date: [date]
Bullets added/removed: [summary]' \
    --model sonnet \
    --permission-mode auto \
    --allowedTools "Read,Write,Edit,Glob,Grep" \
    --max-turns 12 \
    >> "\$LOG" 2>&1
else
  echo "Step 3 skipped: no AGENTS.md" >> "\$LOG"
fi

# Notify Hermes with weekly review summary
if command -v hermes &>/dev/null; then
  hermes chat -z "Read \$(pwd)/.claude/weekly-review.md \
and send me a Telegram summary of any issues found. \
If nothing needs attention say \
'All clear: \$(basename \$(pwd))'. \
Keep it to bullet points."
fi

echo "Done: \$(date)" >> "\$LOG"
WEEKLYEOF

chmod +x "$WEEKLY_SCRIPT"

CRON_TAG="# ai-context-weekly repo=${REPO_ROOT}"
# Older script versions installed an inline claude job tagged this way — remove so Monday does not run twice.
LEGACY_CRON_TAG="# ai-context-weekly-review repo=${REPO_ROOT}"
quoted_weekly=$(printf %q "$WEEKLY_SCRIPT")
CRON_LINE="0 9 * * 1 bash ${quoted_weekly} ${CRON_TAG}"
(
  crontab -l 2>/dev/null | grep -vF "$CRON_TAG" | grep -vF "$LEGACY_CRON_TAG" || true
  printf '%s\n' "$CRON_LINE"
) | crontab -

success "Weekly cron installed (Mondays 09:00)."
fi

divider

# =============================================================================
# STAGE 6 — Auto-fill CLAUDE.local.md from everything discovered
# =============================================================================

if run_phase 6; then

cat <<EOF

================================================================
PHASE 6 — CLAUDE.local.md (personal, gitignored)
================================================================
AUTOMATIC:
  - Claude Opus reads your repo + existing context files and overwrites CLAUDE.local.md
    with concrete preferences (marks uncertain lines with "(inferred)").
YOU MUST DO AFTER:
  - open -e CLAUDE.local.md  (or your editor) — fix anything wrong or too specific.

EOF

log "Stage 6 — Auto-filling CLAUDE.local.md from repo analysis..."

claude -p \
'You are filling in CLAUDE.local.md for a solo developer.
This file is gitignored and personal — it steers how YOU behave
specifically for this developer, not the team.

Read ALL of the following to infer their preferences:
- CLAUDE.md (their conventions and patterns)
- .claude/settings.json (their hooks and guardrails)
- .claude/skills/ (domains they care about)
- .cursor/rules/ (what they have protected and prioritised)
- The actual codebase — file structure, naming style, test patterns,
  commit message style (check git log if accessible), script style

Then write CLAUDE.local.md with these sections fully populated.
No placeholders. Every line must be a real, specific preference
inferred from what you found. If you are uncertain about something,
make a reasonable inference and mark it with (inferred) so the
developer can confirm or correct it.

# Verbosity
[How much explanation to give. Infer from: do they write terse or
verbose comments? Short or long commit messages? Prefer concise.]

# Response style
[Infer from code style: do they prefer direct answers, step-by-step
breakdowns, or just the code with minimal prose?]

# Never do
[Infer from: protected files in settings.json, guardrails in
.cursor/rules/index.mdc, conventions in CLAUDE.md.
List specific things to never do in this repo without asking.]

# Always do
[Infer from: PostToolUse hooks, testing rules, commit conventions.
List specific things to always do automatically.]

# Local environment
[Infer from: runner path if found, External SSD path patterns,
Xcode usage, any env-specific scripts or configs found.]

# Workflow preferences
[Infer from: CI setup, script naming, how tasks are organised.
E.g. always check runner before CI, always run alignment check
before release, etc. Include: when you prefer **Cursor Agents** vs **Claude Code CLI**
for this repo, if inferrable from context files or history.]

# Things to confirm with me before doing
[Infer from: PreToolUse hooks, protected file patterns, anything
that touches signing, distribution, or production.]

Write the file directly to CLAUDE.local.md.
After writing, print a summary of every preference you inferred
and the evidence that led to each inference.' \
  --model opus \
  --settings "$CLAUDE_CODE_OPUS_SESSION_SETTINGS" \
  --permission-mode auto \
  --allowedTools "Read,Write,Glob,Grep,Bash" \
  --max-turns 20 \
  2>&1 | tee -a "$LOG_FILE"

success "Stage 6 complete — CLAUDE.local.md auto-filled."
echo ""
echo -e "  ${YELLOW}Review CLAUDE.local.md and correct any (inferred) items.${NC}"
echo -e "  ${YELLOW}Open with: open -e CLAUDE.local.md${NC}"
fi

divider

# =============================================================================
# STAGE 7 — AGENTS.md generator
# =============================================================================

if run_phase 7; then

AGENTS_MD="$REPO_ROOT/AGENTS.md"
AGENTS_MARKER='<!-- repo-init-phase-7 v1 -->'

cat <<EOF

================================================================
PHASE 7 — AGENTS.md generator
================================================================
AUTOMATIC:
  - Claude Opus reads CLAUDE.md, .claude/settings.json, .claude/agents/,
    .cursor/rules/, and the repo structure, then writes AGENTS.md.
  - AGENTS.md is a brief (~30-line), agent-ready summary:
    stack, integration branch, test/lint commands, key files,
    and autonomy constraints specific to this repo.
  - Idempotent: skips if marker already present (set FORCE_AGENTS_MD=1 to overwrite).
YOU DO AFTER:
  - Review AGENTS.md and tweak any inferred constraints.
WHERE OUTPUT GOES:
  - AGENTS.md at repo root (committed; not gitignored)
DURATION:
  - ~3–8 minutes (tight Opus prompt).

EOF

if grep -qF "$AGENTS_MARKER" "$AGENTS_MD" 2>/dev/null && [[ "${FORCE_AGENTS_MD:-0}" != "1" ]]; then
  warn "AGENTS.md already has phase-7 marker — skipping (set FORCE_AGENTS_MD=1 to regenerate)."
else

# Regeneration overwrites AGENTS.md with only the three Opus sections — save the
# accumulated ## Review learnings bullets so they survive FORCE_AGENTS_MD=1.
SAVED_LEARNINGS=""
if [[ -f "$AGENTS_MD" ]]; then
  SAVED_LEARNINGS="$(python3 - "$AGENTS_MD" <<'PY'
import sys
out, in_sec = [], False
for line in open(sys.argv[1], encoding="utf-8").read().splitlines():
    if line.startswith("## "):
        in_sec = line.startswith("## Review learnings")
        continue
    if in_sec and line.startswith("- ") and "(none yet" not in line:
        out.append(line)
print("\n".join(out))
PY
)"
fi

log "Stage 7 — Generating AGENTS.md via Claude Opus..."

claude -p \
'You are writing AGENTS.md for this repository.
AGENTS.md is a brief, agent-ready summary read by autonomous agents
(Cursor Agents, Claude Code, Codex, etc.) before they start work.
It is NOT a copy of CLAUDE.md — it points agents to it and extracts
the facts an agent needs in the first 10 seconds.

Read these files to extract facts:
- CLAUDE.md               — conventions, stack, commands, do-not-touch list
- .claude/settings.json   — hooks and guarded file patterns
- .claude/agents/         — list what agents exist (filenames only)
- .cursor/rules/          — note which .mdc files exist (filenames only)
- CLAUDE.local.md         — if present, note personal guardrails relevant to agents
- .github/workflows/      — if present, note runner label (e.g. self-hosted, ubuntu-latest)

Then write AGENTS.md with EXACTLY this structure (fill every section;
no placeholders; use "none configured" when a command genuinely is not set up):

# <Repo name>  (use git remote or directory name)

> Read `CLAUDE.md` for full project conventions before acting.

## Quick reference
- **Stack:** <1-line description, e.g. "zsh/bash shell scripts, macOS .app bundle">
- **Integration branch:** `<branch>`
- **Test:** `<command or "none configured">`
- **Lint/build:** `<command or "none configured">`
- **CI runner:** `<runs-on label from .github/workflows/ or "none detected">`

## Key files (read before acting)
- `CLAUDE.md` — must-read conventions and workflow
(add 2–5 more lines; only files that actually exist in this repo)

## Autonomy constraints
- May push, merge, or open PRs when the user asks or when completing ship/PR; confirm before force-push or merging to main
- Do not commit secrets or production credentials
(add 2–4 repo-specific constraints extracted from CLAUDE.md protected
 sections, settings.json hooks, or .cursor/rules/index.mdc deny-list;
 be specific — name actual files/commands to avoid, not generic advice)

<!-- repo-init-phase-7 v1 -->

Rules for writing AGENTS.md:
- Total length: 25–40 lines. Never exceed 50.
- No section headers beyond the three above.
- No prose paragraphs — bullet points only.
- Do not reproduce command output, file contents, or long lists.
- Use backticks for all file paths, commands, and branch names.
- The autonomy constraints must be repo-specific, not generic.
- End the file with exactly: <!-- repo-init-phase-7 v1 -->

Write the file directly to AGENTS.md.
After writing, print one line: "AGENTS.md written (<N> lines)."' \
  --model opus \
  --settings "$CLAUDE_CODE_OPUS_SESSION_SETTINGS" \
  --permission-mode auto \
  --allowedTools "Read,Write,Glob,Grep,Bash" \
  --max-turns 12 \
  2>&1 | tee -a "$LOG_FILE"

# Opus writes only Quick reference / Key files / Autonomy constraints — restore the
# Codex review lane (and saved learnings) so regeneration never drops them.
if [[ -f "$AGENTS_MD" ]]; then
  write_agents_codex_learnings_append "$AGENTS_MD"
  if [[ -n "$SAVED_LEARNINGS" ]]; then
    python3 - "$AGENTS_MD" "$SAVED_LEARNINGS" <<'PY'
import sys
path, saved = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
placeholder = "- (none yet — weekly maintenance and post-review agent tasks populate this section)"
if placeholder in text:
    open(path, "w", encoding="utf-8").write(text.replace(placeholder, saved, 1))
PY
  fi
fi

fi

success "Stage 7 complete — AGENTS.md generated."
echo ""
echo -e "  ${YELLOW}Review AGENTS.md — check autonomy constraints are repo-specific.${NC}"
echo -e "  ${YELLOW}Open with: open -e AGENTS.md${NC}"
fi

divider

# =============================================================================
# DONE
# =============================================================================

echo -e "${BOLD}${GREEN}Setup complete.${NC}"
echo ""
if [[ "$SETUP_AI_CONTEXT_PHASES" != "all" ]]; then
  echo -e "${YELLOW}[notice]${NC} Partial run — phases executed this time: ${SETUP_AI_CONTEXT_PHASES}"
  echo "  The checklist below describes the full pipeline; some items may not apply until you run missing phases."
  echo ""
fi
echo -e "${BOLD}What you should do now (manual checklist):${NC}"
echo "  1) Review git diff — especially after Phase 4 auto-fixes."
echo "  2) Read .claude/crosscheck-report.md — decide which remaining notes to act on later."
echo "  3) Restart Cursor (required for MCP changes in Phase 5)."
echo "  4) Edit CLAUDE.local.md — remove or correct any (inferred) lines from Phase 6."
echo "  5) Review AGENTS.md — check autonomy constraints are repo-specific (Phase 7)."
echo "  6) crontab -e — weekly install strips legacy # ai-context-weekly-review lines for this repo; remove any other stray duplicates if you see them."
echo ""
echo "What was configured (files / services):"
echo ""
echo "  CLAUDE.md                           Claude Code always-on brain"
echo "  CLAUDE.local.md                     Personal overrides (auto-filled, Phase 6)"
echo "  AGENTS.md                           Agent-ready repo summary (auto-generated, Phase 7)"
echo "  .claude/settings.json               Hooks: lint, guard, runner check"
echo "  .claude/skills/                     On-demand domain knowledge"
echo "  .claude/skills/runner/SKILL.md      Runner start/status/logs"
echo "  .cursor/rules/index.mdc                      Cursor always-on project rules"
echo "  .cursor/rules/self-improvement.mdc           Auto-evolution rule"
echo "  .cursor/rules/cursor-agent-cli-workflow.mdc  Cursor vs Claude Code CLI + handoffs"
echo "  .cursor/rules/runner.mdc                     Runner awareness for Cursor (if detected)"
echo "  .cursor/rules/[domain].mdc          Dynamic context-triggered rules"
echo "  .claude/crosscheck-report.md        Conflict audit + fixes applied"
echo "  .claude/weekly-maintenance.sh       Self-running weekly script"
echo "  context7 MCP                        Live docs (Claude Code + Cursor)"
echo "  GitHub MCP                          PRs, issues, Actions (self-hosted runners still use GitHub API)"
echo "  Playwright MCP                      Browser automation via MCP (first run may download browsers)"
echo "  Memory MCP                          Persistent cross-repo memory"
echo ""
echo -e "${BOLD}Two things left:${NC}"
echo ""
echo "  1) Review CLAUDE.local.md — Claude auto-filled it from your repo."
echo "     Correct any (inferred) items that don't match your preferences."
echo "     Open with: open -e CLAUDE.local.md"
echo ""
echo "  2) Review AGENTS.md — Claude generated it from your repo context."
echo "     Check the autonomy constraints are specific to this repo (not generic)."
echo "     Open with: open -e AGENTS.md"
echo ""
echo "Rerun anytime:         ./repo-init.sh"
echo "Run weekly now:        bash $WEEKLY_SCRIPT"
echo "Full log:              $LOG_FILE"
