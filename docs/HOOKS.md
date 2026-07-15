# Hooks in the container (P5 reconciliation)

## The situation

`~/.claude/settings.json` defines 17 hooks. All are **host-workflow** and all
reference host-only paths/binaries, so every one errors when claude runs in the
container:

| hook input | command | why it fails in-container |
|---|---|---|
| PreToolUse / PostToolUse / SessionStart / Stop / etc. | `node ~/.claude/hooks/gsd-*.js` (gsd workflow) | `/Users/amahale/.nvm/.../node` absent; gsd is a host project-flow tool |
| PreToolUse | `rtk hook claude` | `rtk` (host token proxy) not installed |
| PostToolUse | `bash ~/.claude/hooks/gsd-graphify-update.sh` | calls `graphify` against `graphify-out/` (host, wow-pic-specific) |
| Notification | `/Users/amahale/go/bin/claudio` | host go binary (sound) |

Two independent failure causes:
1. **Path mismatch** — commands hardcode `/Users/amahale/...`; container home is `/root`.
2. **Missing binaries** — `node` (nvm path), `rtk`, `graphify`, `claudio` aren't in the image.

None of these hooks are useful in a generic dev container (they're project-flow
/ token-opt / host-graph / sound). The errors are **cosmetic — claude runs fine**.

## Options

1. **Accept (do nothing).** Errors are non-fatal noise. Zero work. Fine if the
   noise doesn't bother you.
2. **Hooks-stripped settings overlay (recommended).** `cc-launch` generates a
   copy of `~/.claude/settings.json` with the `hooks` key removed and mounts it
   over `/root/.claude/settings.json` in-container. Plugins/env/everything-else
   preserved; host-workflow hooks silenced. Caveat: untested whether a file `-v`
   cleanly overrides the `~/.claude` dir mount — needs a verify cycle.
3. **Per-hook container guards.** Add `if [ -f /run/.containerenv ]; then exit 0; fi`
   to each hook script. Fragile — the scripts are plugin-managed (gsd updates
   overwrite the guard).

## Recommendation

Option 2 (strip-overlay). Clean, automatic, preserves plugins. Implementing it
is a small `cc-launch` addition + one verify cycle to confirm the overlay mounts
over the dir-mount. Say the word and I add it.
