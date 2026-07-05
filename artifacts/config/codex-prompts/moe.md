Toggle item-level multi-model fusion (MoE) for Codex sessions (all Codex
sessions run through the fusion proxy via the `fusion` model provider in
~/.codex/config.toml).

Run this shell command (argument may be on / off / toggle / status; default toggle):

    ai-harness-fusion ${1:-toggle} codex-moe

Report to the user in 1-2 short lines: the new mode, and that it applies from
the next step of this session. "moe" = every step fans out to GPT-5.5 and
GLM-5.2 candidates and a synthesizer (GPT-5.5) merges them; "passthrough" =
fully transparent single-model behavior (requests go byte-faithfully to the
ChatGPT backend with your own login). Sessions started before the fusion
provider was configured need a restart to pick it up.
