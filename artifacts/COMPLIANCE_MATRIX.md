# AI Harness Compliance Matrix

Date: 2026-06-26 JST

Source spec: `/Users/nonaka/Downloads/AI_HARNESS_IMPLEMENTATION_SPEC_JA.md`

Status legend:

- `PASS`: current-state evidence satisfies the requirement.
- `BLOCKED`: intentionally waiting for explicit user action.
- `RESIDUAL`: implemented with a documented caveat or external mismatch.
- `PARTIAL`: useful work exists, but the spec is not fully proven.

## Top-Level Requirements

| Spec Area | Status | Evidence |
|---|---:|---|
| Preflight OS/shell/real CLI paths/versions recorded | PASS | `TEST_REPORT.md`; `ai-harness-doctor` shows Darwin, bash, real Claude/Codex/OpenCode paths and versions. |
| Timestamped backups before changes | PASS | `/Users/nonaka/.config/ai-harness/backups/20260625-231939`; `/Users/nonaka/.config/ai-harness/backups/critical-20260625-232016`. |
| No CC Switch style shared config rewriting | PASS | Dedicated harness config files and wrappers; no launch-time global profile rewrite. |
| Parallel-safe command separation | PASS | Dedicated Claude config dirs, Codex profile files, OpenCode `OPENCODE_CONFIG`, per-run OpenCode DB for noninteractive `run`. |
| No secrets in reports/log summaries/permanent config | PASS | `ai-auth logs` outputs summaries only; report/artifact/permanent-config scans found no live key outside the private secret file/auth store. |
| Fixed versions, no auto-latest | PASS | CLIProxyAPI pinned at `v7.2.39` source with local `7.2.39-ai-harness.3` binary and checksums. |
| No silent model fallback | PASS | Wrapper/config pin exact models; OpenCode wrong model and non-high variant exit `64`; Claude fallback arrays empty. |
| Final report includes versions/checksums/tests/risks/rollback | PASS | `TEST_REPORT.md`, `README.md`, `ROLLBACK.md`, `SECURITY_NOTES.md`, `artifacts/vendor/checksums.sha256`. |
| Public wrapper commands available | PASS | `~/.local/bin` links to the harness wrappers after pathfix backup `~/.config/ai-harness/backups/pathfix-20260626-082702`; `command -v` resolves `claude-codex`, `claude-glm`, `codex-glm`, `opencode-codex`, `opencode-glm`, `ai-auth`, and `ai-harness-doctor`. |

## Commands

| Command | Status | Evidence |
|---|---:|---|
| `claude` | PASS | Smoke prompt and tool-call edit test passed; native Claude OAuth ok. |
| `claude-codex` | PASS | Smoke prompt and tool-call edit test passed; routes through CLIProxyAPI. |
| `claude-glm` | PASS | Smoke prompt and tool-call edit test passed; Z.AI key present. |
| `codex` | PASS | Smoke prompt and tool-call edit test passed; streaming repair verified. |
| `codex-glm` | BLOCKED | Wrapper exists and intentionally refuses until explicit Z.AI Coding Plan/Codex CLI compatibility acceptance. |
| `opencode-codex` | PASS | Now routes through native OpenCode OpenAI OAuth with `openai/gpt-5.5 --variant high`; native-route smoke returned `OPENCODE-CODEX-NATIVE-ROUTE-PASS`. |
| `opencode-glm` | PASS | Smoke prompt and tool-call edit test passed; direct Z.AI Coding Plan config. |
| `ai-auth` | PASS | Required subcommands present; `status` and `logs` verified. |
| `ai-harness-doctor` | PASS | Safe diagnostic output verified, including residual checks for `codex-glm` gate, Z.AI rotation reminder, deleted Codex log handles, and Codex `gpt-5.5` catalog context. |
| `ai-harness-rollback` | PASS | `--dry-run` verified; real execution intentionally not run to avoid rolling back active environment. |

## CLIProxyAPI

| Requirement | Status | Evidence |
|---|---:|---|
| Single user service process | PASS | LaunchAgent `com.nonaka.ai-harness.cliproxy` runs the harness starter, which launches one configured CLIProxyAPI process. |
| Local-only bind | PASS | `host: "127.0.0.1"`, `port: 8317`. |
| Writable single auth dir | PASS | `auth-dir: "/Users/nonaka/.local/share/ai-harness/cliproxy/auth"`. |
| OAuth files not copied between stores | PASS | CLIProxyAPI, native Codex, and native OpenCode auth stores remain separate. `ai-auth status` is the unified management view; tokens are not copied between stores. |
| Refresh workers limited | PASS | `auth-auto-refresh-workers: 1`. |
| Commit/version/checksum fixed | PASS | Source commit, release SHA, local `7.2.39-ai-harness.3` binary SHA, starter SHA, and Management Center SHA in `TEST_REPORT.md` and `vendor/build-info.txt`. |
| Codex refresh singleflight | PASS | Package-level `singleflight.Group`, SHA-256 hex credential key, concurrent deduplication test, helper key test, and `go test -race ./internal/auth/codex` pass. |
| Wrapper does not auto-start another proxy | PASS | Wrapper scan showed no CLIProxyAPI/bootstrap invocation in client wrappers. |
| Streaming `/v1/responses` works for Codex | PASS | Local patch plus regression tests and live stream check; rebuilt into `7.2.39-ai-harness.3`. |
| Broad upstream test suite clean | PASS | Antigravity stale reasoning replay bug fixed after Oracle review; `go test ./internal/runtime/executor ./sdk/api/handlers/openai ./sdk/api/handlers -count=1` passes. |

## Auth

| Requirement | Status | Evidence |
|---|---:|---|
| Anthropic OAuth stays native Claude | PASS | `ai-auth status`: Claude native OAuth ok. |
| OpenAI/Codex auth centrally visible | PASS | `ai-auth status` reports CLIProxyAPI OAuth, Codex native OAuth, and OpenCode OpenAI auth without token values. `codex` and `opencode-codex` intentionally avoid CLIProxyAPI. |
| Z.AI key stored once in harness secrets | PASS | `~/.config/ai-harness/secrets/zai-coding.key`, mode `600`; permanent CLIProxyAPI config uses `__ZAI_CODING_KEY__` and the service starter injects the key only into a temporary runtime config. Replacement key was installed on 2026-06-26 and verified with `claude-glm` and `opencode-glm`. |
| Pasted key removed from local files | RESIDUAL | Exact file scan is clean after redacting Claude/Codex histories, deleting malformed Codex log DB files, and installing the replacement Z.AI key. Provider-side deletion/revocation of the old exposed key and closing/restarting the related Codex app or VM process holding deleted log handles remain user actions. |
| CLIProxyAPI Management Center key | PASS | Local 401 was traced to a trailing newline copied by `pbcopy < cliproxy-management.key`; the key file was normalized without a trailing newline, recopied with `printf %s`, and authenticated read-only management API checks returned HTTP 200. |
| `ai-auth` central management | PASS | `status`, `login claude`, `login openai`, `open`, `open zai`, `rotate zai`, `logs`, `doctor` implemented. |
| Token values hidden | PASS | `ai-auth status` shows metadata only; `ai-auth logs` summary scan passed. |

## Models, Reasoning, Context

| Requirement | Status | Evidence |
|---|---:|---|
| Claude Opus 4.8 high, 1M setting | PASS | Claude native settings: `claude-opus-4-8[1m]`, `effortLevel=high`. |
| Claude Codex high | PASS | Claude Codex settings: `oauth-gpt-5.5[1m]`, `effortLevel=high`; upstream note documented. |
| Claude GLM high, 1M setting | PASS | Claude GLM settings: `glm-5.2[1m]`, `effortLevel=high`. |
| Codex GPT high | PASS | Codex profile: `model=gpt-5.5`, `model_reasoning_effort=high`, `plan_mode_reasoning_effort=high`. |
| Codex GPT 400K/250K policy | RESIDUAL | Config says `400000/250000`; Codex v0.142 source clamps `gpt-5.5` to catalog `max_context_window=272000`. Oracle advised keeping known `gpt-5.5` metadata instead of switching to an unknown proxy alias escape. |
| GLM thinking/high | PASS | Direct Z.AI/OpenCode GLM config and the gated CLIProxyAPI GLM route include thinking enabled/high. |
| OpenCode high variant | PASS | Wrappers inject/deduplicate `--variant high`; configs define high variants. |

## Acceptance Tests

| Test Area | Status | Evidence |
|---|---:|---|
| Basic command resolution | PASS | All harness commands resolve under `/Users/nonaka/.local/share/ai-harness/bin`. |
| Authentication | PASS | `ai-auth status` and service restart test passed. |
| Model identity | PASS | Configs, Codex catalog, OpenCode metadata, and Claude `--debug-file` dispatch lines verified model IDs without relying on model self-report. Claude slash commands were attempted noninteractively and returned `/status isn't available in this environment`; debug evidence is used instead. |
| Tool call edit tests | PASS | Six enabled routes fixed `calc.py`, added `unittest`, ran tests. |
| MCP configuration access | PASS | `claude mcp list`, `codex mcp list`, `opencode-codex mcp list`, and `opencode-glm mcp list` verified without copying/removing existing user MCP configuration. |
| MCP tool invocation by model route | PASS | Claude, `claude-codex`, `claude-glm`, `codex`, `opencode-codex`, and `opencode-glm` invoked `test-wait` successfully. Codex uses a narrow MCP allowlist with only `test-wait/wait` pre-approved. |
| Subagent or plan/build transition | PASS | Claude routes invoked the `general-purpose` subagent successfully; Codex invoked a multi-agent subagent via `collab_tool_call spawn_agent/wait/close_agent`; OpenCode Codex/GLM routes passed `--agent plan` and `--agent build`. |
| Reasoning high | PASS | Multi-layer settings and live run headers/metadata where available; payload override configured. |
| Context | RESIDUAL | Harness configs set requested policy; Codex CLI catalog mismatch recorded. |
| Parallel/refresh | PASS | Final 10-request parallel test passed; log scan found no refresh/auth/process errors. |
| Non-destructive existing customization | PASS | Existing Claude/Codex custom paths still present; rc source line count is one in `.bashrc` and `.zshrc`. |

## Deliverables

| Deliverable | Status | Evidence |
|---|---:|---|
| `install.sh` | PASS | Present, executable, `--dry-run` and real idempotent check passed. |
| `rollback.sh` | PASS | Present, executable, delegates to rollback helper. |
| `uninstall.sh` | PASS | Present, executable, keeps credentials by default. |
| `README.md` | PASS | Present. |
| `TEST_REPORT.md` | PASS | Present and updated. |
| `SECURITY_NOTES.md` | PASS | Present. |
| `ROLLBACK.md` | PASS | Present. |
| `wrappers/` artifact bundle | PASS | Present under `/Users/nonaka/.local/share/ai-harness/artifacts/wrappers`. |
| `config/` artifact bundle | PASS | Present under `/Users/nonaka/.local/share/ai-harness/artifacts/config`, including the restricted Codex `test-wait` MCP snippet. |
| Claude dedicated config dirs | PASS | `claude-codex` and `claude-glm` `.claude.json` files captured under `artifacts/config/claude-config-dirs`; `test-wait` MCP added via Claude MCP management command. |
| `service/` artifact bundle | PASS | LaunchAgent plist and CLIProxyAPI starter script present. |
| `vendor/` artifact bundle | PASS | Build info, applied patches, checksums present. |

## Wrapper Maintenance Dispatch

| Check | Status | Evidence |
|---|---:|---|
| `codex mcp list` passthrough | PASS | Wrapper no longer injects model profile into Codex MCP management command; MCP list succeeds. |
| Codex route policy | PASS | `codex` uses native Codex/OpenAI OAuth and verified `provider: openai`; `codex-glm` remains gated and is the only Codex route intended to use CLIProxyAPI/Z.AI. |
| `codex-glm --help` while gated | PASS | Help/maintenance command passes through before the acceptance gate. |
| `codex-glm exec` while gated | PASS | Still exits with the explicit Z.AI Coding Plan/Codex compatibility warning. |

## Remaining Gate

`codex-glm` remains the only intentionally incomplete route. It requires explicit user acceptance of the Z.AI Coding Plan/Codex CLI compatibility risk before enabling and testing.

Acceptance phrase requested from user:

```text
codex-glm を有効化してOK
```
