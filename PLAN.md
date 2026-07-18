# Claude Container Stack — Plan (GSD-quick)

Lightweight GSD-quick plan: clear goal, atomic phases, verification per phase.
This file is the first artifact of the `claude-stack` repo. Build outward from here.

## Goal

Run multiple isolated Claude Code instances (z.ai / anthropic / deepseek /
headroom) inside Docker containers managed by `aerovato/container`, with:

- shared plugins + skills + MCP (`~/.claude`, mounted — zero rebuild on update). NOTE: MCP `mcpServers` live in `~/.claude.json` (a file at `~/`), NOT under `~/.claude` — so the dir mount alone does NOT carry them. `mcp.json` + `scripts/install-mcp.sh` declare + merge them into `~/.claude.json`; `bin/cc-launch` bind-mounts that file RW into the container so both sides see one config (accepted host+container write race, same as the `~/.claude` mount).
- shared brain (claude-mem server) across all instances
- shared LLM proxy (headroom) where compatible
- secrets in macOS Keychain — never in image, git, or `.zshrc`
- one-command export to the home laptop via a private GitHub repo

## Decisions (locked)

| Area | Decision |
|---|---|
| Runtime (work Mac) | Podman (`"runtime": "podman"`) — switched after Docker Desktop buildkit corruption; clean VM/storage |
| Runtime (home laptop) | OrbStack (`"runtime": "docker"`) |
| Instance model | Hybrid — one shared container (mprocs) + dedicated containers for long unattended jobs |
| Shared services | mem-server + headroom-proxy as separate `docker compose` containers on a network |
| Multiplexer | **mprocs** (default) — alt: tmux + ccmux |
| Secrets | macOS Keychain; host launcher reads keychain → injects `-e` at `container run`/`exec` |
| Plugins | `plugins.yaml` catalog + weekly updater; `~/.claude` mounted so updates are live, no rebuild |
| Export | private GitHub repo → clone + `import.sh` on laptop; secrets re-entered via bootstrap prompt |

## Invariants (every phase obeys)

1. Tokens: keychain only. Never `.zshrc`, never image, never git.
2. `~/.claude` mounted, not baked. Plugin/skill updates = live in containers.
3. One image, N processes. Providers are env switches, not separate images.
4. `runtime` is per-machine — set by `container init` (podman on work Mac, docker/OrbStack on home). Repo `settings.json` is a template only; do not clobber the live one.
5. Export = git config, not image tars. Rebuild native on each machine.

## Open / exploration (non-blocking — P7)

- **headroom custom-upstream for z.ai/deepseek**: unverified whether headroom accepts a
  non-Anthropic upstream. If not → headroom only on the `ccm` path; z.ai/deepseek route direct.
- **`[1m]` context drop** via custom `ANTHROPIC_BASE_URL` (headroom issue #1158) — affects z.ai 1M models through any proxy.
- **mem-server N-writer concurrency** — claude-mem is client-server; verify storage handles concurrent writers in P3.

## Phases

### P1 — Scaffold repo + image config
- [ ] `git init`, `.gitignore` (`logs/`, `secrets.env`, `*.tar`, `secrets/*.env`)
- [ ] `settings.json` — `runtime: docker`, `enabledHarnesses: [claude]`, `systemMounts`
- [ ] `Dockerfile.User` — zsh, bun, headroom (`pip install headroom-ai[all]`), mprocs, git, fzf, ripgrep
- [ ] `.zshrc.container` — thin aliases (`claude --dangerously-skip-permissions`); tokens via env, not baked
- [ ] `README.md` — overview + pointer to this plan
- **Verify**: `container build user` succeeds; `container` drops to shell with zsh + mprocs on PATH.

### P2 — Secrets + host launcher
- [ ] `secrets/secrets.bootstrap.sh` — prompts for each token, stores via `security add-generic-password`
- [ ] `secrets/secrets.env.example` — template (no values)
- [ ] `bin/cc-launch <provider>` — reads keychain for that provider, runs `container run … -e ANTHROPIC_AUTH_TOKEN=… -e ANTHROPIC_BASE_URL=… -e ANTHROPIC_MODEL=…`
- **Verify**: `cc-launch zai` starts a container whose env has only the z.ai token; grep image layers + git for token → absent.

### P3 — Shared services (compose)
- [ ] `compose/docker-compose.yml` — `mem-server` + `headroom-proxy` services, named volumes, private network
- [ ] `compose/mem/Dockerfile` — claude-mem server (bun worker-service)
- [ ] `compose/proxy/Dockerfile` — headroom proxy on :8787
- [ ] Point each claude container's MCP config at `http://mem-server:port`
- **Verify**: 2 claude containers write to mem-server, both see each other's observations; headroom reachable at `http://headroom-proxy:8787`.

### P4 — Instances (mprocs hybrid)
- [ ] `mprocs.yaml` — one entry per provider (`ccg`, `ccdideep`, `ccm`, `ccmh`)
- [ ] `bin/cc-shared` — enter shared container, launch `mprocs` with the provider layout
- [ ] `bin/cc-bg <provider>` — spin a dedicated container for a long unattended job
- **Verify**: `cc-shared` shows 4 live panels; killing one provider's process doesn't kill others; `cc-bg zai` runs an unattended job isolated from the shared container.

### P5 — Plugin catalog + updater
- [x] `plugins.yaml` — plugins + skills (name, source, marketplace). **MCP split out** → `mcp.json` (different mechanism: direct `~/.claude.json` merge, no `claude mcp` CLI, so the z.ai token stays out of argv).
- [x] `scripts/install-mcp.sh` — merges `mcp.json` into `~/.claude.json` `mcpServers`; resolves `$ZAI_TOKEN` from keychain (host) / `providers.env` (container). Wired as install.sh step 4. `bin/cc-launch` bind-mounts `~/.claude.json` RW into the container so both sides share one MCP config.
- [ ] `scripts/update-plugins.sh` — reads manifest, runs each `update`, logs to `logs/update-<date>.log`
- [ ] `launchd` plist — weekly run on host (updates propagate to containers via mount, no rebuild)
- [x] **stdio MCP binaries baked in image:** `headroom` (pip headroom-ai[all]) + `markitdown-mcp` (pip) in `Dockerfile.User`; `playwright`/`zai` use the image node. `serena` dropped (not wanted). Host-side markitdown: `uv tool install markitdown-mcp`.
- **Verify**: `update-plugins.sh` runs clean; a changed skill is visible in-container next session without `container build`; `/mcp` in-container lists all 6 servers.

### P6 — Export / import
- [ ] Private GitHub repo `claude-stack`
- [ ] `scripts/export.sh` — `git push` (secrets excluded by `.gitignore`)
- [ ] `scripts/import.sh` — clone-target: `install.sh` (symlink configs into `~/.code-container`, `npm i -g @aerovato/container`) + `secrets.bootstrap.sh` + `docker compose up -d mem proxy` + `container build`
- [ ] `scripts/install.sh` — symlink `settings.json` + `Dockerfile.User` into `~/.code-container/`
- **Verify**: on the home laptop, fresh clone → `import.sh` → working stack; no token transmits via git.

### P7 — Exploration (headroom compat)
- [ ] Check headroom config schema for a custom-upstream env (e.g. `HEADROOM_UPSTREAM_URL`)
- [ ] If yes → route z.ai/deepseek through headroom; document in `docs/HEADROOM-EXPLORATION.md`
- [ ] If no → headroom on `ccm` only; z.ai/deepseek direct. Note `[1m]` context-drop caveat.
- **Verify**: documented finding + working config (or clean fallback).

## Repo layout (to build through P1–P6)

```
~/claude-stack/                      private GitHub repo
├── README.md
├── PLAN.md                          this file
├── .gitignore
├── settings.json                    → ~/.code-container/settings.json
├── Dockerfile.User                  → ~/.code-container/Dockerfile.User
├── .zshrc.container                 thin aliases (no tokens)
├── compose/
│   ├── docker-compose.yml           mem-server + headroom-proxy, network, volumes
│   ├── mem/Dockerfile
│   └── proxy/Dockerfile
├── bin/
│   ├── cc-launch <provider>         keychain → -e → container run/exec
│   ├── cc-shared                    enter shared container, start mprocs layout
│   └── cc-bg <provider>             dedicated container for long job
├── secrets/
│   ├── secrets.bootstrap.sh         prompt + store in keychain (no values committed)
│   └── secrets.env.example
├── plugins.yaml                     catalog
├── scripts/
│   ├── install.sh
│   ├── update-plugins.sh
│   ├── rebuild.sh
│   ├── export.sh
│   └── import.sh
└── docs/
    ├── ARCHITECTURE.md
    ├── SECRETS.md
    └── HEADROOM-EXPLORATION.md      (P7)
```

## Runtime facts (from aerovato/container docs)

- Harness configs (`~/.claude`) are **mounted** into every container → shared, live, no rebuild.
- `settings.json` keys that matter: `runtime`, `enabledHarnesses`, `enabledTools`, `systemMounts`, `dockerRunFlags`, `dockerExecFlags`, `dockerfileCore`.
- `Dockerfile.User` is `FROM localhost/aerovato/container-v3-harness:latest` → add packages there, rebuild via `container build user`.
- Per-container extra flags: `container run /path -- -p 8080:80` or `-- -e FOO=bar`.

## Next action

Confirm multiplexer pick (mprocs vs tmux+ccmux), then execute **P1** (scaffold + image config).
