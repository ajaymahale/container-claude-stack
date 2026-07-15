# claude-stack

Isolated Claude Code containers (z.ai / anthropic / deepseek / headroom) on
`aerovato/container`, with shared plugins+skills, a shared brain (claude-mem),
a shared LLM proxy (headroom), secrets in macOS Keychain, and one-command
export to a home laptop.

See **[PLAN.md](./PLAN.md)** for the full phase plan (P1–P7) and locked decisions.

## What lives here

| File | Purpose |
|---|---|
| `PLAN.md` | GSD-quick plan: goal, phases, verification, open items |
| `settings.json` | → `~/.code-container/settings.json` (runtime, harnesses, mounts) |
| `Dockerfile.User` | → `~/.code-container/Dockerfile.User` (bundles herdr + aliases; headroom is a P3 service) |
| `bin-container/` | Provider launchers (ccm/ccg/ccdideep/ccd/ccmh/claude-mem) → `/usr/local/bin`; shell-independent, work in herdr panes |

Still to build (P2–P6): `bin/cc-launch`, `secrets/`, `compose/`, `plugins.yaml`,
`scripts/{install,update-plugins,rebuild,export,import}.sh`.

## Multiplexer: herdr

[ogulcancelik/herdr](https://github.com/ogulcancelik/herdr) — agent multiplexer.
Per-agent status (blocked/working/done), detach/reattach over SSH, socket API so
agents self-coordinate. Bundled into the image via `Dockerfile.User`.

## Invariants (every phase obeys)

1. Tokens in macOS Keychain only — never image, never git, never `.aliases.sh`.
2. `~/.claude` is **mounted** (not baked) → plugin/skill updates are live, no rebuild.
3. One image, N processes. Providers are env switches, not separate images.
4. `runtime` is per-machine — same `settings.json` works for Docker Desktop + OrbStack.
5. Export = git config, not image tars.

## Bootstrap (run once, per machine)

> `container` is interactive and owns `~/.code-container`. We symlink our files
> in after init so this repo stays the source of truth.

```bash
# 1. install the container tool (if not already)
npm install -g @aerovato/container

# 2. run onboarding (choose docker; enable the claude harness)
container init

# 3. point it at this repo's config (additive files only).
#    Do NOT symlink settings.json — `container init` owns it (runtime is
#    per-machine: podman here, docker/OrbStack on the home laptop).
ln -sf "$PWD/Dockerfile.User" ~/.code-container/Dockerfile.User
cp    "$PWD/.aliases.sh"     ~/.code-container/.aliases.sh     # real file — buildah won't follow a symlink that escapes the context
# (re-run this cp after editing .aliases.sh, before `container build user`)

# 4. build the image (first build ~5+ min)
container build user

# 5. enter a container and verify
container
# inside:
#   herdr --version      # agent multiplexer present
#   bun --version        # claude-mem runtime (from the 'bun' tool pack)
#   type ccg ccm ccdideep ccd ccmh   # provider functions loaded
```

## Updating the image (rebuild workflow)

After editing `Dockerfile.User` or `bin-container/`, a rebuild alone is NOT enough —
`container` re-attaches to the existing per-project container (old image). Full cycle:

```bash
cp -r ~/claude-stack/bin-container ~/.code-container/bin-container   # scripts into the build context
container build user
container remove          # destroy the stale container
container                 # create fresh from the new image
```

Gotchas learned during P1:
- **claude binary** — the harness stage installs a Linux claude under
  `/root/.local/share/claude`, which is **mounted from the macOS host** at runtime
  (host Mach-O → `Exec format error`). `Dockerfile.User` relocates the Linux
  binary to `/opt/claude` and repoints the symlink. Don't drop that step.
- **bun / herdr** — install to paths outside the harness-config mounts
  (`/root/.bun`, `/root/.local/bin`) so they survive runtime.

## Provider tokens

Not handled in P1. P2 adds `bin/cc-launch` (reads Keychain → mounts
`/root/.secrets/providers.env` → starts container) and
`secrets/secrets.bootstrap.sh` (stores tokens in Keychain).

Store them ahead of P2 with:

```bash
security add-generic-password -a "$USER" -s 'cc-zai-token'       -w 'tok_zai'       -U
security add-generic-password -a "$USER" -s 'cc-deepinfra-token' -w 'tok_deepinfra' -U
security add-generic-password -a "$USER" -s 'cc-deepseek-token'  -w 'tok_deepseek'  -U
# anthropic uses native claude login — no token needed for ccm
```
