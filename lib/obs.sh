# obs.sh — shared observability library for ai-harness wrappers.
#
# Every wrapper invocation gets a trace_id and writes structured JSONL events
# to ~/.local/share/ai-harness/obs/events.jsonl. Schema and query recipes are
# documented in OBSERVABILITY.md. Telemetry must never break the tool: every
# write is best-effort (|| true) and AI_HARNESS_OBS=0 disables it entirely.
#
# Usage from a wrapper (bash, set -euo pipefail is fine):
#   . "$HOME/.local/share/ai-harness/lib/obs.sh"
#   obs_init claude-glm "$@"          # logs the start event
#   obs_redact_add "$SOME_TOKEN"      # register secrets before logging argv-ish data
#   obs_event health_check target=cliproxy status=ok latency_ms=12
#   obs_run "$REAL_CLAUDE" ...args... # runs in FOREGROUND, logs end event, returns rc
#   exit $?

OBS_DIR="${AI_HARNESS_OBS_DIR:-$HOME/.local/share/ai-harness/obs}"
OBS_FILE="$OBS_DIR/events.jsonl"
OBS_SCHEMA=1
OBS_MAX_BYTES=$((50 * 1024 * 1024))
OBS_ENABLED="${AI_HARNESS_OBS:-1}"
OBS_ROUTE=""
OBS_TRACE=""
OBS_PARENT_TRACE=""
OBS_START_MS=0
OBS_ENDED=0
OBS_REDACT=()

_obs_now_ms() {
  # bash 5 EPOCHREALTIME = "sec.micros"; perl keeps ms precision on bash 3.2;
  # whole seconds as the last resort.
  if [ -n "${EPOCHREALTIME:-}" ]; then
    local s="${EPOCHREALTIME%.*}" us="${EPOCHREALTIME#*.}"
    printf '%s%s\n' "$s" "${us:0:3}"
  elif command -v perl >/dev/null 2>&1; then
    perl -MTime::HiRes=time -e 'printf "%d\n", time()*1000'
  else
    printf '%s000\n' "$(date +%s)"
  fi
}

_obs_ts() {
  date -u '+%Y-%m-%dT%H:%M:%S.000Z' 2>/dev/null || true
}

_obs_json_escape() {
  # stdin -> JSON-safe string content (no surrounding quotes).
  # Escapes backslash and quote, converts newlines/tabs, drops other controls.
  local s
  s="$(cat)"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/}"
  printf '%s' "$s" | LC_ALL=C tr -d '\000-\010\013\014\016-\037'
}

_obs_redact() {
  # stdin -> stdout with all registered secret values replaced.
  local s secret
  s="$(cat)"
  # ${arr[@]+...} guard: empty-array expansion trips `set -u` on bash < 4.4.
  for secret in ${OBS_REDACT[@]+"${OBS_REDACT[@]}"}; do
    [ -n "$secret" ] || continue
    s="${s//"$secret"/[REDACTED]}"
  done
  printf '%s' "$s"
}

obs_redact_add() {
  [ -n "${1:-}" ] && OBS_REDACT+=("$1")
  return 0
}

_obs_rotate() {
  local size
  size="$(stat -f %z "$OBS_FILE" 2>/dev/null || echo 0)"
  if [ "$size" -gt "$OBS_MAX_BYTES" ]; then
    mv -f "$OBS_FILE.1" "$OBS_FILE.2" 2>/dev/null || true
    mv -f "$OBS_FILE" "$OBS_FILE.1" 2>/dev/null || true
  fi
  return 0
}

_obs_write() {
  [ "$OBS_ENABLED" = "1" ] || return 0
  printf '%s\n' "$1" >> "$OBS_FILE" 2>/dev/null || true
}

# obs_event NAME [key=value ...]
# Values are strings by default. Use key:=value for raw JSON (numbers/bools).
obs_event() {
  [ "$OBS_ENABLED" = "1" ] || return 0
  local name="$1"; shift || true
  local line kv key val
  line="{\"schema\":$OBS_SCHEMA"
  line+=",\"ts\":\"$(_obs_ts)\""
  line+=",\"ts_ms\":$(_obs_now_ms)"
  line+=",\"trace_id\":\"$OBS_TRACE\""
  [ -n "$OBS_PARENT_TRACE" ] && line+=",\"parent_trace_id\":\"$OBS_PARENT_TRACE\""
  line+=",\"route\":\"$OBS_ROUTE\""
  line+=",\"event\":\"$(printf '%s' "$name" | _obs_json_escape)\""
  line+=",\"pid\":$$"
  for kv in "$@"; do
    case "$kv" in
      *:=*)
        key="${kv%%:=*}"; val="${kv#*:=}"
        line+=",\"$(printf '%s' "$key" | _obs_json_escape)\":$val"
        ;;
      *=*)
        key="${kv%%=*}"; val="${kv#*=}"
        line+=",\"$(printf '%s' "$key" | _obs_json_escape)\":\"$(printf '%s' "$val" | _obs_redact | _obs_json_escape)\""
        ;;
    esac
  done
  line+="}"
  _obs_write "$line"
  return 0
}

_obs_on_exit() {
  local rc=$?
  if [ "$OBS_ENDED" = "0" ]; then
    obs_event end rc:="$rc" duration_ms:="$(( $(_obs_now_ms) - OBS_START_MS ))" abnormal:=true
  fi
  return 0
}

# obs_init ROUTE [argv...]
obs_init() {
  OBS_ROUTE="${1:-unknown}"; shift || true
  [ "$OBS_ENABLED" = "1" ] || return 0
  mkdir -p "$OBS_DIR" 2>/dev/null || { OBS_ENABLED=0; return 0; }
  chmod 700 "$OBS_DIR" 2>/dev/null || true
  _obs_rotate

  # Reuse an inherited trace as parent so nested agent invocations correlate.
  if [ -n "${AI_HARNESS_TRACE_ID:-}" ]; then
    OBS_PARENT_TRACE="$AI_HARNESS_TRACE_ID"
  fi
  OBS_TRACE="$(uuidgen 2>/dev/null | tr 'A-Z' 'a-z' || printf 'notrace-%s-%s' "$$" "$(date +%s)")"
  export AI_HARNESS_TRACE_ID="$OBS_TRACE"
  OBS_START_MS="$(_obs_now_ms)"
  trap _obs_on_exit EXIT

  local argv=""
  if [ "$#" -gt 0 ]; then
    argv="$(printf '%s ' "$@")"
    argv="${argv% }"
  fi
  obs_event start \
    argv="$argv" \
    cwd="$PWD" \
    ppid:="${PPID:-0}" \
    tty="$(tty 2>/dev/null | head -n1 || true)" \
    user="$(id -un 2>/dev/null || echo unknown)" \
    wrapper_version="${OBS_WRAPPER_VERSION:-unversioned}"
  return 0
}

# obs_curl_probe NAME URL [curl args...]
# Logs a health_check event with HTTP status and millisecond latency.
# Returns curl's exit code so callers can gate on reachability.
obs_curl_probe() {
  local name="$1" url="$2"; shift 2
  local t0 t1 rc=0 http_code
  t0="$(_obs_now_ms)"
  http_code="$(curl -sS -m 10 -o /dev/null -w '%{http_code}' "$@" "$url" 2>/dev/null)" || rc=$?
  t1="$(_obs_now_ms)"
  obs_event health_check \
    target="$name" \
    url="$url" \
    http_status="${http_code:-0}" \
    curl_rc:="$rc" \
    latency_ms:="$((t1 - t0))" \
    ok:="$([ "$rc" -eq 0 ] && [ "${http_code:-0}" = "200" ] && echo true || echo false)"
  return "$rc"
}

# obs_run CMD [args...]
# Runs CMD in the foreground (keeps TTY control for interactive TUIs),
# then logs the end event with exit code and wall-clock duration.
obs_run() {
  local rc=0 t0 t1
  t0="$(_obs_now_ms)"
  obs_event exec cmd="$1"
  "$@" || rc=$?
  t1="$(_obs_now_ms)"
  OBS_ENDED=1
  obs_event end rc:="$rc" duration_ms:="$((t1 - t0))" abnormal:=false
  return "$rc"
}
