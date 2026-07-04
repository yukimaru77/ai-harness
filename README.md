# AI Harness

This directory contains the installed AI coding harness and deliverable artifacts for `/Users/nonaka/Downloads/AI_HARNESS_IMPLEMENTATION_SPEC_JA.md`.

## Commands

Source `/Users/nonaka/.config/ai-harness/shell.sh` or open a new shell, then use:

- `claude`: native Claude Code via a TRANSPARENT wrapper (telemetry only, no flags or env changes; real binary = `paths.env` `REAL_CLAUDE`).
- `claude-codex`: Claude Code through CLIProxyAPI and OpenAI/Codex OAuth, GPT-5.5, high effort. Uses dedicated config dir `~/.config/ai-harness/claude-codex`.
- `claude-glm`: Claude Code through Z.AI Anthropic-compatible GLM-5.2, high effort. Uses dedicated config dir `~/.config/ai-harness/claude-glm`.
- `codex`: Codex CLI through native Codex/OpenAI OAuth, GPT-5.5, high effort.
- `codex-glm`: Codex CLI through CLIProxyAPI to Z.AI GLM-5.2. Gated by `ai-harness-enable codex-glm` (accepted 2026-07-03).
- `opencode-codex`: OpenCode through native OpenCode OpenAI OAuth, GPT-5.5, high effort.
- `opencode-glm`: OpenCode through Z.AI Coding Plan GLM-5.2, high effort.
- `ai-auth`: safe auth/status/open/log helper, including `ai-auth rotate zai`.
- `ai-harness-doctor`: safe diagnostic helper.
- `ai-harness-rollback`: non-destructive rollback helper.
- `ai-harness-monitor`: one-shot health probe (also runs every 5 min via LaunchAgent `com.nonaka.ai-harness.monitor`).
- `ai-harness-stats`: telemetry analysis — per-route error rates, latency percentiles, upstream health, proxy restarts. See `OBSERVABILITY.md` for schemas, jq recipes, and the failure runbook.
- `ai-harness-bench`: same tiny prompt through all 7 routes, timed — the direct route-vs-route comparison (`--routes a,b` to subset, `--note` to label).

## Paths

- Runtime config: `/Users/nonaka/.config/ai-harness`
- Runtime share/logs/auth: `/Users/nonaka/.local/share/ai-harness`
- Wrappers: `/Users/nonaka/.local/share/ai-harness/bin`
- CLIProxyAPI binary: `/Users/nonaka/.local/libexec/ai-harness/cli-proxy-api`
- CLIProxyAPI starter: `/Users/nonaka/.local/libexec/ai-harness/cli-proxy-api-start`
- LaunchAgent: `/Users/nonaka/Library/LaunchAgents/com.nonaka.ai-harness.cliproxy.plist`
- Test report: `/Users/nonaka/.local/share/ai-harness/reports/TEST_REPORT.md`
- Artifacts bundle: `/Users/nonaka/.local/share/ai-harness/artifacts`

## Verification

```bash
ai-auth status
ai-harness-doctor
```

Z.AI key rotation helper:

```bash
ai-auth rotate zai
```

The latest completed acceptance report is:

```bash
/Users/nonaka/.local/share/ai-harness/reports/TEST_REPORT.md
```

## Install, Rollback, Uninstall

Idempotent check/reapply:

```bash
/Users/nonaka/.local/share/ai-harness/install.sh --dry-run
/Users/nonaka/.local/share/ai-harness/install.sh
```

Rollback:

```bash
/Users/nonaka/.local/share/ai-harness/rollback.sh
```

Uninstall without credential deletion:

```bash
/Users/nonaka/.local/share/ai-harness/uninstall.sh
```

Credential deletion is intentionally not part of the default uninstall path.

## Notes

OpenCode noninteractive `run` uses a per-run temporary `OPENCODE_DB` unless the user explicitly sets one. This avoids local SQLite contention during parallel acceptance tests. Stateful `--continue`, `--session`, and `--fork` require a persistent user-provided `OPENCODE_DB`.
