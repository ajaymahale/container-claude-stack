#!/usr/bin/env bash
# install.sh — one-shot setup of the claude-stack ecosystem on a machine.
# Runs every layer in order with progress, skipping what's already done.
# Interactive steps (token entry, container init) prompt inline.
#
# Usage:  ./install.sh     (after cloning the repo)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
TOTAL=7; STEP=0

c_ok='\033[32m'; c_skip='\033[33m'; c_err='\033[31m'; c_dim='\033[2m'; c_off='\033[0m'
step() { STEP=$((STEP+1)); echo; printf '======== [%d/%d] %s ========\n' "$STEP" "$TOTAL" "$1"; }
ok()   { printf "  ${c_ok}✓${c_off} %s\n" "$1"; }
skip() { printf "  ${c_skip}·${c_off} %s (skipped — already done)\n" "$1"; }
warn() { printf "  ${c_skip}!${c_off} %s\n" "$1"; }
die()  { printf "  ${c_err}✗${c_off} %s\n" "$1"; exit 1; }

echo "claude-stack installer"
echo "--------------------"
echo "Installs: skills + plugins → tokens → container init + build."
echo "Needs a runtime already installed: podman, OR OrbStack/docker."
[ -t 0 ] && { read -r -p "Proceed? [y/N] " ans; case "${ans:-}" in y|Y) ;; *) echo "aborted"; exit 0;; esac; }
START=$SECONDS

# ---- pre-flight ----
step "pre-flight checks"
for b in git node npm claude; do
  command -v "$b" >/dev/null 2>&1 && ok "$b" || die "missing dependency: $b — install it first"
done
# bun — plugin hooks (caveman, ponytail, claude-mem) require it; install if missing
# so the host matches the image (where bun is baked).
command -v bun >/dev/null 2>&1 && ok "bun" || {
  warn "bun missing — installing (plugin hooks require it)"
  curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1 || die "bun install failed"
  export PATH="$HOME/.bun/bin:$PATH"
  ok "bun installed (restart shell if not yet on PATH)"
}
command -v container >/dev/null 2>&1 || {
  warn "container tool missing — installing @aerovato/container"
  npm install -g @aerovato/container || die "npm install -g @aerovato/container failed"
}
ok "container tool"
if   command -v podman >/dev/null 2>&1; then ok "runtime: podman"
elif command -v docker  >/dev/null 2>&1; then ok "runtime: docker (OrbStack?)"
else die "no podman/docker — install a runtime first (OrbStack: brew install --cask orbstack)"; fi

# ---- 1. skills ----
step "skills — clone 8 repos + copy personal"
"$ROOT/scripts/install-claude-config.sh" || die "skill install failed"
ok "skills installed"

# ---- 2. plugins ----
step "plugins — 8 marketplaces + 17 plugins (non-interactive CLI)"
"$ROOT/scripts/install-plugins.sh" || die "plugin install failed"
ok "plugins installed"

# ---- 3. tokens ----
step "provider tokens → macOS Keychain"
if security find-generic-password -a "$USER" -s cc-zai-token -w >/dev/null 2>&1; then
  skip "tokens already in Keychain"
else
  echo "  Enter tokens when prompted (z.ai / deepinfra / deepseek; blank to skip):"
  "$ROOT/secrets/secrets.bootstrap.sh" || warn "token entry incomplete — re-run secrets/secrets.bootstrap.sh later"
fi

# ---- 4. container init ----
step "container init (interactive onboarding)"
if [ -d "$HOME/.code-container" ]; then
  skip "~/.code-container exists"
else
  echo "  Follow the prompts: choose your runtime, enable the claude harness."
  container init || die "container init failed"
fi

# ---- 5. wire config into build context ----
step "wire config (Dockerfile.User + bin-container + live .claude link)"
mkdir -p "$HOME/.code-container"
cp "$ROOT/Dockerfile.User" "$HOME/.code-container/Dockerfile.User"
rm -rf "$HOME/.code-container/bin-container"
cp -r "$ROOT/bin-container" "$HOME/.code-container/bin-container"
ok "config copied (real files — runtime-portable)"

# The container bind-mounts configs/.claude at /root/.claude, but container init
# only snapshots ~/.claude into it ONCE (skip-if-exists) and never refreshes — so
# skills/plugins installed after init never reach the container. Replace the
# snapshot with a symlink to live ~/.claude: one dir, live in both, no rebuild.
CLINK="$HOME/.code-container/configs/.claude"
mkdir -p "$HOME/.code-container/configs"
if [ -e "$CLINK" ] && [ ! -L "$CLINK" ]; then
  mv "$CLINK" "$CLINK.stale.$(date +%s)"
  warn "shelved stale snapshot → configs/.claude.stale.*"
fi
if [ -L "$CLINK" ]; then
  skip "configs/.claude already → ~/.claude"
else
  ln -s "$HOME/.claude" "$CLINK"
  ok "configs/.claude → ~/.claude (container sees live host config)"
fi

# ---- 6. build image ----
step "build image  (~10-15 min first time; rtk compiles from source)"
t0=$SECONDS
container build user || die "image build failed"
ok "image built in $((SECONDS - t0))s"

# ---- 7. enter ----
step "enter the container"
printf "  Ready. Enter with:\n    ${c_dim}cc-launch${c_off}   (or ${c_dim}%s/bin/cc-launch${c_off})\n" "$ROOT"
echo "  First run adds the providers.env mount + shared-mem volume, then enters."
echo
printf "======== complete — %dm%02ds ========\n" $((SECONDS/60)) $((SECONDS%60))
