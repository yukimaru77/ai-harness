# AGENT_SETUP.md — instructions for an AI agent reproducing this harness

You are an AI coding agent (Claude Code, Codex CLI, OpenCode, or similar).
Your job: set up this AI harness on the current machine so it matches the
reference deployment, honoring the component selection in
`setup-selection.json` (created by `./install.sh` in this repo; if it does not
exist, run `./install.sh` or ask the user which components they want).

Work autonomously. Ask the user only when a credential or an account-level
decision is genuinely required.

## Non-negotiable rules

1. NEVER print, echo, or log API keys, OAuth tokens, or their file contents.
2. Secrets live only in `~/.config/ai-harness/secrets/` (chmod 700 dir, 600 files).
3. Back up any pre-existing file before overwriting it (`<file>.bak-<date>`).
4. After every phase, verify before moving on. Finish with the checklist at
   the bottom.
5. macOS is the reference platform (launchd). On Linux, translate the two
   LaunchAgents to systemd user units with the same commands and intervals.

## What this harness is

Wrapper commands that route several coding agents through selected model
providers, with full observability (see `OBSERVABILITY.md`). The plain
`claude` and `codex` commands are OUT OF SCOPE: never wrap, monitor, modify,
or troubleshoot them from this repo — it owns only the commands below:

| Command | Requires selection | Route |
|---|---|---|
| `claude-fusion` | claude | native Anthropic OAuth, pinned profile: Opus 4.8 main / Sonnet 5 fast, effort high (the plain `claude` command is NEVER wrapped or symlinked — it is the user's daily driver) |
| `claude-codex` | claude + codex | Claude Code → CLIProxyAPI (localhost:8317) → OpenAI/Codex OAuth, model `oauth-gpt-5.5` |
| `claude-glm` | claude + glm | Claude Code → official Z.AI Anthropic-compatible endpoint (`https://api.z.ai/api/anthropic`), models via `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL` |
| `codex-fusion` | codex | native Codex CLI (ChatGPT OAuth), model gpt-5.5, xhigh effort, telemetry (plain `codex` likewise untouched) |
| `codex-glm` | codex + glm | Codex CLI → CLIProxyAPI → Z.AI GLM (`zai/glm-5.2`), gated by `ai-harness-enable codex-glm` |
| `opencode-codex` | opencode + codex | OpenCode native OpenAI provider |
| `opencode-glm` | opencode + glm | OpenCode native `zai-coding-plan` provider |

CLIProxyAPI is needed iff (claude AND codex) or (codex AND glm) — i.e. any
proxied route is selected.

## Target layout

```
~/.local/share/ai-harness/        # this repo, cloned here (or symlinked)
  bin/ lib/ artifacts/ docs/
~/.config/ai-harness/
  paths.env shell.sh
  secrets/{cliproxy-client.key,cliproxy-management.key,zai-coding.key}
  cliproxy/config.yaml            # rendered from artifacts/config/cliproxy/config.template.yaml
  claude/ opencode/ state/
~/.local/libexec/ai-harness/
  cli-proxy-api                   # binary (see Phase 3)
  cli-proxy-api-start             # from artifacts/service/
~/Library/LaunchAgents/
  com.<user>.ai-harness.cliproxy.plist   # from artifacts/service/, paths templated
  com.<user>.ai-harness.monitor.plist
~/.local/bin/                     # symlinks to bin/ wrappers
```

## Phase 0 — read the selection

`setup-selection.json` example:

```json
{"schema":1,"agents":{"claude":true,"codex":true,"opencode":true},"glm":true}
```

Derive the route list from the table above. Skip every step below that only
serves an unselected route.

## Phase 1 — repo placement and shell

1. If the repo is not already at `~/.local/share/ai-harness`, move/clone it there.
2. Create `~/.config/ai-harness/shell.sh`:
   ```bash
   #!/usr/bin/env bash
   case ":$PATH:" in
     *":$HOME/.local/share/ai-harness/bin:"*) ;;
     *) export PATH="$HOME/.local/share/ai-harness/bin:$PATH" ;;
   esac
   ```
3. Append to `~/.bashrc` and `~/.zshrc` (idempotently):
   `[ -f "$HOME/.config/ai-harness/shell.sh" ] && . "$HOME/.config/ai-harness/shell.sh"`
4. Create `~/.config/ai-harness/paths.env` with the REAL binary paths on this
   machine (`command -v` after installing the selected CLIs):
   ```
   AI_HARNESS_HOME=<home>/.config/ai-harness
   AI_HARNESS_SHARE=<home>/.local/share/ai-harness
   AI_HARNESS_LIBEXEC=<home>/.local/libexec/ai-harness
   REAL_CLAUDE=<path to claude binary>
   REAL_CODEX=<path to codex binary>
   REAL_OPENCODE=<path to opencode binary>
   CLIPROXY_URL=http://127.0.0.1:8317
   ```
   Install missing selected CLIs first (brew/npm per each tool's docs).
5. Symlink the selected wrappers plus `ai-auth`, `ai-harness-*` from
   `~/.local/bin/` to `bin/` (see the symlink list in `install.sh --check`).

## Phase 2 — secrets

Create `~/.config/ai-harness/secrets/` (700):

- `cliproxy-client.key` — generate: `openssl rand -hex 32` (600). Only needed
  if CLIProxyAPI is needed.
- `cliproxy-management.key` — same.
- `zai-coding.key` — only if `glm` is selected. Ask the user to create a
  **GLM Coding Plan** API key at <https://z.ai/manage-apikey/apikey-list> and
  paste it via a hidden prompt (`ai-auth rotate zai` does exactly this once
  the wrappers are linked — prefer it).

## Phase 3 — CLIProxyAPI (only if a proxied route is selected)

1. Download the latest release binary for this OS/arch from
   <https://github.com/router-for-me/CLIProxyAPI/releases> into
   `~/.local/libexec/ai-harness/cli-proxy-api` (chmod 755).
   The reference deployment ran v7.2.39 plus the three patches in
   `artifacts/vendor/*.patch` (codex SSE handling, refresh single-flight,
   antigravity reasoning replay). Newer upstream releases include equivalent
   fixes; only build from source with those patches if you must pin v7.2.39.
2. Render `~/.config/ai-harness/cliproxy/config.yaml` from
   `artifacts/config/cliproxy/config.template.yaml`:
   - `__MANAGEMENT_KEY__` → contents of `cliproxy-management.key`
   - `__LOCAL_CLIENT_KEY__` → contents of `cliproxy-client.key`
   - LEAVE `__ZAI_CODING_KEY__` as-is (rendered at service start by
     `cli-proxy-api-start`). If `glm` is NOT selected, delete the
     `openai-compatibility` block and create an empty `zai-coding.key` anyway
     (the starter requires the file; alternatively adapt the starter).
   - chmod 600.
3. Install `artifacts/service/cli-proxy-api-start` to
   `~/.local/libexec/ai-harness/` (chmod 700).
4. Install both plists from `artifacts/service/` into `~/Library/LaunchAgents/`,
   replacing every `/Users/nonaka` with this user's home and `com.nonaka.` with
   `com.<this user>.`. Then `launchctl bootstrap gui/$(id -u) <plist>` each.
5. Verify: `curl -fsS -H "Authorization: Bearer $(cat ~/.config/ai-harness/secrets/cliproxy-client.key)" http://127.0.0.1:8317/v1/models` returns JSON.

## Phase 4 — provider auth (per selection)

- claude: `claude` → complete the native Anthropic login (`/login` or
  `claude auth login` depending on version).
- codex native: `codex login` (ChatGPT OAuth).
- codex OAuth **inside CLIProxyAPI** (needed for `claude-codex`):
  `ai-auth login openai` — opens a browser, registers the credential in the
  proxy's auth dir.
- opencode: `opencode auth login` / `opencode providers login openai`, and the
  `zai-coding-plan` provider key if glm is selected (OpenCode reads
  `ZAI_CODING_API_KEY` from the wrapper, so usually nothing extra is needed).
- codex-glm gate: run `ai-harness-enable codex-glm` and let the USER type
  ACCEPT (do not auto-accept: it is an explicit risk acknowledgment).

## Phase 5 — per-agent config

- Claude settings files are already in `artifacts/config/claude/`; copy to
  `~/.config/ai-harness/claude/`.
- Skill/MCP selection (cc-switch style): run `ai-harness-agent sync` to create
  `~/.agent-fusion/` — `skills/` (symlink selection from the `~/.agents/skills`
  central store; default empty), `mcp.json` (default: no servers), `claude/`
  (CLAUDE_CONFIG_DIR for claude-* routes; shares the user's OAuth via a
  `.credentials.json` symlink and mirrors `CLAUDE.md`), `codex/` (CODEX_HOME
  for codex-* routes; shares `auth.json` via symlink), `xdg/opencode/`
  (XDG_CONFIG_HOME for opencode routes). Harness routes therefore see ONLY the
  selected skills/MCP; the user's normal `~/.claude`/`~/.codex` are untouched.
  Select skills with `ai-harness-agent add <name>`; MCP servers by editing
  `~/.agent-fusion/mcp.json`.
- Codex profile: copy `artifacts/config/codex/glm.config.toml` to
  `~/.codex/glm.config.toml` (only if codex+glm).
- OpenCode configs: copy `artifacts/config/opencode/{codex,glm}.json` to
  `~/.config/ai-harness/opencode/`.
- IMPORTANT model-name rule learned in production: model names with a `[1m]`
  suffix are ONLY valid via `ANTHROPIC_DEFAULT_*_MODEL` mapping, never as a
  direct `--model`/settings model value. The shipped wrappers already encode
  this — do not "simplify" them.

## Phase 5.5 — skill / MCP selection (ASK THE USER)

The harness routes see NO skills and NO MCP servers by default. Do not decide
for the user — enumerate and ask:

1. Run `ai-harness-agent list`. It shows every skill in the `~/.agents/skills`
   store and every MCP-server candidate from the user's `~/.claude.json`, each
   marked `[selected]` or `[ ]`.
2. Present the COMPLETE list to the user and ask, item by item (or as one
   checklist), which skills and which MCP servers the harness routes should
   get. Ask about every candidate — do not skip or preselect.
3. Apply the answers with `ai-harness-agent add <skill>` /
   `ai-harness-agent mcp-add <server>` (remove with `remove` / `mcp-remove`),
   then `ai-harness-agent sync`.
4. Show `ai-harness-agent list` output back to the user as confirmation.

The user can also do this themselves later: `ai-harness-agent select` is an
interactive y/n walk-through of every item. Whenever the user asks "what
skills/MCP do the harness routes have?", answer from `ai-harness-agent list`.

## Phase 5.7 — fusion proxies (optional; claude+codex for claude-moe, codex+glm for codex-moe)

Item-level multi-model fusion (MoE). ONE daemon serves one proxy instance per
config file in `~/.config/ai-harness/fusion/*.json` — to add another proxy
later, drop a new JSON there (choose a free port, protocol
`anthropic`|`responses`, any candidate mix incl. `{"model":..,"count":N}`)
and restart the fusion LaunchAgent. No code changes.

1. Install `artifacts/service/fusion-api` to
   `~/.local/libexec/ai-harness/fusion-api` (chmod 755).
2. Copy `artifacts/config/fusion/*.json` to `~/.config/ai-harness/fusion/`.
   Policy: codex-moe candidates are GPT/GLM only — never route Claude models
   through the Codex harness.
3. Install the `com.<user>.ai-harness.fusion` plist, bootstrap, then verify
   `curl http://127.0.0.1:8400/health` and `:8401/health`.
4. Claude candidate needs the Claude account registered in CLIProxyAPI:
   `ai-auth login anthropic`, and `disable-claude-cloak-mode: false` in the
   cliproxy config (otherwise Anthropic answers 429 to proxied traffic).
5. Mode switches: `/moe` is installed ONCE per CLI — slash command
   `artifacts/config/claude/commands/moe.md` → `~/.claude/commands/moe.md`,
   Codex custom prompt `artifacts/config/codex-prompts/moe.md` →
   `~/.codex/prompts/moe.md` (a prompt file is additive; it does NOT wrap the
   plain binaries). `ai-harness-agent sync` symlinks both into the isolated
   moe-session homes automatically. CLI alternative:
   `ai-harness-fusion on|off <instance>`.
6. Codex discovers skills (CODEX_HOME/skills), not prompts, from natural
   language: install `artifacts/config/skills/moe/` into `~/.agents/skills/moe`
   and symlink it into `~/.codex/skills/moe` so "moe を試して" works without
   typing /moe. (Claude needs nothing extra: commands are model-visible.)
7. Verify with `ai-harness-fusion diag all` — every line must be PASS.

## Phase 6 — verify (all selected routes)

```bash
./install.sh --check          # structural check: files, perms, symlinks, agents
ai-auth status                # every selected credential shows as present/ok
ai-harness-doctor             # end-to-end diagnostic
ai-harness-monitor            # one probe run; inspect ~/.local/share/ai-harness/obs/health.jsonl
ai-harness-bench --routes <selected,routes> --note "initial setup"
```

Every benched route must print OK. If one fails, follow the runbook in
`OBSERVABILITY.md` (it maps each failure signature to its cause), fix, rerun.

## Phase 7 — report

Tell the user: which routes are live, where telemetry lands (`obs/`), the two
LaunchAgents' names, and that `ai-harness-stats` / `ai-harness-bench` exist.
Do not include any secret material in the report.

## If you get stuck or find a bug

**First ask the user for permission** — e.g. "May I file an issue on the
ai-harness repo with the (redacted) details?" — and show them what you intend
to post. Filing an issue publishes text to a public repository, so never do
it unasked. If they agree, file it at
<https://github.com/yukimaru77/ai-harness/issues>
(e.g. `gh issue create -R yukimaru77/ai-harness`) with:

- which Phase and step failed, and the selection from `setup-selection.json`
- OS / arch, versions of the involved CLIs (`claude --version`, etc.)
- the exact error output — **redact every key, token, and Authorization
  header before pasting** (the wrappers' obs redaction does not apply to
  text you copy manually)
- relevant telemetry: `ai-harness-stats --errors` output and the matching
  `obs/events.jsonl` lines (already redacted by design)
- what you tried from the `OBSERVABILITY.md` runbook and the result

Then continue with any remaining phases that do not depend on the blocked
step, and tell the user about the filed issue (or, if they declined, hand
them the prepared issue text so they can post it themselves).
