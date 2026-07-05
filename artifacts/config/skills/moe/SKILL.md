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

All Claude and Codex sessions run through the fusion proxies by default
(claude: ANTHROPIC_BASE_URL in ~/.claude/settings.json; codex: the `fusion`
model provider in ~/.codex/config.toml), so the new mode applies from the
next step. Passthrough mode is byte-transparent to the real provider.
Only sessions started BEFORE that wiring existed need a restart — for Claude
you can verify with `echo "${ANTHROPIC_BASE_URL:-direct}"` (8400 = proxied).

Report in 1-2 lines: the new mode and that it applies from the next step.
Diagnosis if anything misbehaves: `ai-harness-fusion diag all`.
