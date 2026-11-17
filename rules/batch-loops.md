---
rule: batch-loops
when: The agent is about to process a list of many items one at a time, one turn or one tool call per item.
threshold: 0.6
---
Put loops over items in one script that reports progress at 25/50/100% and prints a final summary. Never spend one turn per item: it multiplies latency, hides partial failure, and makes the run impossible to resume.
