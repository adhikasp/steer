---
rule: file-not-chat
when: The agent is about to record a decision, a durable fact, or a task — something the user will need again later.
threshold: 0.55
---
Write it into the file that owns the fact (decision log, project note, todo line) and link it, then mention the path in one line. A decision that lives only in a chat transcript is lost; the reply is a receipt, not the record.
