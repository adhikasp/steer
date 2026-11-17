#!/usr/bin/env bash
# steer for Claude Code — UserPromptSubmit hook.
#
# Claude Code sends {"session_id","transcript_path","prompt",...} on stdin. `steer inject
# --claude` prints the hookSpecificOutput.additionalContext JSON, or nothing when no rule
# applies. Never fails the turn: a missing key or a timeout exits 0 silently.
#
# Install: copy/symlink to ~/.claude/hooks/steer.sh and add to ~/.claude/settings.json
#   "UserPromptSubmit": [ { "hooks": [ { "type": "command",
#       "command": "bash ~/.claude/hooks/steer.sh", "timeout": 10 } ] } ]
set -uo pipefail
BIN="${STEER_BIN:-$HOME/.local/bin/steer}"
[ -x "$BIN" ] || exit 0
exec "$BIN" inject --claude
