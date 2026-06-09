# Hermes Agent — Project Rules

## Code Review / Quality Gates

All code changes must pass a strict pre-commit review gate (Codex-style) before commit. Route every non-trivial feature through `/code-review` and iterate until all HOLDs are resolved before committing. Enforce all-or-nothing per-row gating on imports and atomic transactions on the first pass, not as a retrofit.

## Response Style / Constraints

Keep all responses concise. If a response would be long (diffs, logs, plans), split it across multiple messages and pause for the user to say "continue" — never dump a wall of output in one message.

## Git / Version Control

`git push` is deny-listed by the Bash guard — never attempt to push directly. Stage and commit, then stop and give the user the exact `git push origin <branch>` command to run manually.

## Workflow / Plan-then-Build

Do not begin implementation until the user confirms the patch is wanted. For plan-then-build cycles, finish and save the plan file before proceeding with any code changes. A plan interrupted mid-write leaves no recoverable artifact.

## Testing

Always use `scripts/run_tests.sh` — do not call `pytest` directly. See AGENTS.md Testing section for the full rationale (CI parity, credential isolation, hermetic subprocess model).

---

## Claude Insights Applied — 2026-06-10

- **Code Review / Quality Gates** — Added Codex-style pre-commit gate rule. Usage data: review loops caught load-bearing bugs (S1 dedup-key, import-gating gap) before merge.
- **Response Style** — Added chunking rule. Usage data: 8+ sessions were fully lost to output token-limit API errors.
- **Git** — Documented `git push` deny-list behavior. Usage data: recurring blocked-push friction degraded otherwise-fully-achieved sessions.
- **Workflow** — Added plan-before-implement gate. Usage data: premature implementation starts and lost plan files were repeated friction points.
- **Skills** — Created `.claude/skills/gated-ship/SKILL.md` encoding the design→implement→review→commit cycle as a reusable command.
- **Hooks** — Created `.claude/settings.json` with a pre-commit ruff lint hook.
- **AGENTS.md** — Appended `## Review learnings` section with Codex-facing bullets (marker: setup-ai-context-codex-learnings v1).
