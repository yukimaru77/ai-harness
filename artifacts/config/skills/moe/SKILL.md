---
name: moe
description: Toggle item-level multi-model fusion (MoE) for ai-harness fusion-proxy sessions (claude-moe / codex-moe). Use when the user says "moe", "MoE", "fusion mode", or asks to turn multi-model fusion on/off or check its status.
---

# moe — item-level multi-model fusion toggle

Switch the ai-harness fusion proxy between "moe" (every step fans out to all
candidate models in parallel and a synthesizer merges them) and "passthrough"
(normal single model).

Run with the shell tool (argument: on / off / toggle / status; default toggle):

    ai-harness-fusion <arg> codex-moe    # in Codex
    ai-harness-fusion <arg> claude-moe   # in Claude Code

Then check whether THIS session goes through the fusion proxy:
- Codex: `echo "${CODEX_HOME:-none}"` — contains ".agent-fusion/codex" = proxied.
- Claude: `echo "${ANTHROPIC_BASE_URL:-direct}"` — contains "8400" = proxied.

Report in 1-2 lines: the new mode, and whether it applies to this session
(proxied = from the next step) or only to future `codex-moe` / `claude-moe`
sessions (a running session's backend URL cannot be changed mid-flight — in
that case tell the user to start `codex-moe` / `claude-moe`).
Diagnosis if anything misbehaves: `ai-harness-fusion diag all`.
