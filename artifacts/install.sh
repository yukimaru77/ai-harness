#!/usr/bin/env bash
# install.sh — entry point for setting up (or checking) the AI harness.
#
# Fresh clone (default): pick which agents/providers you want, then hand the
# rest of the work to an AI coding agent following docs/AGENT_SETUP.md:
#
#   ./install.sh                                   # interactive selection
#   ./install.sh --agents claude,opencode --glm no # non-interactive
#
# Installed deployment: structural check + repair (perms, symlinks, launchd):
#
#   ./install.sh --check [--dry-run]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SELECTION_FILE="$REPO_DIR/setup-selection.json"
ZAI_KEY_URL="https://z.ai/manage-apikey/apikey-list"

MODE=wizard
DRY_RUN=0
AGENTS=""
GLM=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) MODE=check; shift ;;
    --dry-run) DRY_RUN=1; MODE=check; shift ;;
    --agents) AGENTS="${2:?}"; shift 2 ;;
    --agents=*) AGENTS="${1#--agents=}"; shift ;;
    --glm) GLM="${2:?}"; shift 2 ;;
    --glm=*) GLM="${1#--glm=}"; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "usage: $0 [--check [--dry-run]] [--agents claude,codex,opencode] [--glm yes|no]" >&2; exit 64 ;;
  esac
done

say() { printf '%s\n' "$*"; }

# ---------------------------------------------------------------------------
# Wizard mode: component selection -> setup-selection.json -> AI agent handoff
# ---------------------------------------------------------------------------
wizard() {
  say "AI Harness setup"
  say ""
  say "This selects WHICH components you want. The actual setup is done by an"
  say "AI coding agent following docs/AGENT_SETUP.md."
  say ""

  if [ -z "$AGENTS" ]; then
    if [ -t 0 ]; then
      say "Which agent CLIs do you want? (comma-separated)"
      say "  claude   - Claude Code (native + proxied/GLM routes)"
      say "  codex    - Codex CLI (native + GLM route, enables claude-codex)"
      say "  opencode - OpenCode (native codex/GLM providers)"
      printf 'agents [claude,codex,opencode]: '
      IFS= read -r AGENTS
      [ -n "$AGENTS" ] || AGENTS="claude,codex,opencode"
    else
      AGENTS="claude,codex,opencode"
    fi
  fi

  if [ -z "$GLM" ]; then
    if [ -t 0 ]; then
      say ""
      say "Include GLM (Z.AI GLM Coding Plan) routes? Requires an API key from:"
      say "  $ZAI_KEY_URL"
      printf 'glm [yes]: '
      IFS= read -r GLM
      [ -n "$GLM" ] || GLM="yes"
    else
      GLM="yes"
    fi
  fi

  local want_claude=false want_codex=false want_opencode=false want_glm=false
  case ",$AGENTS," in *,claude,*) want_claude=true ;; esac
  case ",$AGENTS," in *,codex,*) want_codex=true ;; esac
  case ",$AGENTS," in *,opencode,*) want_opencode=true ;; esac
  case "$GLM" in y|Y|yes|YES|true) want_glm=true ;; esac
  if [ "$want_claude" = false ] && [ "$want_codex" = false ] && [ "$want_opencode" = false ]; then
    echo "no agents selected" >&2; exit 64
  fi

  local routes=()
  $want_claude && routes+=(claude-fusion)
  $want_claude && $want_codex && routes+=(claude-codex)
  $want_claude && $want_glm && routes+=(claude-glm)
  $want_codex && routes+=(codex-fusion)
  $want_codex && $want_glm && routes+=(codex-glm)
  $want_opencode && $want_codex && routes+=(opencode-codex)
  $want_opencode && $want_glm && routes+=(opencode-glm)

  local routes_json="" r
  for r in "${routes[@]}"; do routes_json+="\"$r\","; done
  routes_json="[${routes_json%,}]"

  printf '{"schema":1,"created":"%s","agents":{"claude":%s,"codex":%s,"opencode":%s},"glm":%s,"routes":%s}\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$want_claude" "$want_codex" "$want_opencode" "$want_glm" "$routes_json" \
    > "$SELECTION_FILE"

  say ""
  say "Wrote $SELECTION_FILE"
  say "Selected routes: ${routes[*]}"
  if [ "$want_glm" = true ]; then
    say ""
    say "GLM selected: create a GLM Coding Plan API key (you will paste it"
    say "into a hidden prompt later, never into a chat):"
    say "  $ZAI_KEY_URL"
  fi
  say ""
  say "Next step — run your AI coding agent in this directory and tell it:"
  say ""
  say '  Read docs/AGENT_SETUP.md and set up the AI harness on this machine'
  say '  according to setup-selection.json. Never display API keys or tokens.'
  say ""
  say "Any capable agent works (claude / codex / opencode / other)."
}

# ---------------------------------------------------------------------------
# Check mode: structural verification + repair of an installed deployment
# ---------------------------------------------------------------------------
check() {
  local HOME_DIR="${HOME:?}"
  local HARNESS_HOME="$HOME_DIR/.config/ai-harness"
  local HARNESS_SHARE="$HOME_DIR/.local/share/ai-harness"
  local BIN_DIR="$HARNESS_SHARE/bin"
  local LIBEXEC_DIR="$HOME_DIR/.local/libexec/ai-harness"
  local SOURCE_LINE='[ -f "$HOME/.config/ai-harness/shell.sh" ] && . "$HOME/.config/ai-harness/shell.sh"'
  local LA_LABEL_USER
  LA_LABEL_USER="$(id -un)"
  # Reference deployment used com.nonaka.*; accept either naming.
  local PLIST="" MONITOR_PLIST="" cand
  for cand in "com.$LA_LABEL_USER.ai-harness.cliproxy" com.nonaka.ai-harness.cliproxy; do
    [ -f "$HOME_DIR/Library/LaunchAgents/$cand.plist" ] && PLIST="$HOME_DIR/Library/LaunchAgents/$cand.plist" && PROXY_LABEL="$cand" && break
  done
  for cand in "com.$LA_LABEL_USER.ai-harness.monitor" com.nonaka.ai-harness.monitor; do
    [ -f "$HOME_DIR/Library/LaunchAgents/$cand.plist" ] && MONITOR_PLIST="$HOME_DIR/Library/LaunchAgents/$cand.plist" && MONITOR_LABEL="$cand" && break
  done
  local FUSION_PLIST="" FUSION_LABEL=""
  for cand in "com.$LA_LABEL_USER.ai-harness.fusion" com.nonaka.ai-harness.fusion; do
    [ -f "$HOME_DIR/Library/LaunchAgents/$cand.plist" ] && FUSION_PLIST="$HOME_DIR/Library/LaunchAgents/$cand.plist" && FUSION_LABEL="$cand" && break
  done

  run() {
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '[dry-run]'
      local arg; for arg in "$@"; do printf ' %q' "$arg"; done
      printf '\n'
    else
      "$@"
    fi
  }
  require_file() { [ -e "$1" ] || { echo "missing required file: $1" >&2; exit 66; }; }

  # Selection-aware requirements: without setup-selection.json assume everything.
  local sel="$HARNESS_SHARE/setup-selection.json"
  local want_claude=true want_codex=true want_opencode=true want_glm=true
  if [ -f "$sel" ] && command -v python3 >/dev/null 2>&1; then
    want_claude="$(python3 -c "import json;print(str(json.load(open('$sel'))['agents']['claude']).lower())" 2>/dev/null || echo true)"
    want_codex="$(python3 -c "import json;print(str(json.load(open('$sel'))['agents']['codex']).lower())" 2>/dev/null || echo true)"
    want_opencode="$(python3 -c "import json;print(str(json.load(open('$sel'))['agents']['opencode']).lower())" 2>/dev/null || echo true)"
    want_glm="$(python3 -c "import json;print(str(json.load(open('$sel'))['glm']).lower())" 2>/dev/null || echo true)"
  fi
  local need_proxy=false
  { [ "$want_claude" = true ] && [ "$want_codex" = true ]; } && need_proxy=true
  { [ "$want_codex" = true ] && [ "$want_glm" = true ]; } && need_proxy=true

  say "AI Harness install/check (claude=$want_claude codex=$want_codex opencode=$want_opencode glm=$want_glm proxy=$need_proxy)"
  require_file "$HARNESS_HOME/paths.env"
  require_file "$HARNESS_HOME/shell.sh"
  require_file "$HARNESS_SHARE/lib/obs.sh"
  if [ "$need_proxy" = true ]; then
    require_file "$HARNESS_HOME/cliproxy/config.yaml"
    require_file "$HARNESS_HOME/secrets/cliproxy-client.key"
    require_file "$HARNESS_HOME/secrets/cliproxy-management.key"
    require_file "$LIBEXEC_DIR/cli-proxy-api"
    require_file "$LIBEXEC_DIR/cli-proxy-api-start"
    [ -n "$PLIST" ] || { echo "missing cliproxy LaunchAgent plist" >&2; exit 66; }
  fi
  [ "$want_glm" = true ] && require_file "$HARNESS_HOME/secrets/zai-coding.key"
  [ "$want_claude" = true ] && require_file "$BIN_DIR/claude-fusion"
  { [ "$want_claude" = true ] && [ "$want_codex" = true ]; } && require_file "$BIN_DIR/claude-codex"
  { [ "$want_claude" = true ] && [ "$want_glm" = true ]; } && require_file "$BIN_DIR/claude-glm"
  [ "$want_codex" = true ] && require_file "$BIN_DIR/codex-fusion"
  { [ "$want_codex" = true ] && [ "$want_glm" = true ]; } && require_file "$BIN_DIR/codex-glm"
  { [ "$want_opencode" = true ] && [ "$want_codex" = true ]; } && require_file "$BIN_DIR/opencode-codex"
  { [ "$want_opencode" = true ] && [ "$want_glm" = true ]; } && require_file "$BIN_DIR/opencode-glm"
  local c
  for c in ai-auth ai-harness-doctor ai-harness-enable ai-harness-rollback \
           ai-harness-monitor ai-harness-stats ai-harness-bench ai-harness-agent \
           ai-harness-fusion claude-moe codex-moe; do
    require_file "$BIN_DIR/$c"
  done
  [ -n "$MONITOR_PLIST" ] || { echo "missing monitor LaunchAgent plist" >&2; exit 66; }

  # Keep ~/.local/bin symlinks pointing at the harness wrappers so the commands
  # work in shells that do not source shell.sh. NEVER manage `claude`, `codex`,
  # or `opencode` there: those are the user's daily-driver commands.
  local LOCAL_BIN="$HOME_DIR/.local/bin" cmd link target
  for cmd in claude-fusion codex-fusion claude-codex claude-glm codex-glm opencode-codex opencode-glm \
             ai-auth ai-harness-doctor ai-harness-enable ai-harness-rollback \
             ai-harness-monitor ai-harness-stats ai-harness-bench ai-harness-agent \
             ai-harness-fusion claude-moe codex-moe; do
    [ -e "$BIN_DIR/$cmd" ] || continue
    link="$LOCAL_BIN/$cmd"
    target="$BIN_DIR/$cmd"
    if [ "$(readlink "$link" 2>/dev/null || true)" != "$target" ]; then
      run ln -sfn "$target" "$link"
    fi
  done

  local dir file
  for dir in "$HARNESS_HOME" "$HARNESS_SHARE" "$HARNESS_HOME/secrets" "$HARNESS_SHARE/cliproxy/auth"; do
    [ -d "$dir" ] || continue
    run chmod 700 "$dir"
  done
  for file in "$HARNESS_HOME"/secrets/*.key "$HARNESS_HOME/cliproxy/config.yaml" "$HARNESS_SHARE"/cliproxy/auth/*.json; do
    [ -e "$file" ] || continue
    run chmod 600 "$file"
  done
  [ -e "$LIBEXEC_DIR/cli-proxy-api-start" ] && run chmod 700 "$LIBEXEC_DIR/cli-proxy-api-start"

  local rc_file
  for rc_file in "$HOME_DIR/.bashrc" "$HOME_DIR/.zshrc"; do
    if [ -f "$rc_file" ] && ! grep -Fqx "$SOURCE_LINE" "$rc_file"; then
      if [ "$DRY_RUN" -eq 1 ]; then
        say "[dry-run] append harness source line to $rc_file"
      else
        printf '\n%s\n' "$SOURCE_LINE" >> "$rc_file"
      fi
    fi
  done

  if [ "$DRY_RUN" -eq 1 ]; then
    [ "$need_proxy" = true ] && say "[dry-run] launchctl bootstrap gui/$(id -u) $PLIST if not already loaded"
    say "[dry-run] launchctl bootstrap gui/$(id -u) $MONITOR_PLIST if not already loaded"
  else
    if [ "$need_proxy" = true ]; then
      launchctl print "gui/$(id -u)/$PROXY_LABEL" >/dev/null 2>&1 || \
        launchctl bootstrap "gui/$(id -u)" "$PLIST"
    fi
    launchctl print "gui/$(id -u)/$MONITOR_LABEL" >/dev/null 2>&1 || \
      launchctl bootstrap "gui/$(id -u)" "$MONITOR_PLIST"
    if [ -n "$FUSION_PLIST" ]; then
      launchctl print "gui/$(id -u)/$FUSION_LABEL" >/dev/null 2>&1 || \
        launchctl bootstrap "gui/$(id -u)" "$FUSION_PLIST"
    fi
  fi

  say "AI Harness install/check complete"
}

case "$MODE" in
  wizard) wizard ;;
  check) check ;;
esac
