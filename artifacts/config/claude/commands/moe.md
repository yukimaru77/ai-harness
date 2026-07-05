---
description: Toggle item-level multi-model fusion (MoE) for this fusion-proxy session
allowed-tools: Bash(ai-harness-fusion:*)
---

Run `ai-harness-fusion ${ARGUMENTS:-toggle}` with the Bash tool
(valid arguments: on / off / toggle / status; default is toggle).

Then tell the user in one short line which fusion mode is now active and what
it means: "moe" = every following step fans out to all candidate models and a
synthesizer merges them; "passthrough" = normal single-model behavior.
This only has an effect in sessions started via `claude-moe` (the fusion
proxy); in other sessions, say so instead of implying it changed anything.
