# AI Harness Security Notes

Secrets are stored only in private local files:

- `/Users/nonaka/.config/ai-harness/secrets/cliproxy-client.key`
- `/Users/nonaka/.config/ai-harness/secrets/cliproxy-management.key`
- `/Users/nonaka/.config/ai-harness/secrets/zai-coding.key`
- `/Users/nonaka/.local/share/ai-harness/cliproxy/auth/*.json`

The Z.AI Coding key is not stored in the permanent CLIProxyAPI config. The LaunchAgent starts
`/Users/nonaka/.local/libexec/ai-harness/cli-proxy-api-start`, which reads the private key file,
renders a temporary mode-600 config, starts CLIProxyAPI, and removes the temporary config on exit.

Expected permissions:

- Harness config/share directories: `700`
- Secret files, runtime config, OAuth JSON, and reports: `600`
- Wrappers/scripts: executable by the local user

Operational rules:

- Do not paste API keys or OAuth JSON into shell rc files, wrappers, logs, reports, Git, or process arguments.
- If a key is ever pasted into a chat or terminal session, rotate/revoke it at the provider. Local redaction removes copies, but does not make the exposed credential safe again.
- CLIProxyAPI is bound to `127.0.0.1:8317`; do not expose it to LAN or `0.0.0.0`.
- `request-log` is not enabled for normal operation.
- `ai-auth status` and `ai-harness-doctor` intentionally show state and model names, not token values.
- `codex-glm` remains disabled until explicit user acceptance because Codex CLI through Z.AI Coding Plan is compatibility-risky.

Z.AI key rotation runbook:

Preferred helper:

```bash
ai-auth rotate zai
```

The helper opens the Z.AI API Keys page, prompts for the replacement key with hidden input, writes it atomically to the harness secret file, and restarts the CLIProxyAPI LaunchAgent.

Manual fallback:

1. Open `https://z.ai/manage-apikey/apikey-list`.
2. Sign in to the Z.AI account that owns the GLM Coding Plan key.
3. Create a replacement key for the same Coding Plan scope.
4. Store the new key with:

   ```bash
   umask 077
   tmp="$(mktemp "$HOME/.config/ai-harness/secrets/zai-coding.key.XXXXXX")"
   cat > "$tmp"
   mv "$tmp" "$HOME/.config/ai-harness/secrets/zai-coding.key"
   chmod 600 "$HOME/.config/ai-harness/secrets/zai-coding.key"
   ```

   Paste the new key once, press Enter, then press Ctrl-D.

5. Restart the local proxy:

   ```bash
   launchctl kickstart -k "gui/$(id -u)/com.nonaka.ai-harness.cliproxy"
   ai-auth status
   ```

6. Verify `claude-glm` and `opencode-glm`, then revoke/delete the old key in the Z.AI API Keys page.

2026-06-26 local rotation result:

- `ai-auth rotate zai` was run successfully, CLIProxyAPI was restarted, and `ai-auth status` showed the Z.AI key present.
- `claude-glm` returned `CLAUDE-GLM-ROTATE-PASS` and `opencode-glm` returned `OPENCODE-GLM-ROTATE-PASS`.
- Exact scan for the replacement key outside private auth/secrets returned `files_with_exact_secret=0`, `occurrences=0`.
- Deleting/revoking the old exposed key in the Z.AI console still requires user confirmation.

CLIProxyAPI Management Center key note:

- The Management Center at `http://127.0.0.1:8317` uses the local management key, not any provider API key.
- Do not paste Z.AI, OpenAI, or Claude API keys into the Management Key field.
- If copying the management key manually, use `printf %s "$(cat ~/.config/ai-harness/secrets/cliproxy-management.key)" | pbcopy` so no trailing newline is pasted.

Automation note:

- Browser automation was attempted for the Z.AI console, but Open Browser Use was unavailable due a Chrome profile mismatch and Computer Use returned a local authentication error. Provider-side key rotation remains a user-session action.
