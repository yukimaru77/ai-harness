# Fusion API Proxy — item-level multi-model fusion (design)

Status: DESIGN (not implemented). 2026-07-05.

## Goal

An Anthropic-Messages-compatible reverse proxy that fuses at the **item
level**: every single API call in an agent loop (one "item" = one model
response: text and/or tool_use) is answered by fanning the identical request
out to N candidate models, then having a synthesizer model merge the N
candidate responses into the one response the client actually receives.

This differs from the existing turn-level fusion skill (N full agent runs
merged at the end). Here the agent loop is single, but every step of it is a
committee decision:

```
user prompt ─▶ [candidates: claude, gpt, glm] ─▶ synthesizer ─▶ final item
                                                                (tool_use)
tool output ─▶ [candidates × same history]    ─▶ synthesizer ─▶ next item
...repeat until final text answer
```

## Why it is feasible (verified)

- All three backends already serve the **same protocol**. CLIProxyAPI
  `/v1/messages` converts Anthropic-protocol requests to:
  - `oauth-gpt-5.5` (Codex OAuth) — proven daily by the claude-codex route
  - `zai/glm-5.2` — verified 2026-07-05: tool_use round-trip works
  - Claude itself: either register the Claude account in CLIProxyAPI, or the
    fusion proxy calls `api.anthropic.com` directly with the Claude Code
    OAuth credential (see Open questions)
- Claude Code tolerates gateway backends via `ANTHROPIC_BASE_URL` (all our
  routes work this way), so the client side needs nothing but a wrapper.
- Every candidate model already runs Claude Code's system prompt + tools
  individually today; the proxy merely multiplexes identical requests.

## Architecture

```
Claude Code  (wrapper: ANTHROPIC_BASE_URL=http://127.0.0.1:8400)
   │  POST /v1/messages (stream=true)
   ▼
fusion-api (new daemon, 127.0.0.1:8400, single-file Python, stdlib only)
   │
   ├─ Phase A: fan-out (parallel, stream=false)
   │    for each candidate model: forward the request verbatim,
   │    only `model` rewritten; via CLIProxyAPI :8317 /v1/messages
   │    timeout per candidate; ≥1 success required
   │
   ├─ Phase B: synthesis
   │    request to synthesizer model =
   │      original system + original history + original tools
   │      + appended user message:
   │        "N candidate next-messages were produced by independent models
   │         for exactly this state: <candidates as JSON>. Emit the single
   │         best next message yourself — call a tool or answer; do not
   │         mention the candidates."
   │    stream=true; tool schema identical → output is valid by construction
   │
   └─ Phase C: stream the synthesizer's SSE back to the client,
        rewriting `model` to the advertised name (e.g. "fusion-v1");
        during Phase A send SSE `ping` events as keepalive
```

### Key invariants

1. **History purity** — candidates are ephemeral. Only synthesized messages
   enter the conversation history (the client keeps history; we never store).
   `tool_use` ids the client sees are the synthesizer's own, so the next
   `tool_result` matches. No id remapping needed.
2. **Statelessness** — the proxy holds no session state; each request is
   self-contained (Messages API is replay-style). Retry/resume = free.
3. **Format safety** — the synthesizer produces the final item through the
   same API with the same tool schema, so no hand-assembly of content blocks.

### Failure policy

| Failure | Behavior |
|---|---|
| candidate timeout/error | proceed with the survivors (min 1); log |
| ALL candidates fail | forward the original request to the synthesizer model alone (degraded = single-model passthrough); log loudly |
| synthesizer fails | return the highest-priority surviving candidate verbatim (priority = config order); log loudly |
| client disconnect | cancel all upstream calls |

### Config (`~/.config/ai-harness/fusion-api.yaml`)

```yaml
listen: 127.0.0.1:8400
upstream: http://127.0.0.1:8317        # CLIProxyAPI
advertised_model: fusion-v1            # what the client sees
candidates:
  - model: claude-opus-4-8             # via anthropic direct or cliproxy
  - model: oauth-gpt-5.5
  - model: zai/glm-5.2
synthesizer:
  model: claude-opus-4-8               # configurable, default Claude
candidate_timeout_s: 120
keepalive_s: 15
# background/haiku-class requests bypass fusion entirely:
passthrough_models: ["*haiku*", "*sonnet*"]   # → synthesizer model, no fan-out
```

`passthrough_models` matters: Claude Code fires cheap background calls
(naming, summarization). Fusing those wastes 4× cost for zero value — route
them straight to one model.

### Observability (reuses the existing obs stack)

- Every request: one `fusion_item` JSONL record in `obs/fusion.jsonl`:
  trace id (propagates incoming `x-ai-harness-trace`), per-candidate
  latency/status/stop_reason, chosen synthesis latency, degraded flags.
- Candidates + final answer stored (redacted) — this is gold data: it shows
  per-item where models disagree and which one the synthesizer follows.
- `ai-harness-stats` gains a Fusion section (agreement rate, degraded rate,
  p50/p95 per phase). Health monitor probes :8400.
- LaunchAgent `com.<user>.ai-harness.fusion`, lifecycle log like cliproxy.

### Client wrapper

New `claude-fx` command (working name — see Open questions): same shape as
claude-codex but `ANTHROPIC_BASE_URL=http://127.0.0.1:8400`, model pins to
`fusion-v1`, obs route `claude-fx`. Skills/MCP selection via ~/.agent-fusion
applies unchanged.

## Cost & latency (eyes open)

- Per item: 3 candidate calls + 1 synthesis call whose input includes the
  full history **plus** all candidate outputs → ×4–5 tokens per step vs
  single-model. A 30-item session ≈ 120+ upstream calls.
- Wall clock per item ≈ max(candidate latencies) + synthesis. With today's
  bench numbers: roughly GLM-bound (~7–9s) + synthesis (~3–8s) ≈ 10–17s/item.
  Fine for quality-first sessions; not a daily-driver replacement.
- Quota: burns Claude Max + ChatGPT + GLM Coding Plan simultaneously.

## Open questions (decide before implementation)

1. **Claude candidate/synthesizer transport**: (a) register the Claude
   account inside CLIProxyAPI (uniform upstream, but another OAuth copy), or
   (b) fusion-api calls api.anthropic.com directly reusing
   `~/.claude/.credentials.json` (no new registration; must send Claude-Code
   OAuth beta headers and handle token refresh timing — read-only reuse,
   refresh stays owned by Claude Code). Recommendation: try (b) first; fall
   back to (a).
2. **Naming**: `claude-fusion` is already the Opus-4.8 telemetry route.
   Candidates for the new command: `claude-fx` / `claude-fuse` /
   rename the existing route. Needs user decision.
3. **Synthesis prompt shape**: single fixed template first; later maybe
   per-item-type templates (tool-choice items vs final-answer items).
4. **Thinking blocks**: candidates may emit `thinking` content; strip from
   the candidate JSON given to the synthesizer (keep only text/tool_use) to
   control token growth? Default: strip, configurable.

## Implementation plan (when approved)

1. `bin/fusion-api` (single-file Python 3 stdlib: ThreadingHTTPServer,
   urllib, SSE passthrough) + config template + LaunchAgent + lifecycle log.
2. `claude-fx` wrapper + obs route + bench route + monitor probe.
3. Runbook additions in OBSERVABILITY.md; AGENT_SETUP phase; install.sh
   requirements; artifacts sync.
4. Verification: scripted tool-loop test (fake tool), then real Claude Code
   session; bench with `--routes claude-fx`.
```
