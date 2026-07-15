#!/usr/bin/env bash
# bridge-host-paths.sh — make the mounted ~/.claude/settings.json hook commands
# resolve in-container, PORTABLY. Reads whatever host paths THIS machine's
# settings.json references (username / node-version agnostic) and symlinks each
# to its container equivalent. Called from /root/.bashrc at container start.
#
# Same image works on work Mac (amahale) and home laptop (ajaymahale): the bridge
# mirrors each machine's own settings.json paths. Idempotent — safe per shell.
set -e
S=/root/.claude/settings.json
[ -f "$S" ] || exit 0

# Host home dir = /Users/<x> or /home/<x> prefix in any hook command.
home=$(grep -oE '/(Users|home)/[^/"]+' "$S" 2>/dev/null \
       | sort -u | head -1 \
       | grep -oE '^/(Users|home)/[^/]+')

if [ -n "$home" ]; then
  # ~/.claude -> /root/.claude (where the mount actually lives at runtime)
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
