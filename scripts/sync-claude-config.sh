#!/usr/bin/env bash
# sync-claude-config.sh — bundle ~/.claude (plugins, skills, hooks, settings) for
# transfer between machines, so the container has the same claude ecosystem on each.
#
# The container mounts each machine's OWN ~/.claude — plugins/skills/hooks come via
# that mount, not via this repo. Run this on the SOURCE machine (the one with the
# full setup); transfer the tarball to the target and extract there.
#
# Selective: bundles only what CANNOT be rebuilt from this repo — settings, authored
# hooks/commands/agents, CLAUDE.md. Excludes big/private session data (projects, logs,
# file-history, backups, chrome, downloads, cache) — those stay machine-local.
#
# skills/ and plugins/ are deliberately NOT bundled: install.sh rebuilds both from
# skills.yaml + plugins.yaml on the target. Shipping them meant ~824M of derived state
# (643M of it gsd-core's node_modules), the source machine's binaries rather than the
# target's, and a stale tsconfig.build.tsbuildinfo that makes the target's gsd-core
# build print "Build complete" and exit 0 while emitting nothing.
set -euo pipefail

OUT="${1:-$HOME/claude-config.tgz}"

# Candidate paths (relative to $HOME). Only existing ones are bundled.
candidates=(
  .claude/hooks .claude/commands .claude/agents
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
  ./install.sh     # clones+builds skills, installs plugins, builds image
  cc-launch        # enter the container

Order matters: extract FIRST. install.sh merges claude-settings.json into
~/.claude/settings.json, so extracting afterwards would overwrite that merge with
the source machine's file.

Notes:
  - skills/ and plugins/ are NOT in this tarball — install.sh rebuilds them from
    skills.yaml + plugins.yaml, on the target's own architecture. That also avoids
    shipping the source machine's node_modules and build caches.
  - The dynamic bridge (bin-container/bridge-host-paths.sh) symlinks /Users/<user>
    paths found in settings.json + plugins/*.json (absolute installPaths) so they
    resolve in the container. Those plugin JSONs are written by install-plugins.sh
    on the target, so the bridge finds the target's own paths.
EOF
