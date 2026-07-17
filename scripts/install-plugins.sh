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

# Run a claude-plugin CLI call, surface a clear result, NEVER hide failures.
# (The old `| grep -viE ... || true` swallowed real errors — marketplaces
# silently failed to add and the only signal was an empty `plugin list`.)
run_cli() {   # $1 = label, rest = claude plugin args
  printf '  %s\n' "$1"
  shift                                   # drop the label — without this it was
                                          # passed to the CLI as the subcommand,
                                          # and every call died with
                                          # "unknown command '<label>'"
  out=$(claude plugin "$@" 2>&1); rc=$?
  if printf '%s' "$out" | grep -qiE 'already|no changes|up to date|nothing to'; then
    printf '    \033[33m·\033[0m already done\n'
  elif [ "$rc" -ne 0 ]; then
    printf '    \033[31m✗\033[0m FAILED (exit %d):\n' "$rc"
    printf '%s\n' "$out" | sed 's/^/      /'
  else
    printf '    \033[32m✓\033[0m ok\n'
  fi
}

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
        mkt)  run_cli "marketplace add  $item" marketplace add "$item" ;;
        plug) run_cli "install          $item" install "$item" ;;
      esac
      ;;
  esac
done < "$YAML"

echo
echo "Done. Verify: claude plugin list"
