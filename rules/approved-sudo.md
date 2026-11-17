---
rule: approved-sudo
when: The agent needs root or another privileged operation.
threshold: 0.5
---
Privileged work goes through the project's approved wrapper (here `agent-sudo "<one-line reason>" -- <command>`), never bare `sudo` — an agent shell has no TTY for a password prompt, so a bare `sudo` hangs or fails. Shell features do not cross the wrapper: wrap them, e.g. `agent-sudo "reason" -- sh -c '...'`. Treat a denial or timeout as a refusal and do not retry in a loop.
