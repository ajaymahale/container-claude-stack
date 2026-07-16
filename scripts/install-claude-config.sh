#!/usr/bin/env bash
# install-claude-config.sh — set up the claude skill ecosystem on a machine from
# source manifests.
#   1. Clone online skill repos (skills.yaml), shallow, into ~/.claude/skills/<name>/
#      and symlink each sub-skill to the top level (claude discovers top-level skills).
#   2. Copy authored skills (personal-skills/) — these have no upstream.
# Plugins install separately via /plugin using plugins.yaml (marketplaces).
#
# Re-runnable: existing clones are git-pulled; existing symlinks/personal skills
# are left in place (personal skills overwritten with the repo copy).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"   # claude-stack repo root
SKILLS="$HOME/.claude/skills"
mkdir -p "$SKILLS"

# 1. online skill repos
while IFS=' ' read -r name url; do
  [ -z "$name" ] && continue
  dest="$SKILLS/$name"
  if [ -d "$dest/.git" ]; then
    echo "  update  $name"
    git -C "$dest" pull --ff-only --quiet 2>/dev/null || echo "    (pull failed, leaving as-is)"
  else
    echo "  clone   $name  <-  $url"
    git clone --quiet --depth 1 "$url" "$dest"
  fi
  # symlink every <dir>/SKILL.md under the clone to the top level
  while IFS= read -r sm; do
    sdir="$(dirname "$sm")"; sname="$(basename "$sdir")"
    [ "$sdir" = "$dest" ] && continue          # skill at repo root — $dest is already the skill dir
    [ -e "$SKILLS/$sname" ] || ln -s "$sdir" "$SKILLS/$sname"
  done < <(find "$dest" -name SKILL.md -not -path '*/node_modules/*' 2>/dev/null)
done < <(awk '/- name:/{n=$3} /url:/{if(n){print n" "$2; n=""}}' "$ROOT/skills.yaml")

# 2. authored skills (no upstream) — copy into place
if [ -d "$ROOT/personal-skills" ]; then
  echo "  copy    personal-skills/"
  cp -r "$ROOT/personal-skills/." "$SKILLS/"
fi

echo
echo "Done. Skills under $SKILLS."
echo "Next: install plugins via /plugin using the marketplaces in plugins.yaml."
echo "Updates: git pull in each cloned repo, or scripts/update-plugins.sh."
