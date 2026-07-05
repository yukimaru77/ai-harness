---
description: Toggle item-level multi-model fusion (MoE) — takes effect in claude-moe sessions
allowed-tools: Bash(ai-harness-fusion:*), Bash(echo:*)
---

Run these two commands with the Bash tool:
1. `ai-harness-fusion ${ARGUMENTS:-toggle}` (valid: on / off / toggle / status; default toggle)
2. `echo "${ANTHROPIC_BASE_URL:-direct}"`

Then report to the user in 1-2 short lines:

- If command 2 printed a URL containing `8400`: this session runs through the
  fusion proxy, so the new mode applies **from the very next step of this
  conversation**. State the mode: "moe" = every step fans out to all candidate
  models and a synthesizer merges them; "passthrough" = normal single model.
- Otherwise: the global fusion mode was still switched, but THIS session talks
  directly to its provider and cannot be rerouted mid-flight (the backend URL
  is fixed at process start). Tell the user to run `claude-moe` in a terminal
  to get a session where the mode takes effect.
