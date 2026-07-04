# AI Harness

Multi-provider harness for coding agents: run Claude Code, Codex CLI, and
OpenCode against their native providers, OpenAI/Codex OAuth via a local
reverse proxy (CLIProxyAPI), and Z.AI GLM — with per-invocation tracing,
health monitoring, and cross-route benchmarking built in
(see `OBSERVABILITY.md`).

## Quick start (new machine)

```bash
git clone https://github.com/yukimaru77/ai-harness.git ~/.local/share/ai-harness
cd ~/.local/share/ai-harness
./install.sh        # pick agents: claude / codex / opencode, GLM yes/no
```

Then run any AI coding agent in this directory and tell it:

> Read docs/AGENT_SETUP.md and set up the AI harness on this machine
> according to setup-selection.json. Never display API keys or tokens.

The agent installs CLIs, the proxy, LaunchAgents, and walks you through the
logins. GLM routes need a GLM Coding Plan API key:
<https://z.ai/manage-apikey/apikey-list> (you paste it into a hidden prompt,
never into the chat).

On an already-installed machine, `./install.sh --check` verifies and repairs
files, permissions, symlinks, and LaunchAgents.

Stuck, or found a bug? Open a detailed issue at
<https://github.com/yukimaru77/ai-harness/issues> — include your
`setup-selection.json`, OS/CLI versions, the exact error (with all keys and
tokens redacted), and `ai-harness-stats --errors` output.

## Commands

Source `/Users/nonaka/.config/ai-harness/shell.sh` or open a new shell, then use:

- `claude` / `codex`: OUT OF SCOPE for this repo — not wrapped, not monitored, not benched. Your daily-driver commands stay exactly as they are; this harness is responsible only for the commands below.
- `claude-fusion`: native Anthropic OAuth with a pinned profile — Opus 4.8 main, Sonnet 5 fast/background, effort high (`fusion-settings.json`). Independent of the plain `claude` settings.
- `claude-codex`: Claude Code through CLIProxyAPI and OpenAI/Codex OAuth, GPT-5.5, high effort. Shares your normal `~/.claude` environment (MCP, skills, sessions) — only the model/provider changes.
- `claude-glm`: Claude Code through Z.AI Anthropic-compatible GLM-5.2, high effort. Shares your normal `~/.claude` environment — only the model/provider changes.
- `codex-fusion`: Codex CLI through native Codex/OpenAI OAuth, GPT-5.5, xhigh effort, telemetry.
- `codex-glm`: Codex CLI through CLIProxyAPI to Z.AI GLM-5.2. Gated by `ai-harness-enable codex-glm` (accepted 2026-07-03).
- `opencode-codex`: OpenCode through native OpenCode OpenAI OAuth, GPT-5.5, high effort.
- `opencode-glm`: OpenCode through Z.AI Coding Plan GLM-5.2, high effort.
- `ai-auth`: safe auth/status/open/log helper, including `ai-auth rotate zai`.
- `ai-harness-doctor`: safe diagnostic helper.
- `ai-harness-rollback`: non-destructive rollback helper.
- `ai-harness-monitor`: one-shot health probe (also runs every 5 min via LaunchAgent `com.nonaka.ai-harness.monitor`).
- `ai-harness-stats`: telemetry analysis — per-route error rates, latency percentiles, upstream health, proxy restarts. See `OBSERVABILITY.md` for schemas, jq recipes, and the failure runbook.
- `ai-harness-bench`: same tiny prompt through all 7 routes, timed — the direct route-vs-route comparison (`--routes a,b` to subset, `--note` to label).
- `ai-harness-agent`: cc-switch-style skill/MCP selection for the harness routes. Central store `~/.agents/skills` → symlink selection `~/.agent-fusion/skills` (default: NOTHING selected — harness routes see no skills and no MCP servers). `list` / `add <skill>` / `remove <skill>` / `mcp` (edit `~/.agent-fusion/mcp.json`) / `sync`. The user's normal `~/.claude` and `~/.codex` keep their full skill/MCP setup.

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
