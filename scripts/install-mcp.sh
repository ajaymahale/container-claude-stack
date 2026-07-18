#!/usr/bin/env bash
# install-mcp.sh — merge user-scope MCP servers from mcp.json into the
# mcpServers block of ~/.claude.json. Direct JSON merge (no `claude` CLI) so
# the resolved z.ai token never appears in argv/ps — same merge style as
# install.sh handling claude-settings.json. Re-runnable; backs up first.
#
# Secrets: the $ZAI_TOKEN placeholder in mcp.json is resolved HERE from the
# macOS Keychain (cc-zai-token) on the host, falling back to the ZAI_TOKEN env
# var inside a container (providers.env, mounted by bin/cc-launch). Never
# committed. Matches repo invariant #1 (keychain only).
#
# Also creates ~/.claude.json if absent — required before bin/cc-launch can
# bind-mount it into the container (a missing host file turns the mount into a
# directory).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Resolve z.ai token: keychain on host, env (providers.env) in container.
ZAI_TOKEN="${ZAI_TOKEN:-}"
if [ -z "$ZAI_TOKEN" ] && command -v security >/dev/null 2>&1; then
  ZAI_TOKEN="$(security find-generic-password -a "$USER" -s cc-zai-token -w 2>/dev/null || true)"
fi
if [ -z "$ZAI_TOKEN" ]; then
  echo "  ! ZAI_TOKEN not found (no keychain cc-zai-token, no env var)."
  echo "    z.ai servers registered with literal \$ZAI_TOKEN — will fail until set."
  echo "    Fix: ~/claude-stack/secrets/secrets.bootstrap.sh"
fi

python3 - "$ROOT/mcp.json" "$HOME/.claude.json" "${ZAI_TOKEN:-}" <<'PY'
import json, pathlib, sys
manifest, target, token = sys.argv[1], sys.argv[2], sys.argv[3]
entries = json.loads(pathlib.Path(manifest).read_text())["servers"]
path = pathlib.Path(target)
cfg = json.loads(path.read_text()) if path.exists() else {}
cfg.setdefault("mcpServers", {})
changed = False
for e in entries:
    # Substitute the placeholder only where present (3 z.ai servers).
    obj = json.loads(json.dumps(e["json"]).replace("$ZAI_TOKEN", token or "$ZAI_TOKEN"))
    if cfg["mcpServers"].get(e["name"]) != obj:
        cfg["mcpServers"][e["name"]] = obj
        changed = True
        print(f"  mcp  ~ {e['name']}")
if changed:
    if path.exists():
        pathlib.Path(str(path) + ".bak").write_text(path.read_text())
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(cfg, indent=2) + "\n")
    print(f"  wrote {path}" + (" (backup: .claude.json.bak)" if changed else ""))
else:
    print("  (mcpServers already current)")
PY

echo
echo "Done. Verify in Claude: /mcp   (or claude mcp list)"
