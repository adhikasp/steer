# steer

Inject the one harness rule that applies to what the agent is about to do — and nothing else.

Agents forget rules. A `AGENTS.md` full of "use `safe-kill`, not `pkill -f`" is read once and then
buried under 40 turns of tool output, so the rule loses to habit. `steer` turns each rule into a
**trigger** and asks a decision model, on every prompt, which one is about to happen:

```
pick      safe-kill  p=0.99  (382 ms, $0.00005, google/gemini-decision-1)
```

The winning rule's body is appended to the turn as one short block. If nothing applies, nothing is
injected — no chatter, no "no rule found" line.

```
<steer rule="safe-kill" confidence="0.99">
HARNESS RULE (auto-injected for this turn — follow it over routine habit):
Kill by pattern with `safe-kill PATTERN` — … never `pkill -f`.
</steer>
```

## Why a decision model and not keywords

Measured on 24 behavioural prompts (12 written first, 12 held-out paraphrases) and 18 ordinary ones:

| trigger | prompts it was written from | held-out paraphrases | false fires |
|---|---|---|---|
| keyword regex | 12/12 | **2/12** | 0/18 |
| Decisions API (`choice` over the rules) | 11/12 | **10/12** | 0/18 |

Regex triggers only fire on the exact phrasing they were written from ("stop that runaway vite
worker" and "how full is the btrfs volume" both miss). The Decisions API returns a calibrated
probability per rule in one pass — 0.35–0.65 s, ~$0.00005 per prompt with a 10-rule catalog.

`steer` is deliberately the narrow version of this idea: **rules only**, one winner, one line. It
does not try to route notes or docs — that is a different catalog with a different failure mode.

## Install

```bash
git clone https://github.com/adhikasp/steer ~/Workspace/steer
cd ~/Workspace/steer
export OPENROUTER_API_KEY=sk-or-v1-...     # written to ~/.config/steer/env, mode 600
./install.sh                                # CLI + rules + opencode plugin + Claude hook
```

`install.sh` is idempotent and never prints the key. It seeds `~/.config/steer/rules/` only when that
directory is empty, so your edits survive re-installs; `~/.claude/settings.json` is backed up before
the hook entry is added, and the entry is not duplicated.

Environment:

| variable | default | meaning |
|---|---|---|
| `OPENROUTER_API_KEY` / `STEER_API_KEY` | — | key, read from env or `~/.config/steer/env` |
| `STEER_RULES` | `~/.config/steer/rules` | rule directory (recursive `*.md`) |
| `STEER_MODEL` | `google/gemini-decision-1` | any Decisions API model |
| `STEER_THRESHOLD` | `0.5` | global probability floor; a rule may override it |
| `STEER_TIMEOUT` | `4` | seconds before the call is abandoned (fail-open) |
| `STEER_TTL` | `900` | seconds to suppress re-injecting the same rule for the same prompt |
| `STEER_NO_LOG` | unset | set to skip `~/.local/state/steer/log.jsonl` |

The key and the `STEER_MODEL` / `STEER_THRESHOLD` / `STEER_TIMEOUT` / `STEER_TTL` settings can all live
in `~/.config/steer/env` as `KEY=VALUE` lines, which is how a machine picks its model without editing a
shell profile (the process environment still wins). `STEER_RULES`, `STEER_STATE`, `STEER_ENV_FILE` and
`STEER_BIN` are paths for tests and adapters and are env-only.

## Rule files

One markdown file per rule, front matter plus the text to inject. Any file under the rules directory
is loaded; subdirectories are fine.

```markdown
---
rule: safe-kill
when: The agent is about to kill processes by name or pattern.
threshold: 0.5          # optional, default STEER_THRESHOLD
enabled: true           # optional
---
Kill by pattern with `safe-kill PATTERN` — it never signals itself or an ancestor. Never `pkill -f`.
```

- `rule` — slug, `[A-Za-z0-9_-]{1,64}`, unique. `none` is reserved.
- `when` — the trigger, written as a *condition*, not a topic. This is the text the model scores.
- body — injected verbatim when the rule wins. Keep it to one or two sentences; every rule is one
  more instruction competing for attention.

Ten starter rules ship in `rules/`. Replace them.

## Commands

```bash
steer rules                     # what is loaded, from where
steer lint                      # validate the catalog (exit 1 on problems)
steer eval "kill the stuck worker"   # dry run: rule + probability + latency + cost
steer eval --json "..."         # machine readable
echo '{"prompt":"..."}' | steer inject           # what an adapter runs
echo '{"prompt":"..."}' | steer inject --claude  # Claude Code hook payload
```

`inject` is **fail-open**: no key, no network, a timeout, an unknown answer — it prints nothing and
exits 0, because a router must never be able to block a turn. Every call (including skips) appends a
line to `~/.local/state/steer/log.jsonl` with the pick, probability, latency, cost and whether it
injected, so the hit rate is measurable rather than felt.

## Adapters

- **opencode 2.x** — `adapters/opencode/steer.js`, symlinked to `~/.config/opencode/plugins/steer.js`.
  Hooks `session.hook("context")`, caches per message id so a tool loop injects once.
- **Claude Code** — `adapters/claude/steer-hook.sh` as a `UserPromptSubmit` hook; prints
  `hookSpecificOutput.additionalContext`.

Both are thin: all logic (catalog, scoring, threshold, logging, duplicate suppression) lives in the
one CLI, so a third harness is a ten-line adapter.

## Scope, honestly

Injection helps where a rule is **not already habitual**, and is noise where it is. In a four-pair A/B
with live agents, a "browse, not curl" rule flipped `webfetch` to the browser tool, and a `safe-kill`
rule moved the agent from `ps | grep` to `safe-kill --list`; a "wait, don't sleep" rule changed
nothing because the agent already followed it. So: keep the catalog small, keep rules only for
behaviours that actually fail, and judge the change with a before/after error rate rather than a
feeling. `steer eval` and the log are there for exactly that.

MIT.
