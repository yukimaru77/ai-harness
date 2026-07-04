#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
case "${1:-}" in
  --dry-run) DRY_RUN=1 ;;
  "" ) ;;
  * )
    echo "usage: $0 [--dry-run]" >&2
    exit 64
    ;;
esac

HOME_DIR="${HOME:?}"
HARNESS_HOME="$HOME_DIR/.config/ai-harness"
HARNESS_SHARE="$HOME_DIR/.local/share/ai-harness"
BIN_DIR="$HARNESS_SHARE/bin"
LIBEXEC_DIR="$HOME_DIR/.local/libexec/ai-harness"
PLIST="$HOME_DIR/Library/LaunchAgents/com.nonaka.ai-harness.cliproxy.plist"
SOURCE_LINE='[ -f "$HOME/.config/ai-harness/shell.sh" ] && . "$HOME/.config/ai-harness/shell.sh"'

say() {
  printf '%s\n' "$*"
}

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run]'
    for arg in "$@"; do printf ' %q' "$arg"; done
    printf '\n'
  else
    "$@"
  fi
}

require_file() {
  [ -e "$1" ] || { echo "missing required file: $1" >&2; exit 66; }
}

say "AI Harness install/check"
require_file "$HARNESS_HOME/paths.env"
require_file "$HARNESS_HOME/shell.sh"
require_file "$HARNESS_HOME/cliproxy/config.yaml"
require_file "$HARNESS_HOME/secrets/cliproxy-client.key"
require_file "$HARNESS_HOME/secrets/cliproxy-management.key"
require_file "$HARNESS_HOME/secrets/zai-coding.key"
require_file "$LIBEXEC_DIR/cli-proxy-api"
require_file "$LIBEXEC_DIR/cli-proxy-api-start"
# `claude` is a TRANSPARENT wrapper: telemetry only, no flags/env changes.
require_file "$BIN_DIR/claude"
require_file "$BIN_DIR/claude-codex"
require_file "$BIN_DIR/claude-glm"
require_file "$BIN_DIR/codex"
require_file "$BIN_DIR/codex-glm"
require_file "$BIN_DIR/opencode-codex"
require_file "$BIN_DIR/opencode-glm"
require_file "$BIN_DIR/ai-auth"
require_file "$BIN_DIR/ai-harness-doctor"
require_file "$BIN_DIR/ai-harness-enable"
require_file "$BIN_DIR/ai-harness-rollback"
require_file "$BIN_DIR/ai-harness-monitor"
require_file "$BIN_DIR/ai-harness-stats"
require_file "$BIN_DIR/ai-harness-bench"
require_file "$HARNESS_SHARE/lib/obs.sh"
require_file "$PLIST"
MONITOR_PLIST="$HOME_DIR/Library/LaunchAgents/com.nonaka.ai-harness.monitor.plist"
require_file "$MONITOR_PLIST"

# Keep ~/.local/bin symlinks pointing at the harness wrappers so the commands
# work in shells that do not source shell.sh. `claude` links to the harness
# wrapper (transparent, telemetry only). Never touch `codex` or `opencode`
# there: `codex` is owned by the agmsg shim in ~/.agents/bin and `opencode`
# is the real binary.
LOCAL_BIN="$HOME_DIR/.local/bin"
for cmd in claude claude-codex claude-glm codex-glm opencode-codex opencode-glm \
           ai-auth ai-harness-doctor ai-harness-enable ai-harness-rollback \
           ai-harness-monitor ai-harness-stats ai-harness-bench; do
  link="$LOCAL_BIN/$cmd"
  target="$BIN_DIR/$cmd"
  if [ "$(readlink "$link" 2>/dev/null || true)" != "$target" ]; then
    run ln -sfn "$target" "$link"
  fi
done

for dir in "$HARNESS_HOME" "$HARNESS_SHARE" "$HARNESS_HOME/secrets" "$HARNESS_SHARE/cliproxy/auth"; do
  [ -d "$dir" ] || continue
  run chmod 700 "$dir"
done
for file in "$HARNESS_HOME"/secrets/*.key "$HARNESS_HOME/cliproxy/config.yaml" "$HARNESS_SHARE"/cliproxy/auth/*.json; do
  [ -e "$file" ] || continue
  run chmod 600 "$file"
done
run chmod 700 "$LIBEXEC_DIR/cli-proxy-api-start"

for rc in "$HOME_DIR/.bashrc" "$HOME_DIR/.zshrc"; do
  if [ -f "$rc" ] && ! grep -Fqx "$SOURCE_LINE" "$rc"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      say "[dry-run] append harness source line to $rc"
    else
      printf '\n%s\n' "$SOURCE_LINE" >> "$rc"
    fi
  fi
done

if [ "$DRY_RUN" -eq 1 ]; then
  say "[dry-run] launchctl bootstrap gui/$(id -u) $PLIST if not already loaded"
  say "[dry-run] launchctl bootstrap gui/$(id -u) $MONITOR_PLIST if not already loaded"
else
  launchctl print "gui/$(id -u)/com.nonaka.ai-harness.cliproxy" >/dev/null 2>&1 || \
    launchctl bootstrap "gui/$(id -u)" "$PLIST"
  launchctl print "gui/$(id -u)/com.nonaka.ai-harness.monitor" >/dev/null 2>&1 || \
    launchctl bootstrap "gui/$(id -u)" "$MONITOR_PLIST"
fi

say "AI Harness install/check complete"
