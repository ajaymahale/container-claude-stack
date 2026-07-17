#!/usr/bin/env bash
# bridge-host-paths.sh — make mounted ~/.claude paths resolve in-container,
# PORTABLY. Reads host paths from settings.json (hook commands) AND plugin
# metadata (installed_plugins.json / known_marketplaces.json installPaths) and
# symlinks each to its container equivalent. Called from /root/.bashrc at start.
#
# Same image works on work Mac (amahale) and home laptop (ajaymahale): the bridge
# mirrors each machine's own paths. Idempotent — safe per shell.
set -e
S=/root/.claude/settings.json

# Host home dir = /Users/<x> or /home/<x> prefix, found in ANY file that carries
# absolute paths. settings.json had them when hooks lived there; now that it's
# hooks-free, plugin metadata (plugins/*.json with absolute installPaths) is where
# they live. Scan settings.json + every plugins/*.json so the symlink is always
# created regardless of which file holds the paths.
home=""
for f in "$S" /root/.claude/plugins/*.json; do
  [ -f "$f" ] || continue
  # `|| true` is load-bearing: under `set -e` a no-match grep (exit 1) inside a
  # command substitution aborts the whole script. Without it the scan dies on the
  # first hooks-free settings.json and never reaches the plugins/*.json that
  # actually carry the host path — leaving every plugin's installPath dangling.
  m=$(grep -oE '/(Users|home)/[^/"]+' "$f" 2>/dev/null | sort -u | head -1 | grep -oE '^/(Users|home)/[^/]+') || true
  [ -n "$m" ] && { home="$m"; break; }
done

if [ -n "$home" ]; then
  # /Users/<hostuser> is baked into the image for the work Mac only (node path);
  # create it on other machines so the symlink below can land inside it.
  mkdir -p "$home"
  # ~/.claude -> /root/.claude (where the mount lives). Makes the absolute paths
  # in plugin metadata resolve, so all marketplace plugins load.
  ln -sfn /root/.claude "$home/.claude"
  # claudio -> BEL emitter (containers have no audio; the bell reaches the host TTY)
  mkdir -p "$home/go/bin"
  printf '#!/usr/bin/env sh\nprintf "\\a"\n' > "$home/go/bin/claudio"
  chmod +x "$home/go/bin/claudio"
fi

# Every .../bin/node path referenced -> the container's node (covers any nvm version).
node_bin="$(command -v node 2>/dev/null || true)"
if [ -n "$node_bin" ]; then
  grep -oE '/(Users|home)/[^"]*bin/node' "$S" 2>/dev/null | sort -u | while IFS= read -r np; do
    [ -n "$np" ] || continue
    mkdir -p "$(dirname "$np")"
    ln -sfn "$node_bin" "$np"
  done
fi
