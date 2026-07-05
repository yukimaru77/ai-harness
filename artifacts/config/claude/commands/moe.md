---
description: Toggle item-level multi-model fusion (MoE) for Claude sessions (all sessions run through the fusion proxy)
allowed-tools: Bash(ai-harness-fusion:*), Bash(echo:*)
---

Run these two commands with the Bash tool:
1. `ai-harness-fusion ${ARGUMENTS:-toggle} claude-moe` (valid: on / off / toggle / status; default toggle)
2. `echo "${ANTHROPIC_BASE_URL:-direct}"`

Then report to the user in 1-2 short lines:

- If command 2 printed a URL containing `8400`: this session runs through the
  fusion proxy, so the new mode applies **from the very next step**. State the
  mode: "moe" = every step fans out to the candidate models (Opus 4.7 /
  GPT-5.5 / GLM-5.2) and the synthesizer (Fable 5) merges them;
  "passthrough" = fully transparent single-model behavior (requests go
  byte-faithfully to api.anthropic.com with your own login).
- Otherwise: this session was started before the proxy setting existed — the
  global mode was still switched; tell the user to restart `claude` so the
  session picks up the proxy.
