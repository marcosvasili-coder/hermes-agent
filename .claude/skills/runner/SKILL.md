---
name: runner
description: Managing the local self-hosted GitHub Actions runner
---

# Runner Skill

## When to use
Before any task that triggers a GitHub Actions workflow.
When debugging CI failures. When the runner appears offline.

## Status check
pgrep -f 'Runner.Listener' > /dev/null && echo online || echo offline

## Start runner
cd /Users/marcosvasili/actions-runners/hermes-agent && ./run.sh
Run in a separate terminal — it stays in foreground.
Wait ~10 seconds after starting before triggering any workflow.

## Read latest log
ls -t /Users/marcosvasili/actions-runners/hermes-agent/_diag/*.log 2>/dev/null | head -1 | xargs tail -50

## Pre-CI checklist
1. Check status: pgrep -f 'Runner.Listener' > /dev/null && echo online || echo offline
2. If offline: open a new terminal and run: cd /Users/marcosvasili/actions-runners/hermes-agent && ./run.sh
3. Wait 10 seconds
4. Confirm online: pgrep -f 'Runner.Listener' > /dev/null && echo online || echo offline
5. Proceed with the workflow-triggering task

## Gotchas
- Runner runs in the foreground — needs its own terminal tab
- Never close the runner terminal while a job is running
- Runner must be online BEFORE pushing commits that trigger workflows
- If a job hangs, read the latest log for the real error
