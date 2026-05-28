# BugBot Guidance

Shell scripts in this repo must follow the local runner conventions:

- New bash scripts use `#!/usr/bin/env bash` and `set -euo pipefail`; zsh scripts keep `#!/usr/bin/env zsh`.
- Quote variable expansions, especially `"$VAR"` and path arguments.
- Keep `scripts/check-runner-singletons.sh` and `Self Hosted Runners.app/Contents/Resources/bundled/check_runner_singletons.sh` in lockstep when either changes.
- Do not edit protected app metadata or launcher assets without explicit maintainer confirmation: `*.plist`, `*.icns`, `Contents/MacOS/launcher`, `Contents/Info.plist`, and `Contents/PkgInfo`.