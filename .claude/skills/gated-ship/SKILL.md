---
name: gated-ship
description: Design, implement, review, commit; user runs the push.
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [macos, linux]
metadata:
  hermes:
    tags: [workflow, review, git, codex]
    category: development
---

# Gated Ship Skill

Runs the full design→verify→implement→review→commit cycle with a human gate before push. Never attempts `git push` — that is deny-listed; it stops and prints the exact command instead.

## When to Use

Use for any non-trivial feature, bug fix, or refactor where you want to enforce the project's gated-commit workflow end-to-end.

## Prerequisites

- A confirmed design or plan (written and saved as a file)
- Working test suite (`scripts/run_tests.sh` passes on current HEAD)

## How to Run

Invoke `/gated-ship` (or describe the task). Claude will walk through the cycle below and stop at the push gate.

## Quick Reference

| Step | Gate | Blocker |
|------|------|---------|
| Verify design | file:line evidence | Any unverified assumption |
| Implement | minimal diff | Scope creep |
| Test | `scripts/run_tests.sh` | Any failure |
| Review | `/code-review` APPROVE | Any open HOLD |
| Diff approval | User confirms staged diff | User reject |
| Commit | clean commit | — |
| Push | **USER runs manually** | deny-listed |

## Procedure

1. Read the plan or ask the user to confirm the change scope in one sentence.
2. Validate every design assumption against live source — cite `file:line` evidence. Never infer; misidentified subsystems waste the entire implementation pass.
3. Implement. Keep the diff minimal and reviewable; no unrelated cleanups.
4. Run `scripts/run_tests.sh` — all tests must pass before proceeding.
5. Run `/code-review`. Parse every HOLD into a tracked task; fix each one; re-run until APPROVE with tests still green.
6. Run `git diff --staged` and present it to the user. Wait for explicit approval before committing.
7. Commit with a clear, descriptive message.
8. **Stop.** Print: `git push origin <branch>` — never run it yourself.

## Pitfalls

- Do not commit before tests pass — a broken commit blocks the review loop.
- Do not skip the review gate for "small" changes; HOLDs have caught real blockers in the past.
- Do not attempt `git push` — the Bash guard will deny it and leave the session in a broken state.
- If the plan file is missing, write and save it first; a plan interrupted mid-write is unrecoverable.

## Verification

- All tests pass via `scripts/run_tests.sh`
- `/code-review` returned APPROVE with no open HOLDs
- User confirmed the staged diff
- Commit exists locally
- Push command printed to user; push not yet run
