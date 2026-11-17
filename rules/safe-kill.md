---
rule: safe-kill
when: The agent is about to kill processes by name or pattern.
threshold: 0.5
---
Kill by pattern with `safe-kill PATTERN` — it brackets the pattern so it never matches its own argv, never signals itself or an ancestor, and refuses when the only match is one of those (`--list` first, `--signal`, `--wait`). Never `pkill -f`: it has repeatedly killed the shell or the agent's own server.
