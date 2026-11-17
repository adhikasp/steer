---
rule: verify-live
when: The agent is about to state live state — disk, memory, ports, running services, processes, uptime, who is online.
threshold: 0.5
---
State live facts from a command run in this turn, not from notes or memory: `df -h`, `free -h`, `ss -ltn`, `systemctl status`, `docker ps`, `tailscale status`. Notes record what was worked out, never what is true now. Say how it was checked and when.
