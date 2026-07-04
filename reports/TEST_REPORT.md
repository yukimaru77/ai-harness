# AI Harness TEST_REPORT

Date: 2026-06-26 JST

## Scope

Implemented and tested the harness requested by `/Users/nonaka/Downloads/AI_HARNESS_IMPLEMENTATION_SPEC_JA.md`.
Secrets are intentionally not recorded in this report.

## Deliverable Bundle

Created artifact bundle at `/Users/nonaka/.local/share/ai-harness/artifacts`.

Top-level deliverables:

- `install.sh`: present, executable, idempotent check/reapply script, `--dry-run` verified.
- `rollback.sh`: present, executable, delegates to `ai-harness-rollback`.
- `uninstall.sh`: present, executable, keeps credentials by default.
- `README.md`: present.
- `SECURITY_NOTES.md`: present.
- `ROLLBACK.md`: present.
- `TEST_REPORT.md`: present.
- `COMPLIANCE_MATRIX.md`: present.

Artifact subdirectories:

- `wrappers/`: all seven primary wrappers plus `ai-auth`, `ai-harness-doctor`, `ai-harness-rollback`.
- `config/claude`: three Claude settings files.
- `config/claude-config-dirs`: dedicated `.claude.json` files for `claude-codex` and `claude-glm`, including the `test-wait` MCP registered by Claude's MCP management command.
- `config/codex`: two Codex profile files plus restricted `test-wait` MCP evidence.
- `config/opencode`: two OpenCode config files.
- `config/cliproxy`: CLIProxyAPI template config with placeholders only.
- `service`: LaunchAgent plist and CLIProxyAPI starter script.
- `vendor`: CLIProxyAPI build info, applied patches, and checksums.

Compliance matrix:

- `/Users/nonaka/.local/share/ai-harness/reports/COMPLIANCE_MATRIX.md`
- `/Users/nonaka/.local/share/ai-harness/artifacts/COMPLIANCE_MATRIX.md`

Verification:

- `bash -n install.sh rollback.sh uninstall.sh`: PASS.
- `install.sh --dry-run`: PASS.
- `install.sh`: PASS, no auth regression.
- `ai-harness-rollback --dry-run`: PASS; verified quarantine plan without moving files.
- Artifact/permanent-config secret scan: only placeholder `__ZAI_CODING_KEY__` in templates matched the API-key pattern; no live key was found outside the private secret file/auth store.

## Management Command Checks

`ai-auth` required subcommands:

- `status`: PASS. Shows CLIProxyAPI state, model list, Codex OAuth status/update/success/failure counts, Claude native OAuth state, and Z.AI key presence without token values.
- `login claude`: PRESENT. Delegates to the real Claude Code auth login.
- `login openai`: PRESENT. Uses CLIProxyAPI Management API auth URL and polls state.
- `login codex`: PRESENT. Delegates to native Codex login for the normal `codex` route.
- `login opencode-openai`: PRESENT. Delegates to native OpenCode OpenAI provider login for the normal `opencode-codex` route.
- `open`: PRESENT. Opens local management UI at `127.0.0.1`.
- `open zai`: PRESENT. Opens the Z.AI API Keys management page.
- `rotate zai`: PRESENT. Opens the Z.AI API Keys management page, accepts the replacement key via hidden terminal input, atomically updates `zai-coding.key`, and restarts the local CLIProxyAPI LaunchAgent.
- `logs`: PASS. Now prints recent CLIProxyAPI error summaries only; request and response bodies are omitted.
- `doctor`: PRESENT. Delegates to `ai-harness-doctor`.

`ai-auth logs` redaction/summary check:

- Secret-pattern scan of `ai-auth logs` output: PASS.
- Output includes timestamp/method/URL/status summaries only.

## Installed Commands

All commands resolve through `/Users/nonaka/.local/share/ai-harness/bin` after sourcing `/Users/nonaka/.config/ai-harness/shell.sh`.

- `claude`: PASS
- `claude-codex`: PASS
- `claude-glm`: PASS
- `codex`: PASS
- `codex-glm`: BLOCKED by explicit Z.AI Coding Plan/Codex compatibility acceptance gate
- `opencode-codex`: PASS
- `opencode-glm`: PASS
- `ai-auth`: PASS
- `ai-harness-doctor`: PASS
- `ai-harness-rollback`: PRESENT

`codex-glm` remains intentionally disabled until the user explicitly accepts the Z.AI Coding Plan/Codex CLI compatibility risk with `ai-harness-enable codex-glm`.

Maintenance dispatch check:

- `codex mcp list`: PASS after wrapper passthrough fix.
- `codex-glm --help`: PASS even while gated.
- `codex-glm exec`: still correctly blocked until explicit acceptance.

## Versions and Fixed Artifacts

- Claude Code real path: `/Users/nonaka/.local/share/claude/versions/2.1.179`
- Claude Code version: `2.1.179 (Claude Code)`
- Codex real path: `/opt/homebrew/bin/codex`
- Codex version: `codex-cli 0.142.0`
- OpenCode real path: `/Users/nonaka/.local/bin/opencode`
- OpenCode version: `local`
- CLIProxyAPI source tag: `v7.2.39`
- CLIProxyAPI source commit: `c4cf0fd3241afca8b63673bac7e0fc2e11ed9426`
- CLIProxyAPI installed version: `7.2.39-ai-harness.3`
- CLIProxyAPI installed commit label: `c4cf0fd3-local`
- CLIProxyAPI installed SHA-256: `182d37ef135ed98063586570dc32bd42b627faee57da1c3675dc50da2b4e2513`
- Original release binary backup: `/Users/nonaka/.local/libexec/ai-harness/cli-proxy-api.release-v7.2.39.20260626-002151.bak`
- Original release binary SHA-256: `18666393fbd53895945fa3dd2f0dbe6c9074e5c37d2a813342a61f3be6766bca`
- Previous local binary backup: `/Users/nonaka/.local/libexec/ai-harness/cli-proxy-api.pre-antigravity.3.20260626-023750.bak`
- Previous local binary SHA-256: `71e407415529ffe7d573ba0e98dbb48362c0fa81a91cc264c1186b5e6ad2e16a`
- Earlier local binary backup: `/Users/nonaka/.local/libexec/ai-harness/cli-proxy-api.pre-refreshhash.20260626-020416.bak`
- Earlier local binary SHA-256: `a5c8f9b672836978cd0102afc914f479d7bb5e7ee5895f45bf44798c14fedbee`
- Management Center version: `v1.17.6`, SHA-256 `268bf8d53021bd3afbb695b2cabb9780c4a9546ffa70202517e79380cd4b12f3`; `disable-auto-update-panel: true`.

## Authentication

- `ai-auth status`: PASS
- CLIProxyAPI: running
- OpenAI/Codex OAuth: active via CLIProxyAPI auth store
- Claude native OAuth: ok
- Z.AI Coding key: present
- Service restart: PASS. LaunchAgent restarted and `ai-auth status` still showed active OAuth and model list.
- Secrets mode: PASS. Harness key files and Codex OAuth JSON are mode `600`.
- Z.AI key injection: PASS. Oracle session `cliproxy-zai-key-config-secret` recommended keeping permanent config redacted and injecting from the private key file at service start. LaunchAgent now runs `cli-proxy-api-start`, permanent `config.yaml` contains `__ZAI_CODING_KEY__`, runtime temp config is mode `600` with randomized basename `config.yaml.<random>`, and `opencode-glm` passed a live prompt after restart.
- Local history redaction: PASS for file contents. Oracle sessions `harness-backup-history-secret-redaction` and `malformed-codex-log-sqlite-secret` reviewed remediation. Exact key occurrences in Claude/Codex JSON/JSONL history and harness backup copies were replaced with `[REDACTED_ZAI_API_KEY]` in 24 files; 18 JSON/JSONL files parsed successfully after redaction. A malformed Codex log SQLite family containing one remaining occurrence was deleted because it was a disposable corrupted log DB. Final exact file scan over harness backups, `~/.claude`, `~/.codex`, harness share, and permanent CLIProxy config reports `files_with_exact_secret=0`, `occurrences=0`.
- 2026-06-26 Z.AI key rotation: PASS locally. The user ran `ai-auth rotate zai`, the helper stored the replacement key in `~/.config/ai-harness/secrets/zai-coding.key`, and CLIProxyAPI was restarted. `ai-auth status` reported CLIProxyAPI running with `zai/glm-5.2`; `claude-glm --print` returned `CLAUDE-GLM-ROTATE-PASS`; `opencode-glm run` returned `OPENCODE-GLM-ROTATE-PASS`; exact scan for the new key outside private auth/secrets returned `files_with_exact_secret=0`, `occurrences=0`.
- CLIProxyAPI Management Center 401: resolved locally. `pbcopy < ~/.config/ai-harness/secrets/cliproxy-management.key` copied the trailing newline from the mode-600 key file, while CLIProxyAPI compares the provided management key byte-for-byte. The trailing newline was removed from `cliproxy-management.key`, the key was recopied with `printf %s`, and authenticated read-only management API checks returned HTTP 200 for `/v0/management/config`, `/v0/management/plugins`, and `/v0/management/auth-files`.
- 2026-06-26 PATH/public wrapper fix: PASS. `claude-codex`, `claude-glm`, `ai-auth`, and harness maintenance commands were not visible from the user's login shell because `~/.local/share/ai-harness/bin` was not on the login-shell PATH and several `~/.local/bin` entries were missing or stale. Existing stale public wrappers were backed up under `~/.config/ai-harness/backups/pathfix-20260626-082702`, and `~/.local/bin` now links to the harness wrappers. `command -v` resolves `claude-codex`, `claude-glm`, `codex-glm`, `opencode-codex`, `opencode-glm`, `ai-auth`, and `ai-harness-doctor`; short-name smoke tests returned `CLAUDE-CODEX-PATH-PASS` and `CLAUDE-GLM-PATH-PASS`.
- 2026-06-26 route policy correction: PASS. To minimize reverse-proxy blast radius, only `claude-codex` and gated `codex-glm` use CLIProxyAPI. `codex` now uses native Codex/OpenAI OAuth and verified `provider: openai` with `CODEX-NATIVE-ROUTE-PASS`. `opencode-codex` now uses native OpenCode OpenAI OAuth with `openai/gpt-5.5 --variant high` and returned `OPENCODE-CODEX-NATIVE-ROUTE-PASS`. `ai-auth status` centrally reports CLIProxyAPI OAuth, Codex native OAuth, OpenCode OpenAI auth, OpenCode Z.AI auth, Claude native OAuth, and the harness Z.AI key without token values.
- Residual local process note: one Apple Virtualization VM process still holds deleted `logs_2.sqlite*` file handles until the related Codex/app VM exits. Files are unlinked from the filesystem; close/restart Codex app or the related VM session to release the deleted inodes. The process was not killed automatically to avoid interrupting unrelated active work.
- Credential rotation status: replacement key is installed and verified locally, but provider-side deletion/revocation of the old exposed key in the Z.AI console still needs user confirmation.

## Models and Reasoning

- Claude native settings: `claude-opus-4-8[1m]`, `effortLevel=high`, no fallback model.
- Claude Codex settings: `oauth-gpt-5.5[1m]`, `effortLevel=high`, no fallback model. Upstream is still GPT-5.5 subscription path, not a real 1M upstream window.
- Claude GLM settings: `glm-5.2[1m]`, `effortLevel=high`, no fallback model.
- Codex GPT config: `model=gpt-5.5`, `model_provider=cliproxy`, `wire_api=responses`, `model_reasoning_effort=high`, `plan_mode_reasoning_effort=high`, configured context `400000`, auto compact `250000`.
- Codex CLI model catalog for `gpt-5.5`: supports `high`; reports `context_window=272000`, `max_context_window=272000`, `effective_context_window_percent=95`. This differs from the target upstream 400K assumption and is recorded as a residual metadata mismatch.
- Oracle session `ai-harness-codex-context-alias`: recommended not switching Codex to the proxy alias `oauth-gpt-5.5` as an unknown-model escape, because it would lose known GPT-5.5 metadata. After the route policy correction, normal `codex` execution stays on native `gpt-5.5` and verifies `provider: openai`; `codex-glm` remains the only Codex route that would use CLIProxyAPI after explicit acceptance.
- OpenCode Codex config: `cliproxy-codex/oauth-gpt-5.5`, model options `reasoningEffort=high`, variant `high`, limit `400000/128000`.
- OpenCode GLM config: `zai-coding-plan/glm-5.2`, thinking enabled, `reasoningEffort=high`, limit `1000000/131072`.
- CLIProxyAPI payload override: GPT Codex payload forces `reasoning.effort=high`; GLM OpenAI-compatible payload forces `thinking.type=enabled` and `reasoning_effort=high`.
- CLIProxyAPI permanent config: `debug: false`; `request-log` is not enabled; Z.AI key field is a placeholder and is rendered into a temporary mode-600 config only while the service runs.
- Claude `--debug-file` probes showed dispatch models: `claude-opus-4-8[1m]`, `oauth-gpt-5.5[1m]`, and `glm-5.2[1m]`. Noninteractive slash commands were attempted and returned `/status isn't available in this environment`.

## Functional Smoke Tests

Short non-interactive prompts passed:

- `claude`: `OK-CLAUDE-NATIVE`
- `claude-codex`: `OK-CLAUDE-CODEX`
- `claude-glm`: `OK-CLAUDE-GLM`
- `codex`: `OK-CODEX-META`
- `opencode-codex`: `OK-OPENCODE-CODEX`
- `opencode-glm`: `OK-OPENCODE-GLM`

`codex-glm` correctly refused to run until explicit acceptance.

## Tool Call / Edit Tests

Each passing route was tested in a temporary Git repository with `calc.py` initially returning `a - b`.
The harness was asked to read the file, fix the bug, add `test_calc.py` using Python `unittest`, run `python3 -m unittest -v`, and show a diff.

- `claude`: PASS, unittest OK.
- `claude-codex`: PASS, unittest OK.
- `claude-glm`: PASS, unittest OK.
- `codex`: PASS, unittest OK.
- `opencode-codex`: PASS, unittest OK.
- `opencode-glm`: PASS, unittest OK.
- `codex-glm`: NOT RUN because the explicit compatibility acceptance gate is still closed.

Earlier Codex tool test attempted `pytest` and failed because `pytest` was not installed. It was rerun with standard-library `unittest` and passed.

MCP tool invocation:

- `claude`: PASS. Invoked `mcp__test-wait__wait` with `seconds=0`, returned `MCP-WAIT-PASS`.
- `claude-codex`: PASS. Invoked `mcp__test-wait__wait` with `seconds=0`, returned `MCP-WAIT-PASS`.
- `claude-glm`: PASS. Invoked `mcp__test-wait__wait` with `seconds=0`, returned `MCP-WAIT-PASS`.
- `opencode-codex`: PASS. JSON output included `tool_use` for `test-wait_wait` with `seconds=0`, then returned `OPENCODE-CODEX-MCP-PASS`.
- `opencode-glm`: PASS. JSON output included `tool_use` for `test-wait_wait` with `seconds=0`, then returned `OPENCODE-GLM-MCP-PASS`.
- `codex`: PASS. `test-wait` was added to Codex MCP config with `enabled_tools = ["wait"]`, server default approval left at `prompt`, and only `tools.wait.approval_mode = "approve"`. `codex exec --json --sandbox read-only --skip-git-repo-check` emitted one completed `mcp_tool_call` for `server="test-wait"`, `tool="wait"`, `arguments={"seconds":0.1}`, then returned `CODEX-MCP-PASS`.

Codex MCP approval note:

- Initial Codex MCP run reached `mcp_tool_call server=test-wait tool=wait` but failed with `user cancelled MCP tool call`.
- Oracle session `ai-harness-codex-mcp-testwait-3`: recommended a narrow allowlist and per-tool approval, not broad MCP auto-approval.
- Applied only the `test-wait` section in `~/.codex/config.toml`; backed up the previous file at `/Users/nonaka/.config/ai-harness/backups/codex/config.toml.pre-test-wait.20260626-021101.bak`.
- Captured the restricted snippet at `/Users/nonaka/.local/share/ai-harness/artifacts/config/codex/test-wait-mcp.toml`.

Subagent invocation:

- `claude`: PASS. Invoked `general-purpose` subagent and returned `SUBAGENT-OUTER-PASS`.
- `claude-codex`: PASS. Invoked `general-purpose` subagent and returned `SUBAGENT-OUTER-PASS`.
- `claude-glm`: PASS. Invoked `general-purpose` subagent and returned `SUBAGENT-OUTER-PASS`.
- `opencode-codex --agent plan`: PASS, returned `OPENCODE-CODEX-PLAN-PASS`.
- `opencode-codex --agent build`: PASS, returned `OPENCODE-CODEX-BUILD-PASS`.
- `opencode-glm --agent plan`: PASS, returned `OPENCODE-GLM-PLAN-PASS`.
- `opencode-glm --agent build`: PASS, returned `OPENCODE-GLM-BUILD-PASS`.
- `codex`: PASS. Codex CLI does not expose a noninteractive `plan`/`build` subcommand, but the installed Codex has `multi_agent` stable/enabled. `codex exec --json --sandbox read-only --skip-git-repo-check` emitted `collab_tool_call` events for `spawn_agent`, `wait`, and `close_agent`; the child agent returned `SUBAGENT-INNER-PASS` and the parent returned `CODEX-SUBAGENT-OUTER-PASS`.
- Codex subagent JSONL evidence: `/Users/nonaka/.local/share/ai-harness/artifacts/tests/codex-subagent-test.jsonl`.

## CLIProxyAPI Streaming Repair

Initial issue:

- Raw non-stream `/v1/responses` via Codex OAuth completed.
- Streaming `/v1/responses` returned HTTP 200 but only one byte downstream and no `response.completed`.
- Codex CLI failed with `stream disconnected before completion: stream closed before response.completed`.

Research and consultation:

- Official/primary issue references checked: CLIProxyAPI issues around Codex Responses streaming and OpenAI Codex localhost behavior.
- Oracle session `cliproxy-codex-stream-empty-browser2`: agreed issue was likely CLIProxyAPI Codex streaming path.
- Oracle session `cliproxy-codex-stream-translator-empty`: recommended frame-oriented pass-through for Codex upstream SSE to OpenAI Responses clients.

Patch:

- Patched `internal/runtime/executor/codex_executor.go` in the pinned CLIProxyAPI source to forward Codex OpenAI Responses SSE as complete `event:`/`data:` frames.
- Added regression tests in `internal/runtime/executor/codex_executor_stream_output_test.go`.
- Installed local binary `7.2.39-ai-harness.3`.

Verification:

- `go test ./internal/runtime/executor -run 'TestCodexExecutorExecuteStream' -count=1`: PASS.
- `go test ./sdk/api/handlers/openai -run 'TestForwardResponsesStream|TestResponsesSSE' -count=1`: PASS.
- Live stream check: `response.completed` present.
- `codex exec ...`: PASS.
- Broader `go test ./internal/runtime/executor ./sdk/api/handlers/openai ./sdk/api/handlers -count=1`: PASS after the Antigravity replay repair below.

## CLIProxyAPI Antigravity Replay Repair

Issue:

- The broader upstream executor/handler test suite failed in `TestPrepareAntigravityGeminiReasoningReplayPayloadAppendsStaleThoughtSignatureWithoutNullParts`.
- Root cause was a stale thought-signature replay path that did not append a new part object when the cached part index was out of range; the test fixture also used a signature shorter than the cache normalization minimum.

Research and consultation:

- Oracle session `ai-harness-cliproxy-antigravit-test`: recommended resolving stale content indexes to the last model turn, appending stale part indexes to the existing parts array, and validating the broader suite.

Patch:

- Updated `internal/runtime/executor/antigravity_reasoning_replay.go` so missing thought-signature replay targets append `{thoughtSignature: ...}` as a part object instead of writing a nested property under a missing array element.
- Updated `internal/runtime/executor/antigravity_reasoning_replay_test.go` so the stale-signature fixture satisfies the cache minimum length.
- Captured patch at `/Users/nonaka/.local/share/ai-harness/artifacts/vendor/cliproxy-antigravity-reasoning-replay.patch`.
- Rebuilt and installed local binary `7.2.39-ai-harness.3`.

Verification:

- `go test ./internal/runtime/executor -run 'TestPrepareAntigravityGeminiReasoningReplayPayloadAppendsStaleThoughtSignatureWithoutNullParts|TestPrepareAntigravityGeminiReasoningReplayPayloadInjectsCachedToolPart|TestPrepareAntigravityGeminiReasoningReplayInsertsBeforeModelFunctionResponse|TestMergeAntigravityFunctionCallPartReplayMergesSignatureIntoExistingFunctionCall' -count=1`: PASS.
- `go test ./internal/runtime/executor ./sdk/api/handlers/openai ./sdk/api/handlers -count=1`: PASS.
- `ai-harness-doctor`: PASS after LaunchAgent restart and reports CLIProxyAPI `7.2.39-ai-harness.3`.

## CLIProxyAPI Codex Refresh Repair

Issue:

- The pinned source already used package-level `singleflight.Group` and passed concurrent refresh tests, but the singleflight key was the raw refresh token. The spec requires a hashed credential-derived key.

Research and consultation:

- Oracle session `ai-harness-completion-audit-mktemp-refresh-key`: recommended SHA-256 hex keying, preserving same-token deduplication without storing the raw token in the singleflight key, plus an explicit helper test.

Patch:

- Added `codexRefreshSingleflightKey(refreshToken)` using full SHA-256 hex.
- Changed `codexRefreshGroup.Do(...)` to use the hashed key.
- Added `TestCodexRefreshSingleflightKey_UsesSHA256Hex`.
- Rebuilt and installed local binary `7.2.39-ai-harness.3`.

Verification:

- `go test ./internal/auth/codex -count=1`: PASS.
- `go test -race ./internal/auth/codex -count=1`: PASS.
- `go test ./internal/runtime/executor -run 'TestCodexExecutorExecuteStream' -count=1`: PASS after rebuild.
- `ai-auth status` and `ai-harness-doctor`: PASS after LaunchAgent restart.

## OpenCode Wrapper Repairs

Issue 1:

- Passing `--variant high` to the wrapper produced OpenCode payload `variant=["high","high"]`.

Fix:

- `opencode-codex` and `opencode-glm` now normalize wrapper-owned singleton flags.
- Duplicate `--variant high` and fixed `--model` values are accepted and deduplicated.
- Non-high variants and wrong models exit with code `64`.

Issue 2:

- Parallel `opencode-codex run` initially failed with `database is locked`.

Research and consultation:

- Oracle session `opencode-parallel-database-locked`: identified OpenCode shared SQLite DB contention and recommended per-run `OPENCODE_DB` isolation for noninteractive runs.

Fix:

- `opencode-codex run` and `opencode-glm run` create a per-run temporary `OPENCODE_DB` unless the user explicitly provides one.
- Stateful flags `--continue`, `--session`, and `--fork` now require a persistent user-provided `OPENCODE_DB` instead of silently using an isolated DB.

Verification:

- `bash -n` for both wrappers: PASS.
- Duplicate `--variant high` smoke test: PASS.
- Non-high variant/wrong model rejection: PASS.
- Three parallel OpenCode requests: PASS, no `database is locked`.

## Parallel and Refresh

Final 10-request parallel test:

- 3 x `claude-codex`: PASS
- 4 x `codex`: PASS
- 3 x `opencode-codex`: PASS
- Overall: `parallel_rc=0`, `ok_count=10`

Log scan after the parallel run:

- `refresh_token_reused`: not found
- `invalid_grant`: not found
- `panic`: not found
- `duplicate process`: not found
- `database is locked` / `SQLITE_BUSY`: not found in OpenCode test stderr

Codex stderr still shows the user's existing `hook: Stop Failed` after successful responses. It did not prevent model output or tests.

## Non-Destructive Checks

- `.bashrc`: one harness source line.
- `.zshrc`: one harness source line.
- Existing Claude MCP/hooks/plugins paths remain present.
- Existing Codex config/hooks/plugins paths remain present.
- `claude mcp list`: PASS; existing MCP entries remain visible.
- `codex mcp list`: PASS; wrapper dispatch fixed and `test-wait` is enabled with only `wait` allowlisted.
- `codex update`, `codex app`, `codex app-server`, `codex remote-control`, and `codex mcp-server`: PASS fail-closed with exit `64`, preventing auto-update and route escape outside the pinned harness.
- `codex-glm update`, `codex-glm app`, `codex-glm app-server`, `codex-glm remote-control`, and `codex-glm mcp-server`: PASS fail-closed with exit `64`, even before the compatibility gate.
- `opencode-codex mcp list`: PASS; dedicated harness config shows `test-wait` connected without touching the user's default OpenCode config.
- `opencode-glm mcp list`: PASS; dedicated harness config shows `test-wait` connected without touching the user's default OpenCode config.
- OpenCode native OpenAI OAuth was not copied into the harness. `opencode-codex` uses OpenCode's native OpenAI OAuth; `opencode-glm` uses the Z.AI key.
- Runtime config and temporary debug/request logs do not contain active request logging.

## Checksums

- `~/.local/share/ai-harness/bin/ai-auth`: `4cf3e90e385eb7ea0715ca8064d64cde897544cc800413265dbe9eb83f7021b2`
- `~/.local/share/ai-harness/bin/ai-harness-doctor`: `91139a6b8b88d8d20feb30c9c4cc9e1c24d9e423e2a9c2c87a3ee5d85d83ac12`
- `~/.local/share/ai-harness/bin/ai-harness-enable`: `d9d758c17eb3b337a458a8809f10a1ddac7dbeb8617987d810589947e8212f5b`
- `~/.local/share/ai-harness/bin/ai-harness-rollback`: `24b20d434a6829d1d564be1835a53b2c0cd69ebdffa0a834912c89000eb228d7`
- `~/.local/share/ai-harness/bin/claude`: `a63a66576c10ed75979782489a255ce4e7eec0b001bf6149e27f71368d48248f`
- `~/.local/share/ai-harness/bin/claude-codex`: `3e37a77a3a9837ea608c522794a8cf6b8b184b1d6a3e37d87ee72341b878ad70`
- `~/.local/share/ai-harness/bin/claude-glm`: `abe163ed25daa2c59043f8ef3d613585d3b61efe5217b324ef249468aa2f1ae0`
- `~/.local/share/ai-harness/bin/codex`: `7d47a47dbdabd7ec46b518e6425eea0583262b384e2a65343860562dbd58477f`
- `~/.local/share/ai-harness/bin/codex-glm`: `c717f04d9d4a289ec500da7331b8ff44a967a23c8100f1344807167a8b8b5d9c`
- `~/.local/share/ai-harness/bin/opencode-codex`: `f9d82864310ed4adb6922a26a617b72e544a578f4279bb8e663b6224dc3cf674`
- `~/.local/share/ai-harness/bin/opencode-glm`: `228fe6f056a1b7ef22a8fa4c8d7c3c3f3d2f0728ce1a3c688b5c8a0ca314dcaa`
- `~/.local/libexec/ai-harness/cli-proxy-api`: `182d37ef135ed98063586570dc32bd42b627faee57da1c3675dc50da2b4e2513`
- `~/.local/share/ai-harness/install.sh`: `9a086f47065101bc36478602868a3e1d758eb4965d434f27330bd24f99e8eba1`
- `~/.local/libexec/ai-harness/cli-proxy-api-start`: `a9e746579a627e1cf1621f0227f1a9a5e7adfcbee9aa2b54fb5b56cbb4c350de`
- `~/Library/LaunchAgents/com.nonaka.ai-harness.cliproxy.plist`: `44125510347ef7e51bd34866b03d1cf2fe2f4fa6be27faf3b922ab3a4a8f3554`
- `~/.config/ai-harness/cliproxy/config.yaml`: `198c3a5bcf90d482c2c33777374de10c24a906411f7a71381ce13d3153fd7c77`
- `~/.config/ai-harness/opencode/codex.json`: `d043183e99d50f5d6347eae3a488998622ee822cbbb6fe2a593acef658c03616`
- `~/.config/ai-harness/opencode/glm.json`: `c85d3f4744dfee885660bacd64acfb3abb8c2ac14d792b00c965f281abe5c5d3`
- `~/.codex/oauth-gpt.config.toml`: `4c46d463bf5f56ecb26ba76a1b467ab8e3c9790466651ad6112df7f7ef275342`
- `~/.codex/glm.config.toml`: `bddea906285d5bdab88b848811f26ed9d9e86042e1c5860b53c6bd9929d66289`
- `~/.local/share/ai-harness/cliproxy/static/management.html`: `268bf8d53021bd3afbb695b2cabb9780c4a9546ffa70202517e79380cd4b12f3`
- `artifacts/vendor/cliproxy-codex-openai-responses-sse.patch`: `f43f2aa2ea39eb2ae059e842dc657708e67e49242b8133580d04e000d271235d`
- `artifacts/vendor/cliproxy-codex-refresh-singleflight-hash.patch`: `7dd66fba47bd81cc0115c627d3bdf54d3d51ab0bad875b6492cc028d7ec7d5ab`

## Rollback

Primary rollback command:

```bash
ai-harness-rollback
```

The rollback command unloads the LaunchAgent, removes harness PATH source lines from shell rc files, and moves wrapper/plist artifacts into a quarantine directory. Credentials and config are retained under `/Users/nonaka/.config/ai-harness` unless the user explicitly asks for destructive credential removal.

Current rollback implementation also supports `--dry-run`, creates a rollback report on real execution, and quarantines the CLIProxyAPI binary/starter, runtime config, auth store, dedicated harness settings, and harness Codex profile files instead of deleting them.

Artifact rollback docs:

- `/Users/nonaka/.local/share/ai-harness/ROLLBACK.md`
- `/Users/nonaka/.local/share/ai-harness/rollback.sh`
- `/Users/nonaka/.local/share/ai-harness/artifacts/ROLLBACK.md`
- `/Users/nonaka/.local/share/ai-harness/artifacts/rollback.sh`

Backups:

- `/Users/nonaka/.config/ai-harness/backups/20260625-231939`
- `/Users/nonaka/.config/ai-harness/backups/critical-20260625-232016`

## Residual Risks / Open Items

- The replacement Z.AI key is installed and verified locally, but the old exposed key should still be deleted/revoked in the Z.AI console. Official docs point to the API Keys management page (`https://z.ai/manage-apikey/apikey-list`); browser automation was attempted but blocked by local Chrome profile/authentication tooling, so `ai-auth rotate zai` and the fallback runbook are recorded in `SECURITY_NOTES.md`.
- Close or restart existing Codex sessions that still hold deleted `~/.codex/logs_2.sqlite*` handles; filesystem exact scan is clean, but deleted inodes are released only when those processes exit.
- `codex-glm` is not enabled. User action is required because Z.AI Coding Plan officially documents Claude Code/OpenCode-style integrations, while Codex CLI via Responses-to-Chat conversion remains compatibility-risky.
- Codex CLI model catalog reports `gpt-5.5` context metadata as `272000`, while the harness config follows the requested 400K/250K policy. Do not claim a verified 400K effective Codex CLI window from the local catalog.
- Codex CLI prints `hook: Stop Failed` after successful responses. This appears to be an existing user hook behavior, not a model/proxy failure.
- OpenCode noninteractive runs use per-run temporary DBs by default to avoid SQLite contention. To resume an OpenCode session, provide a persistent `OPENCODE_DB` explicitly.
