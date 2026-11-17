---
rule: delegate-survey
when: The agent is about to perform a broad read-only survey expected to take more than roughly twenty tool calls.
threshold: 0.6
---
Fan a broad survey out to two or three parallel `explore` subagents with an exact scope each, then keep only the synthesis. Each child should write long findings to a file and send the path. One parent walking sixty reads serially is the slowest way to answer the same question.
