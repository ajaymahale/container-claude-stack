# /root/.aliases.sh — provider launchers migrated from host ~/.zshrc.
# Sourced by /root/.bashrc inside the container.
#
# Tokens are NOT here. They live in /root/.secrets/providers.env, mounted
# read-only at container start by bin/cc-launch (which reads the macOS
# Keychain on the host and writes the file). Nothing secret is baked into
# the image or committed to git.
#
# Each function sets its provider env per-invocation, so different herdr panes
# in the same container can run different providers simultaneously.

# herdr binary lands in /root/.local/bin (installer default); ensure interactive
# shells find it.
export PATH="/root/.local/bin:$PATH"

# Claude Code binary is relocated to /opt/claude in the image (see Dockerfile.User)
# — /root/.local/share/claude is mounted from the macOS host and can't run on Linux.

# Load provider secrets if the mount is present.
if [ -f /root/.secrets/providers.env ]; then
  set -a
  . /root/.secrets/providers.env
  set +a
fi

# z.ai — glm-5.2[1m]
ccg() {
  ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic" \
  ANTHROPIC_AUTH_TOKEN="${ZAI_TOKEN:?ZAI_TOKEN missing — did cc-launch mount providers.env?}" \
  ANTHROPIC_MODEL="glm-5.2[1m]" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="glm-5.2[1m]" \
  ANTHROPIC_SMALL_FAST_MODEL="glm-5-turbo" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-5-turbo" \
  DISABLE_NON_ESSENTIAL_MODEL_CALLS=1 \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  CLAUDE_CODE_EFFORT_LEVEL="max" \
  claude --dangerously-skip-permissions "$@"
}

# anthropic (native login; no token)
ccm() {
  claude --dangerously-skip-permissions "$@"
}

# deepinfra — deepseek-ai models hosted on DeepInfra
ccdideep() {
  ANTHROPIC_BASE_URL="https://api.deepinfra.com/anthropic" \
  ANTHROPIC_AUTH_TOKEN="${DEEPINFRA_TOKEN:?DEEPINFRA_TOKEN missing — did cc-launch mount providers.env?}" \
  ANTHROPIC_MODEL="deepseek-ai/DeepSeek-V4-Pro[1m]" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-ai/DeepSeek-V4-Pro[1m]" \
  ANTHROPIC_SMALL_FAST_MODEL="deepseek-ai/DeepSeek-V4-Flash" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-ai/DeepSeek-V4-Flash" \
  DISABLE_NON_ESSENTIAL_MODEL_CALLS=1 \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  CLAUDE_CODE_EFFORT_LEVEL="max" \
  claude --dangerously-skip-permissions "$@"
}

# deepseek (native) — deepseek-v4-pro[1m]
ccd() {
  ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic" \
  ANTHROPIC_AUTH_TOKEN="${DEEPSEEK_TOKEN:?DEEPSEEK_TOKEN missing — did cc-launch mount providers.env?}" \
  ANTHROPIC_MODEL="deepseek-v4-pro[1m]" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-pro[1m]" \
  ANTHROPIC_SMALL_FAST_MODEL="deepseek-v4-flash" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-flash" \
  DISABLE_NON_ESSENTIAL_MODEL_CALLS=1 \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  CLAUDE_CODE_EFFORT_LEVEL="max" \
  claude --dangerously-skip-permissions "$@"
}

# claude code through headroom proxy (anthropic path; resolves only when the
# container is on the compose network — see P3).
ccmh() {
  ANTHROPIC_BASE_URL="http://headroom-proxy:8787" \
  claude --dangerously-skip-permissions "$@"
}

# claude-mem worker (bun)
claude-mem() {
  local script
  script="$(ls -d /root/.claude/plugins/cache/thedotmack/claude-mem/*/scripts/worker-service.cjs 2>/dev/null | sort -V | tail -1)"
  [ -n "$script" ] || { echo "claude-mem worker not found in /root/.claude/plugins"; return 1; }
  bun "$script" "$@"
}
