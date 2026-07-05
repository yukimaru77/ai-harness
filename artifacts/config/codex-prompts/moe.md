Toggle item-level multi-model fusion (MoE) for the codex-moe fusion proxy.

Run this shell command (argument may be on / off / toggle / status; default toggle):

    ai-harness-fusion ${1:-toggle} codex-moe

Then check whether this session goes through the fusion proxy:

    codex_provider_check() { printf '%s\n' "${CODEX_HOME:-none}"; }; codex_provider_check

Report to the user in 1-2 short lines:
- If CODEX_HOME contains ".agent-fusion/codex", this session runs through the
  fusion proxy and the new mode applies from the next step ("moe" = every step
  fans out to GPT/GLM candidates and a synthesizer merges them; "passthrough" =
  normal single model).
- Otherwise the global mode was switched but THIS session cannot be rerouted;
  tell the user to start `codex-moe` in a terminal.
