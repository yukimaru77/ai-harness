#!/usr/bin/env bash
set -euo pipefail

PURGE=0
case "${1:-}" in
  --purge-credentials) PURGE=1 ;;
  "" ) ;;
  * )
    echo "usage: $0 [--purge-credentials]" >&2
    exit 64
    ;;
esac

"$HOME/.local/share/ai-harness/bin/ai-harness-rollback"

if [ "$PURGE" -eq 1 ]; then
  echo "Refusing to purge credentials without a second explicit command." >&2
  echo "Credential files remain under ~/.config/ai-harness and ~/.local/share/ai-harness/cliproxy/auth." >&2
  exit 65
fi

echo "Uninstall complete. Credentials/config were retained."
