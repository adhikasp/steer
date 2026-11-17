#!/usr/bin/env bash
# Install steer on this machine: CLI, rules, key file, and the opencode + Claude Code adapters.
#
#   ./install.sh                 install everything it can find
#   ./install.sh --no-claude     skip the Claude Code hook
#   ./install.sh --no-opencode   skip the opencode plugin
#
# Never prints a key. Re-running is safe: rules are only seeded when the dir is empty,
# settings.json is backed up before it is touched, and every symlink is replaced idempotently.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
CONF_DIR="$HOME/.config/steer"
RULES_DIR="$CONF_DIR/rules"
ENV_FILE="$CONF_DIR/env"
OPENCODE_PLUGINS="$HOME/.config/opencode/plugins"
CLAUDE_DIR="$HOME/.claude"
DO_CLAUDE=1
DO_OPENCODE=1
for a in "$@"; do
	case "$a" in
	--no-claude) DO_CLAUDE=0 ;;
	--no-opencode) DO_OPENCODE=0 ;;
	-h | --help)
		sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	*)
		echo "unknown option: $a" >&2
		exit 2
		;;
	esac
done

say() { printf '  %s\n' "$*"; }

echo "steer -> $REPO"

mkdir -p "$BIN_DIR" "$CONF_DIR" "$RULES_DIR"
chmod +x "$REPO/steer" "$REPO/adapters/claude/steer-hook.sh"

# 1. CLI
ln -sfn "$REPO/steer" "$BIN_DIR/steer"
say "cli        $BIN_DIR/steer -> $REPO/steer"

# 2. rules — seed only when empty so local edits are never overwritten
if [ -z "$(find "$RULES_DIR" -name '*.md' -print -quit 2>/dev/null)" ]; then
	cp "$REPO"/rules/*.md "$RULES_DIR"/
	say "rules      seeded $(ls -1 "$RULES_DIR"/*.md | wc -l) example rule(s) into $RULES_DIR"
else
	say "rules      kept existing $(find "$RULES_DIR" -name '*.md' | wc -l) rule(s) in $RULES_DIR"
fi

# 3. key — OPENROUTER_API_KEY from the environment, written once, mode 600, never echoed
if [ -s "$ENV_FILE" ]; then
	say "key        $ENV_FILE (kept)"
elif [ -n "${OPENROUTER_API_KEY:-}" ]; then
	umask 077
	printf 'OPENROUTER_API_KEY=%s\n' "$OPENROUTER_API_KEY" >"$ENV_FILE"
	chmod 600 "$ENV_FILE"
	say "key        wrote $ENV_FILE (mode 600) from OPENROUTER_API_KEY"
else
	say "key        MISSING — export OPENROUTER_API_KEY and re-run, or create $ENV_FILE by hand"
fi

# 4. opencode plugin
if [ "$DO_OPENCODE" = 1 ] && [ -d "$OPENCODE_PLUGINS" ]; then
	ln -sfn "$REPO/adapters/opencode/steer.js" "$OPENCODE_PLUGINS/steer.js"
	say "opencode   $OPENCODE_PLUGINS/steer.js -> $REPO/adapters/opencode/steer.js"
fi

# 5. Claude Code hook + settings merge (backup first, no duplicate entries)
if [ "$DO_CLAUDE" = 1 ] && [ -d "$CLAUDE_DIR" ]; then
	mkdir -p "$CLAUDE_DIR/hooks"
	ln -sfn "$REPO/adapters/claude/steer-hook.sh" "$CLAUDE_DIR/hooks/steer.sh"
	python3 - "$CLAUDE_DIR/settings.json" <<'PY'
import json, shutil, sys, time, pathlib
p = pathlib.Path(sys.argv[1])
data = {}
if p.exists():
    data = json.loads(p.read_text() or "{}")
    shutil.copy2(p, p.with_suffix(f".json.bak-{time.strftime('%Y%m%d-%H%M%S')}"))
hooks = data.setdefault("hooks", {})
entry = hooks.setdefault("UserPromptSubmit", [])
cmd = 'bash "$HOME/.claude/hooks/steer.sh"'
already = any(h.get("command") == cmd for group in entry for h in group.get("hooks", []))
if not already:
    entry.append({"hooks": [{"type": "command", "command": cmd, "timeout": 10}]})
    p.write_text(json.dumps(data, indent=2) + "\n")
    print("  claude     added UserPromptSubmit hook to", p)
else:
    print("  claude     UserPromptSubmit hook already present in", p)
PY
fi

# 6. verify
echo
if "$BIN_DIR/steer" lint; then
	echo "  ok         rule catalog valid"
else
	echo "  warn       rule catalog has problems (see above)" >&2
fi

echo
echo "next:"
echo "  steer eval \"kill the stuck python worker\"   # dry run, no injection"
echo "  steer rules                                 # what is loaded from where"
echo "  log: ~/.local/state/steer/log.jsonl"
