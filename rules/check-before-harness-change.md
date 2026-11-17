---
rule: check-before-harness-change
when: The agent is about to change agent instructions, hooks, permissions, or model/harness configuration.
threshold: 0.55
---
Read the current behaviour before changing it: run the scorecard / baseline measurement, read the actual config and the transcript evidence, and state what should move. A harness change without a before-number is a guess, and these changes are expensive to A/B later.
