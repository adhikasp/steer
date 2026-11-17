// steer for opencode 2.x — inject the one harness rule that applies to this turn.
//
// Thin adapter: before each LLM call, the latest user message is scored against the rule
// catalog by the `steer` CLI (OpenRouter Decisions API), and the winning rule's body is
// appended to that message. The result is cached per message id, so a tool loop with five
// model calls (and every later turn) sees the same text.
//
// Fail-open: a missing key, a timeout, or a malformed answer means no injection, never a
// blocked turn. The CLI logs to ~/.local/state/steer/log.jsonl.
//
// Install: symlink into ~/.config/opencode/plugins/steer.js

import { spawnSync } from "node:child_process";
import { homedir } from "node:os";

const BIN = process.env.STEER_BIN || `${homedir()}/.local/bin/steer`;
const MARK = "<steer ";
const cache = new Map(); // messageID -> injected text ("" = nothing)

const textOf = (m) => m.content.filter((c) => c.type === "text").map((c) => c.text).join("\n");

function inject(prompt, sessionID) {
  const r = spawnSync(BIN, ["inject"], {
    input: JSON.stringify({ prompt, session_id: sessionID }),
    encoding: "utf8",
    timeout: Number(process.env.STEER_TIMEOUT_MS || 6000),
  });
  if (r.error || r.status !== 0) return "";
  return (r.stdout || "").trim();
}

export default {
  id: "adhikasp.steer",
  setup(api) {
    api.session.hook("context", async (ctx) => {
      const users = ctx.messages.filter((m) => m.role === "user");
      const last = users[users.length - 1];
      if (last && !cache.has(last.id) && !textOf(last).includes(MARK)) {
        cache.set(last.id, inject(textOf(last), ctx.sessionID));
      }
      for (const m of users) {
        const text = cache.get(m.id);
        if (text && !textOf(m).includes(MARK)) m.content.push({ type: "text", text });
      }
    });
  },
};
