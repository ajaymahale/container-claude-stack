#!/usr/bin/env bash
# Resolve the latest installed claude-mem version from the ro plugin mount and
# run its HTTP server. server-service.cjs reads NODE_ENV/PORT/CLAUDE_MEM_* env.
set -euo pipefail

v="$(ls -d /plugin-cache/*/ 2>/dev/null | sort -V | tail -1)"
[ -n "$v" ] || { echo "mem-server: no claude-mem version under /plugin-cache" >&2; exit 1; }
script="${v}scripts/server-service.cjs"
[ -f "$script" ] || { echo "mem-server: $script not found" >&2; exit 1; }

echo "mem-server: running $script"
exec bun "$script"
