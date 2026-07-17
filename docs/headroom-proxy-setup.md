# Headroom proxy with z.ai / DeepSeek

Goal: automatic context compression for Claude Code via the **headroom proxy**,
working when the upstream LLM is **z.ai (GLM)** or **DeepSeek** — not just Anthropic.

This is a spec you can run on a fresh machine (e.g. the home laptop). Work
through it top to bottom.

## Background — two headroom halves

| Half | What it does | Status |
|---|---|---|
| **MCP server** (`headroom_compress` / `headroom_retrieve` / `headroom_stats`) | *Manual* compression — Claude calls the tool when it wants. Provider-agnostic. | Already active. |
| **Proxy** (`headroom proxy` / `headroom wrap claude`) | *Automatic* compression of every request. This is the prize. | Not wired. The old `bin-container/ccmh` pointed at a compose service that was never built. |

This spec is about the **proxy** half. The MCP half already works everywhere.

The old compose `headroom-proxy` service (`compose/docker-compose.yml`, commented)
is the **wrong shape** — drop it. The path is `headroom wrap claude`, which starts
its own proxy on `:8787`.

## Provider facts (from the launchers)

**z.ai** — `bin-container/ccg`:
```
ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic
ANTHROPIC_AUTH_TOKEN=$ZAI_TOKEN        # keychain: cc-zai-token
ANTHROPIC_MODEL=glm-5.2[1m]
```
**DeepSeek** — `bin-container/ccd`:
```
ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
ANTHROPIC_AUTH_TOKEN=$DEEPSEEK_TOKEN   # keychain: cc-deepseek-token
ANTHROPIC_MODEL=deepseek-v4-pro[1m]
```
Both speak the Anthropic `/v1/messages` protocol — that's why the `ANTHROPIC_BASE_URL`
override works. headroom is multi-provider (forwards Anthropic · OpenAI · Bedrock),
so forwarding to these is plausible — but **verify before building** (next section).

## Step 0 — prereqs on the home laptop

```bash
# headroom CLI (the proxy half). uv preferred (self-contained venv).
command -v headroom || uv tool install "headroom-ai[all]"
headroom --version          # expect 0.25.x or newer
headroom doctor             # health check; must pass
```
Home laptop has **no Zscaler**, so no TLS flag needed. (Work mac does — see
"Zscaler" below.)

## Step 1 — THE decision experiment

`headroom wrap claude` sets `ANTHROPIC_BASE_URL` to its own proxy. The open
question: does it then forward upstream to the **pre-set z.ai base URL**, or
hardcode real Anthropic (needing `ANTHROPIC_API_KEY`)? That decides everything.

Run this on the home laptop (host terminal, no container):

```bash
# z.ai token from keychain (same one cc-launch writes to providers.env)
ZAI=$(security find-generic-password -a "$USER" -s cc-zai-token -w)

# pre-set z.ai as the upstream, then wrap claude through headroom
ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic" \
ANTHROPIC_AUTH_TOKEN="$ZAI" \
ANTHROPIC_MODEL="glm-5.2[1m]" \
ANTHROPIC_SMALL_FAST_MODEL="glm-5-turbo" \
DISABLE_NON_ESSENTIAL_MODEL_CALLS=1 \
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  headroom wrap claude --tool-search true -v
```

In **another terminal**, while that session is live:
```bash
headroom dashboard        # live view: which provider is traffic hitting?
headroom perf             # token savings so far
```

### Read the result

Ask the running Claude something, then check the dashboard / perf:

- **Traffic hits z.ai (model shows glm-5.2, requests succeed)** → ✅ headroom
  forwards to the pre-set upstream. Proceed to Step 2 (build the launcher).
- **Requests fail / dashboard shows anthropic.com / asks for `ANTHROPIC_API_KEY`**
  → headroom hardcodes Anthropic upstream. The proxy won't ride on z.ai directly.
  Options: (a) chain a translating proxy (cliproxyapi) in front of headroom, or
  (b) skip the proxy, keep using the **MCP server** you already have. Most likely
  you'll pick (b) — the MCP tools give most of the win without the proxy plumbing.

## Step 2 — build `ccg-h` / `ccd-h` (only if Step 1 forwarded to z.ai)

A headroom-wrapped variant of the existing `ccg`/`ccd` launchers. Create
`bin-container/ccg-h` (z.ai + headroom) mirroring `ccg`, but `exec`ing through
`headroom wrap` instead of bare `claude`:

```bash
#!/usr/bin/env bash
# z.ai (glm-5.2[1m]) through the headroom proxy — automatic context compression
[ -f /root/.secrets/providers.env ] && { set -a; . /root/.secrets/providers.env; set +a; }
ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic" \
ANTHROPIC_AUTH_TOKEN="${ZAI_TOKEN:?ZAI_TOKEN missing — run cc-launch}" \
ANTHROPIC_MODEL="glm-5.2[1m]" \
ANTHROPIC_DEFAULT_SONNET_MODEL="glm-5.2[1m]" \
ANTHROPIC_SMALL_FAST_MODEL="glm-5-turbo" \
ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-5-turbo" \
DISABLE_NON_ESSENTIAL_MODEL_CALLS=1 \
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
CLAUDE_CODE_EFFORT_LEVEL="max" \
  exec headroom wrap claude --tool-search true "$@"
```
Make `ccd-h` the same way (DeepSeek env + `headroom wrap`). `chmod +x` both,
rebuild the image (`cp -r bin-container ~/.code-container/ && container build user`).

Then **delete the old `ccmh`** (pointed at a dead compose service) and the
commented `headroom-proxy` block in `compose/docker-compose.yml`.

> Note: `headroom wrap claude` starts its own proxy and re-points `ANTHROPIC_BASE_URL`
> at it — so the z.ai base URL above is what headroom *forwards to*, not what Claude
> dials directly. That's why Step 1 must confirm headroom honors the pre-set upstream.

## Step 3 — verify

```bash
ccg-h                       # inside container, or host equivalent
# in the session, confirm compression is live:
headroom perf               # tokens saved > 0
headroom dashboard          # shows z.ai provider + running savings
```
Send a request that returns a big tool output (e.g. a directory listing); the
dashboard should show it compressed before hitting z.ai.

## Zscaler (work mac only)

The work mac sits behind Zscaler. headroom's upstream client is Python 3.13+,
which rejects the Zscaler inspection root with *"Basic Constraints of CA cert not
marked critical"*. Set this whenever the proxy runs on the work mac:

```bash
export HEADROOM_TLS_STRICT=0     # narrows TLS strict mode only; keeps signature/expiry checks
```
Home laptop (no Zscaler) does **not** need this.

## Open questions to resolve on the machine

1. Does `headroom wrap claude` honor a pre-set `ANTHROPIC_BASE_URL` as upstream? (Step 1)
2. Does headroom's `--tool-search true` keep Claude Code's tool deferral working
   through the proxy on z.ai? (the `--help` warns a custom base URL can force eager
   tool-schema loading, issue #746 — `--tool-search` mitigates it; confirm tokens
   stay low).
3. Container vs host: run headroom on the host first (cleaner experiment), then
   decide whether to bake `headroom-ai` into `Dockerfile.User` for in-container use.

## Reference

- Repo: https://github.com/headroomlabs-ai/headroom
- PyPI: https://pypi.org/project/headroom-ai/
- Modes: `headroom proxy --port 8787` (drop-in) · `headroom wrap claude` (full)
