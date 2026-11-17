#!/usr/bin/env bash
# Offline tests: catalog parsing, fail-open behaviour, adapter payload shapes. No API key needed.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STEER="$REPO/steer"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export STEER_RULES="$TMP/rules" STEER_STATE="$TMP/state" STEER_ENV_FILE="$TMP/env"
mkdir -p "$STEER_RULES"
fail=0
ok() { printf '  ok   %s\n' "$*"; }
bad() {
	printf '  FAIL %s\n' "$*"
	fail=1
}

cat >"$STEER_RULES/a.md" <<'EOF'
---
rule: alpha
when: The agent is about to do the alpha thing.
---
ALPHA BODY
EOF
cat >"$STEER_RULES/b.md" <<'EOF'
---
rule: beta
when: The agent is about to do the beta thing.
threshold: 0.9
---
BETA BODY
EOF

# 1. catalog loads both rules with their thresholds
out=$(python3 "$STEER" rules 2>&1) && ok "rules: runs" || bad "rules: exit $?"
grep -q 'alpha' <<<"$out" && grep -q '0.9' <<<"$out" && ok "rules: lists alpha and beta threshold 0.9" || bad "rules: missing entries"

# 2. lint passes, then fails on a broken rule
python3 "$STEER" lint >/dev/null 2>&1 && ok "lint: valid catalog" || bad "lint: false error"
printf '%s\n' '---' 'when: no slug here' '---' 'body' >"$STEER_RULES/broken.md"
python3 "$STEER" lint >/dev/null 2>&1 && bad "lint: missed a rule without a slug" || ok "lint: rejects a rule without a slug"
rm "$STEER_RULES/broken.md"

# 3. fail-open: no key -> no output, exit 0
out=$(printf '{"prompt":"kill the stuck worker"}' | env -u OPENROUTER_API_KEY -u STEER_API_KEY python3 "$STEER" inject)
[ -z "$out" ] && ok "inject: silent without a key" || bad "inject: emitted output without a key"

# 4. fail-open: unreachable endpoint -> no output, exit 0
out=$(
	printf '{"prompt":"kill the stuck worker"}' | STEER="$STEER" OPENROUTER_API_KEY=x STEER_TIMEOUT=0.3 \
		python3 - <<'PY'
import os, sys, importlib.util, importlib.machinery
loader = importlib.machinery.SourceFileLoader("steer", os.environ["STEER"])
m = importlib.util.module_from_spec(importlib.util.spec_from_loader("steer", loader)); loader.exec_module(m)
m.ENDPOINT = "http://127.0.0.1:9/dead"
sys.argv = ["steer", "inject"]
sys.exit(m.main())
PY
) 2>/dev/null
[ -z "$out" ] && ok "inject: silent when the endpoint is dead" || bad "inject: emitted output on failure"

# 5. fake a decision to check rendering, thresholds, Claude payload
cat >"$TMP/fake.py" <<'PY'
import importlib.util, importlib.machinery, json, os, sys
loader = importlib.machinery.SourceFileLoader("steer", os.environ["STEER"])
m = importlib.util.module_from_spec(importlib.util.spec_from_loader("steer", loader)); loader.exec_module(m)
pick, prob = os.environ["FAKE_PICK"], float(os.environ["FAKE_P"])
m.api_key = lambda: "x"
m.score = lambda *a, **k: {"pick": pick, "p": prob, "latency_ms": 1, "cost": 0.0, "tokens": 1, "model": "fake"}
sys.argv = ["steer", "inject"] + os.environ.get("FAKE_ARGS", "").split()
sys.stdin = __import__("io").StringIO('{"prompt":"kill the stuck worker"}')
sys.exit(m.main())
PY
out=$(STEER="$STEER" STEER_TTL=0 FAKE_PICK=alpha FAKE_P=0.99 python3 "$TMP/fake.py")
grep -q '<steer rule="alpha"' <<<"$out" && grep -q 'ALPHA BODY' <<<"$out" && ok "inject: renders the winning rule" || bad "inject: wrong render: $out"
out=$(STEER="$STEER" STEER_TTL=0 FAKE_PICK=beta FAKE_P=0.6 python3 "$TMP/fake.py")
[ -z "$out" ] && ok "inject: respects a per-rule threshold (0.6 < 0.9)" || bad "inject: ignored threshold"
out=$(STEER="$STEER" STEER_TTL=0 FAKE_PICK=none FAKE_P=0.97 python3 "$TMP/fake.py")
[ -z "$out" ] && ok "inject: stays silent on none" || bad "inject: injected on none"
out=$(STEER="$STEER" STEER_TTL=0 FAKE_PICK=alpha FAKE_P=0.99 FAKE_ARGS="--claude" python3 "$TMP/fake.py")
python3 - "$out" <<'PY' && ok "inject: valid Claude Code payload" || bad "inject: bad Claude payload"
import json, sys
d = json.loads(sys.argv[1])
assert d["hookSpecificOutput"]["hookEventName"] == "UserPromptSubmit"
assert "ALPHA BODY" in d["hookSpecificOutput"]["additionalContext"]
PY

# 6. duplicate suppression
out1=$(STEER="$STEER" STEER_TTL=900 FAKE_PICK=alpha FAKE_P=0.99 python3 "$TMP/fake.py")
out2=$(STEER="$STEER" STEER_TTL=900 FAKE_PICK=alpha FAKE_P=0.99 python3 "$TMP/fake.py")
[ -n "$out1" ] && [ -z "$out2" ] && ok "inject: suppresses the same rule twice (STEER_TTL)" || bad "inject: duplicate suppression"

# 7. adapters are syntactically sane
node --check "$REPO/adapters/opencode/steer.js" 2>/dev/null && ok "opencode adapter: parses" || bad "opencode adapter: syntax"
bash -n "$REPO/adapters/claude/steer-hook.sh" && ok "claude adapter: parses" || bad "claude adapter: syntax"
bash -n "$REPO/install.sh" && ok "install.sh: parses" || bad "install.sh: syntax"

echo
[ "$fail" = 0 ] && echo "all tests passed" || {
	echo "FAILURES"
	exit 1
}
