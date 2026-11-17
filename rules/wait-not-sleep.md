---
rule: wait-not-sleep
when: The agent is about to wait for a server, port, file, lock, or another agent to become ready.
threshold: 0.5
---
Use a bounded wait helper instead of a sleep loop: `wait-for --timeout N -- <cmd>` (or `--port`, `--file`, `--grep`, `--absent`), or `hc wait` when the thing being waited on is another agent. One check, then report the result. Never chain `sleep N` retries: they burn wall-clock and hide a failure that a bounded wait would surface immediately.
