#!/usr/bin/env bash
# install-plugins.sh — install all marketplaces + plugins declared in plugins.yaml
# via the NON-INTERACTIVE claude plugin CLI:
#   claude plugin marketplace add <source>   (owner/repo or URL)
#   claude plugin install <plugin>@<marketplace>
#
# Re-runnable: already-added/installed entries are skipped (the CLI returns
# non-zero for those; we ignore it). No menu, no clicking.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
YAML="$ROOT/plugins.yaml"
[ -f "$YAML" ] || { echo "plugins.yaml not found at $YAML"; exit 1; }

section=""
echo "== marketplaces =="
while IFS= read -r line; do
  case "$line" in
    \#*|"") continue ;;
    marketplaces:*) section="mkt"; continue ;;
    plugins:*)      section="plug"; echo; echo "== plugins =="; continue ;;
    *" - "*)
      item="${line#*- }"                        # strip "  - " list marker
      item="${item%%#*}"                        # strip trailing comment
      item="$(printf '%s' "$item" | xargs)"     # trim whitespace
      [ -z "$item" ] && continue
      case "$section" in
        mkt)  printf '  marketplace add  %s\n' "$item"
              claude plugin marketplace add "$item" 2>&1 | grep -viE 'already|exist' || true ;;
        plug) printf '  install          %s\n' "$item"
              claude plugin install "$item" 2>&1 | grep -viE 'already|installed|no changes|up to date' || true ;;
      esac
      ;;
  esac
done < "$YAML"

echo
echo "Done. Verify: claude plugin list"
