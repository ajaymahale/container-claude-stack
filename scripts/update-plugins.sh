#!/usr/bin/env bash
# Update all git-managed skills + plugin marketplaces under ~/.claude.
# claude-managed plugin binaries (claude-mem, superpowers, etc.) update via the
# `/plugin` command inside a claude session — reminded at the end (not scriptable).
#
# Auto-discovers any directory containing a .git (FS is the source of truth — no
# hardcoded list to maintain). Safe to re-run; logs to logs/update-<date>.log.
set -euo pipefail

LOG_DIR="${LOG_DIR:-$HOME/claude-stack/logs}"
mkdir -p "$LOG_DIR"
log="$LOG_DIR/update-$(date +%F).log"
: > "$log"

pull_git_dirs() {
  local root="$1" label="$2" count=0 failed=0
  echo "== $label ($root) ==" | tee -a "$log"
  while IFS= read -r d; do
    local name; name="$(basename "$d")"
    if git -C "$d" pull --ff-only --quiet >/dev/null 2>&1; then
      echo "  ok   $name" | tee -a "$log"; count=$((count + 1))
    else
      echo "  FAIL $name" | tee -a "$log"; failed=$((failed + 1))
    fi
  done < <(find "$root" -name .git -type d -prune 2>/dev/null | sed 's#/.git$##')
  echo "  -> $count updated, $failed failed" | tee -a "$log"
}

pull_git_dirs "$HOME/.claude/skills" "skills"
pull_git_dirs "$HOME/.claude/plugins/marketplaces" "plugin marketplaces"

cat <<'EOF' | tee -a "$log"

== claude-managed plugin binaries (manual) ==
Update inside a claude session:
  /plugin marketplace update --all
  /plugin update
EOF

echo "Done. Log: $log"
