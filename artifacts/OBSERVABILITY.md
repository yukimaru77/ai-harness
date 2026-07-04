# AI Harness Observability

Every layer of the harness emits structured, locally-stored telemetry so that a
human with `jq`/`grep` — or any simple tool — can answer "what failed, where,
and when" without guesswork. No data leaves this machine. Secrets are redacted
before writing.

## Data flow

```
wrapper (claude-codex, claude-glm, codex, codex-glm, opencode-*)
  │  lib/obs.sh: start / health_check / route_resolved / exec / end events
  │  trace_id generated per invocation, exported as AI_HARNESS_TRACE_ID
  │  claude-* routes add header x-ai-harness-trace to every API request
  │  codex-glm adds the same header via model_providers http_headers
  ▼
~/.local/share/ai-harness/obs/events.jsonl

cli-proxy-api-start (launchd service wrapper)
  │  boot / render_ok / render_failed / proxy_spawned / proxy_exited / terminated
  ▼
~/.local/share/ai-harness/obs/proxy-lifecycle.jsonl

ai-harness-monitor (LaunchAgent com.nonaka.ai-harness.monitor, every 300s)
  │  probes: cliproxy_models, cliproxy_process, zai_anthropic,
  │          zai_openai_compat, codex_oauth_file, logs
  ▼
~/.local/share/ai-harness/obs/health.jsonl

CLIProxyAPI itself
  │  access log + error dumps (request headers include x-ai-harness-trace)
  ▼
~/.local/share/ai-harness/cliproxy/logs/main.log, error-*.log
```

`ai-harness-stats` joins all four sources into one report.

## Files and retention

| File | Writer | Rotation |
|---|---|---|
| `obs/events.jsonl` | wrappers + ai-auth | at 50 MB → `.1`, `.2` kept |
| `obs/health.jsonl` | ai-harness-monitor | at 20 MB → `.1` kept |
| `obs/proxy-lifecycle.jsonl` | cli-proxy-api-start | small; manual |
| `cliproxy/logs/main.log` | CLIProxyAPI | `logs-max-total-size-mb: 100` |
| `cliproxy/logs/error-*.log` | CLIProxyAPI | `error-logs-max-files: 10` |

Disable all wrapper/monitor telemetry for one run with `AI_HARNESS_OBS=0`.

## Event schema — `events.jsonl` (schema: 1)

Common fields on every line:

| Field | Meaning |
|---|---|
| `ts`, `ts_ms` | UTC ISO timestamp / epoch milliseconds |
| `trace_id` | one UUID per wrapper invocation |
| `parent_trace_id` | present when a wrapper was launched from another one |
| `route` | `claude-codex`, `claude-glm`, `codex`, `codex-glm`, `opencode-codex`, `opencode-glm`, `ai-auth` |
| `event` | see below |
| `pid` | wrapper PID |

Events, in the order a normal run emits them:

- `start` — `argv` (secrets redacted), `cwd`, `ppid`, `tty`, `user`, `wrapper_version`
- `health_check` — `target`, `url`, `http_status`, `curl_rc`, `latency_ms`, `ok`
- `route_resolved` — the exact backend chosen: `base_url` / `provider`, `model`, `config_dir` / `db`, `real_bin`
- `exec` — `cmd` (the real binary about to run)
- `end` — `rc` (child exit code), `duration_ms`, `abnormal` (`true` = the wrapper died before the child finished cleanly)
- `fatal` — emitted instead of exec when startup is refused: `reason` ∈ `missing_client_key`, `missing_zai_key`, `cliproxy_unreachable`, `acceptance_gate_closed`
- `blocked_subcommand` / `passthrough` — codex-glm and opencode wrappers' subcommand policy decisions

## Probe schema — `health.jsonl` (schema: 1)

Every monitor run shares a `run_id`. HTTP probes carry the full curl timing
breakdown: `dns_ms`, `connect_ms`, `tls_ms`, `ttfb_ms`, `total_ms`, plus
`http_status`, `curl_rc`, `remote_ip`, `ok`.

| probe | ok criteria | What it tells you |
|---|---|---|
| `cliproxy_models` | HTTP 200 | local proxy reachable + auth works |
| `cliproxy_process` | running | launchd state, PID, RSS, uptime |
| `zai_anthropic` | HTTP 200 | claude-glm upstream (api.z.ai anthropic route) |
| `zai_openai_compat` | HTTP 200 | codex-glm upstream (api.z.ai coding route) |
| `anthropic_api` | any < 500 (401 = healthy) | `claude` upstream network path |
| `openai_api` | any < 500 | OpenAI API network path |
| `chatgpt_backend` | any < 500 | `codex` / claude-codex upstream network path |
| `codex_oauth_file` | not disabled | CLIProxyAPI codex credential age / disabled flag |
| `logs` | always | `proxy_5xx_last_10m`, log dir sizes |

All seven routes' upstreams get the same dns/connect/tls/ttfb breakdown, so a
slow session can be attributed: high `connect_ms`/`tls_ms` = network path,
high `ttfb_ms` with fast connect = provider server, all probes fast but the
wrapper `end.duration_ms` slow = local (harness/CLI/tooling).

## Bench schema — `bench.jsonl` (schema: 1)

`ai-harness-bench` sends the SAME tiny prompt through every route
(`claude`, `claude-codex`, `claude-glm`, `codex`, `codex-glm`,
`opencode-codex`, `opencode-glm`) and appends per-route lines:
`run_id` (one per bench run), `route`, `ok` (exit 0 AND the expected token
appeared in output), `rc`, `timed_out`, `duration_ms`, `note`, `last_line`.
This is the apples-to-apples comparison: same prompt, same moment, all routes.
`ai-harness-stats` shows per-route ok-rate and p50/p95. Run it manually or
periodically (e.g. after config changes: `ai-harness-bench --note "reason"`).

## Lifecycle schema — `proxy-lifecycle.jsonl` (schema: 1)

`boot` → `render_ok` (or `render_failed`) → `proxy_spawned{proxy_pid}` →
`proxy_exited{rc}` / `terminating`+`terminated`. A `boot` without a matching
clean exit right before it = the previous proxy crashed or the Mac restarted.

## How to analyze

Quick overview and error hunt:

```bash
ai-harness-stats                 # 24h summary per route / probe / proxy
ai-harness-stats --hours 168     # a week
ai-harness-stats --errors        # every failure, newest first
ai-harness-stats --json          # for scripts
```

Follow one failed invocation end to end:

```bash
ai-harness-stats --errors                 # copy the trace= id
ai-harness-stats --trace <trace_id>       # all wrapper events for it
grep -r '<trace_id>' ~/.local/share/ai-harness/cliproxy/logs/error-*.log
#   error dumps include request headers; x-ai-harness-trace joins the two logs
```

Raw jq recipes:

```bash
# error-rate per route today
jq -r 'select(.event=="end") | "\(.route) \(.rc)"' ~/.local/share/ai-harness/obs/events.jsonl \
  | sort | uniq -c

# Z.AI latency trend (p95 spikes = upstream trouble, not harness trouble)
jq -r 'select(.probe=="zai_anthropic") | "\(.ts) \(.total_ms)ms ok=\(.ok)"' \
  ~/.local/share/ai-harness/obs/health.jsonl | tail -50

# proxy restarts / crashes
jq -r 'select(.event=="boot" or .event=="proxy_exited")' \
  ~/.local/share/ai-harness/obs/proxy-lifecycle.jsonl

# token usage recorded by CLIProxyAPI (usage-statistics-enabled: true)
curl -s -H "X-Management-Key: $(cat ~/.config/ai-harness/secrets/cliproxy-management.key)" \
  http://127.0.0.1:8317/v0/management/usage | jq .
```

## Failure runbook

| Symptom | First place to look | Typical cause |
|---|---|---|
| wrapper exits 69 | `events.jsonl` `fatal reason=cliproxy_unreachable` | proxy LaunchAgent down → `launchctl kickstart -k gui/501/com.nonaka.ai-harness.cliproxy` |
| wrapper exits 70 | `fatal reason=missing_*_key` | secret file missing → `ai-auth rotate zai` / `ai-auth login openai` |
| 400 "Unknown Model" from Z.AI | `route_resolved` event's model fields | model mapping drift after a Claude Code update — model names must go through `ANTHROPIC_DEFAULT_*_MODEL` |
| 502 "unknown provider" from proxy | same | a request reached the proxy with an Anthropic model name |
| 500 with `dial tcp ... i/o timeout` | `health.jsonl` `zai_*` probes around that time | api.z.ai unreachable — upstream/network, not the harness |
| 503 on `/v1/messages` | `codex_oauth_file` probe + `ai-auth status` | no usable Codex OAuth credential in the proxy |
| proxy restarts repeatedly | `proxy-lifecycle.jsonl` + `launchd.err.log` | render failure (exit 71) or crash loop |
