# AI Harness Rollback

Primary command:

```bash
ai-harness-rollback
```

Equivalent artifact script:

```bash
/Users/nonaka/.local/share/ai-harness/rollback.sh
```

What rollback does:

- Unloads `com.nonaka.ai-harness.cliproxy` from the user LaunchAgent domain.
- Removes the harness shell source line from common shell rc files.
- Moves the harness wrapper directory and LaunchAgent plist into a private quarantine directory.
- Moves the CLIProxyAPI binary and harness starter into the same quarantine directory.
- Keeps credentials and config under `/Users/nonaka/.config/ai-harness` unless the user explicitly requests destructive removal.

After rollback, open a new shell and verify real tools:

```bash
command -v claude
command -v codex
command -v opencode
```

Backups recorded for this run:

- `/Users/nonaka/.config/ai-harness/backups/20260625-231939`
- `/Users/nonaka/.config/ai-harness/backups/critical-20260625-232016`
