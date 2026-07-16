# GitHub Spec Kit — cheatsheet (vs GSD)

> Source: [github/spec-kit](https://github.com/github/spec-kit) · docs: [github.github.io/spec-kit](https://github.github.io/spec-kit/) ·
> announcement: [GitHub Blog](https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/).
> <span>Not installed locally — researched from source.</span>

**One line:** GitHub's open-source **Spec-Driven Development** toolkit (the 🌱 "Specify" CLI).
Flips code-is-king: **specifications become executable** — define *what*+*why*, refine through
structured phases, let the agent implement. Anti-"vibe coding." **Agent-agnostic** (30+ integrations).

**Install + init** (needs [uv](https://docs.astral.sh/uv/)):
```bash
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@vX.Y.Z
specify init my-project --integration claude-code   # or copilot, gemini-cli, codex, ...
cd my-project                                        # then launch your agent here
```
Commands surface as `/speckit.*` (Claude Code/Copilot/Gemini), `$speckit-*` (Codex skills mode),
`/agents` (Copilot CLI). `specify integration list` to see all 30+.

---

## The pipeline — 7 core commands

| # | Command | Skill | Does |
|---|---|---|---|
| 0 | `/speckit.constitution` | `speckit-constitution` | **First.** Project governing principles (quality, testing, UX, perf) that guide ALL later work. |
| (opt) | `/speckit.clarify` | `speckit-clarify` | Clarify underspecified areas. Run **before** plan. (was `/quizme`) |
| 1 | `/speckit.specify` | `speckit-specify` | Define **what**+**why** — requirements + user stories. *Not* the tech stack. |
| 2 | `/speckit.plan` | `speckit-plan` | Technical implementation plan with your chosen stack + architecture. |
| 3 | `/speckit.tasks` | `speckit-tasks` | Actionable task list from the plan. |
| (opt) | `/speckit.analyze` | `speckit-analyze` | Cross-artifact consistency + coverage. **After** tasks, **before** implement. |
| 4 | `/speckit.implement` | `speckit-implement` | Execute all tasks, build the feature per the plan. |
| 5 | `/speckit.converge` | `speckit-converge` | Assess codebase vs spec/plan/tasks → append remaining work as new tasks. **The loop.** |

**Plus:** `/speckit.taskstoissues` (tasks → GitHub issues), `/speckit.checklist` (custom quality
checklists — *"unit tests for English"* validating requirement clarity/completeness).

**Artifacts:** `.specify/memory/constitution.md`, `specs/` (spec.md, plan.md, tasks.md). Spec persistence across runs.

```
constitution → [clarify] → specify → plan → tasks → [analyze] → implement → converge ↺
       governing         what/why     how       units      coverage     build      loop-to-spec
```

---

## Customization — the priority stack (Spec Kit's superpower)

Templates resolve **top-down at runtime**; first match wins:

| Pri | Layer | Purpose |
|---|---|---|
| 1 | `.specify/templates/overrides/` | one-off project-local tweaks |
| 2 | **Presets** | customize *how it works* — override templates/commands (compliance, DDD, language, test-first ordering) |
| 3 | **Extensions** | add *new capabilities* — new commands/templates (Jira, post-impl review, V-Model traceability) |
| 4 | Core defaults | built-in SDD commands + templates |

- `specify extension add <name>` · `specify preset add <name>` — commands written at install time.
- **Bundles** = role-based package (PM, BA, security, developer) of extensions+presets+workflows in one
  versioned `bundle.yml`. `specify bundle search/info/install`. Idempotent, project-confined, offline.

## Development modes
- **0-to-1 (greenfield)** — generate from scratch.
- **Creative exploration** — parallel implementations, multi-stack/architecture, UX patterns.
- **Iterative enhancement (brownfield)** — add features, modernize legacy, adapt. *(← your territory)*

## Philosophy
Intent-driven (*what* before *how*) · rich spec under guardrails + org principles · multi-step
refinement not one-shot · heavy reliance on advanced model capability.

---

## Spec Kit vs GSD

| Dimension | **Spec Kit** | **GSD** |
|---|---|---|
| **Scope** | Single feature/spec pipeline | Project + milestone lifecycle |
| **Artifacts** | `constitution.md`, `specs/` (spec/plan/tasks) | `PROJECT.md`, `ROADMAP`, per-phase `SPEC/PLAN/VERIFICATION` |
| **Entry** | `/speckit.*` (agent-agnostic, 30+ tools) | `/gsd-*` (Claude-first) |
| **The "constitution"** | first-class governed principles artifact | no direct equiv (`CLAUDE.md`/`PROJECT.md` closest) |
| **Completion loop** | `/speckit.converge` — codebase vs spec, append remaining | `/gsd-verify-work` + goal-backward verifier |
| **Verification** | `/speckit.analyze` (cross-artifact), `/checklist` | goal-backward verifier = **hard blocker**, plan-checker, decision gate |
| **Customization** | extensions/presets/bundles priority stack + marketplace | GSD config + model profile |
| **Orchestration** | one agent, sequential tasks (no fan-out) | wave-based parallel subagents + git worktrees |
| **State / memory** | `.specify/` + `specs/` artifacts | `.planning/` + MemPalace temporal KG, threads, capture/resume |
| **Tool reach** | Copilot, Claude Code, Gemini, Codex, … (30+) | Claude Code-first |
| **Best for** | Portable spec→code on any agent; heavy customization | Durable multi-phase project w/ verification rigor |

### Phase mapping
| Spec Kit | GSD |
|---|---|
| `constitution` | (no equiv — ~`CLAUDE.local.md` + PROJECT.md principles) |
| `clarify`, `specify` | `/gsd-spec-phase`, `/gsd-discuss-phase` |
| `plan`, `tasks` | `/gsd-plan-phase` |
| `analyze` | `/gsd-plan-checker`, `/gsd-verify-work` (draft) |
| `implement` | `/gsd-execute-phase`, `/gsd-quick`, `/gsd-fast` |
| `converge` | `/gsd-verify-work` |
| `taskstoissues` | (no native — `/gsd-inbox` triages inbound) |

### Each has what the other lacks
**Spec Kit-only:** `constitution` as first-class artifact; **agent-agnostic** same-spec-on-any-tool; **extensions/presets/bundles** marketplace; **creative exploration** (parallel multi-stack); `converge` loop as a primitive; `checklist` ("unit tests for English").

**GSD-only:** project/milestone lifecycle + ROADMAP; durable cross-session memory (MemPalace, threads); goal-backward verification as hard blocker; wave parallelization + worktrees; AI-phase/UI-phase specializations; import/ingest with conflict detection; dozens of orchestration subagents.

---

## For your stack (.NET backend, legacy reverse-map, already on GSD)

**Low migration pressure.** Your established codebase is already deep in GSD's spec→plan→execute→verify
loop *with* durable memory + milestone tracking + goal-backward rigor — thicker than Spec Kit for project
work. **Stay GSD as spine.**

**Transferable ideas worth stealing:**
- **`constitution` as a governed artifact** — you already keep principles in `CLAUDE.local.md` (byte-identical gates, source-driven, no-GSD-vocab-leakage, Aspire HTTP profile). Promoting that to a checked-in `constitution.md` that every spec references is a clean Spec-Kit-ism.
- **`converge` loop** — mirrors your byte-identical generator snapshot gate; worth naming explicitly ("keep going till snapshot green").
- **brownfield/iterative-enhancement mode** — your exact scenario. If you ever trial Spec Kit, this is the mode, not 0-to-1.
- **extensions/presets** — if you want the SDD pipeline but DDD-flavored or compliance-gated, presets are the lever.

**When Spec Kit genuinely wins for you:** you need the *same spec* executable across Copilot **and** Claude
(portable unit), or you want a rich extension/bundle ecosystem around spec→code. For single-agent,
single-project rigor, GSD is the heavier tool.
