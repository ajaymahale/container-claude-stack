#!/usr/bin/env bash
# sync-claude-config.sh — bundle ~/.claude (plugins, skills, hooks, settings) for
# transfer between machines, so the container has the same claude ecosystem on each.
#
# The container mounts each machine's OWN ~/.claude — plugins/skills/hooks come via
# that mount, not via this repo. Run this on the SOURCE machine (the one with the
# full setup); transfer the tarball to the target and extract there.
#
# Selective: includes plugins/skills/hooks/commands/agents/settings/CLAUDE.md/
# config.json + ~/.claude.json. Excludes big/private session data (projects, logs,
# file-history, backups, chrome, downloads, cache) — those stay machine-local.
set -euo pipefail

OUT="${1:-$HOME/claude-config.tgz}"

# Candidate paths (relative to $HOME). Only existing ones are bundled.
candidates=(
  .claude/plugins .claude/skills .claude/hooks .claude/commands .claude/agents
  .claude/settings.json .claude/settings.local.json .claude/CLAUDE.md .claude/config.json
  .claude.json
)
paths=()
for p in "${candidates[@]}"; do
  [ -e "$HOME/$p" ] && paths+=("$p")
done
[ "${#paths[@]}" -gt 0 ] || { echo "No ~/.claude content found — run on the source (full-setup) machine."; exit 1; }

tar czf "$OUT" -C "$HOME" "${paths[@]}"
echo "Bundled ${#paths[@]} paths -> $OUT ($(du -h "$OUT" | cut -f1))"
echo
cat <<EOF
Transfer $OUT to the target machine (AirDrop / scp / USB), then ON THE TARGET:

  mkdir -p ~/.claude
  tar xzf /path/to/claude-config.tgz -C "\$HOME"
  cc-launch        # re-enter the container; plugins/skills/hooks are now mounted

Notes:
  - The dynamic bridge (bin-container/bridge-host-paths.sh) symlinks /Users/<user>
    paths found in settings.json + plugins/*.json (absolute installPaths) so they
    resolve in the container. Scan widened beyond settings.json once plugin
    metadata, not hooks, became where those paths live.
  - node_modules ship as the SOURCE machine's binaries. Pure-JS plugins work;
    native-module plugins (e.g. claude-mem tree-sitter) may need a Linux rebuild
    in the target container.
EOF
