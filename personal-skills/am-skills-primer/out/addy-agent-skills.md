# Addy Osmani's `agent-skills` — cheatsheet (vs GSD)

> Source: [github.com/addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) ·
> blog: [addyosmani.com/blog/agent-skills](https://addyosmani.com/blog/agent-skills/) ·
> installed here as plugin `addy-agent-skills` (24 skills + 8 commands).
> Disk path: `~/.claude/plugins/marketplaces/addy-agent-skills/skills/`

**One line:** A library of *production-grade engineering workflows*, one skill per concern,
mapped onto a 6-phase lifecycle. Process-not-prose: each skill has steps, verification gates,
an **anti-rationalization table** (excuses + rebuttals), and **Red Flags**. Curated from
Google's engineering culture (Hyrum's Law, Beyoncé Rule, test pyramid, Chesterton's Fence,
trunk-based dev, Shift Left).

```
  DEFINE          PLAN           BUILD          VERIFY         REVIEW          SHIP
 ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐
 │ Idea │ ───▶ │ Spec │ ───▶ │ Code │ ───▶ │ Test │ ───▶ │  QA  │ ───▶ │  Go  │
 │Refine│      │  PRD │      │ Impl │      │Debug │      │ Gate │      │ Live │
 └──────┘      └──────┘      └──────┘      └──────┘      └──────┘      └──────┘
  /spec          /plan          /build        /test         /review       /ship
```

---

## The 8 commands (lifecycle entry points)

| Doing | Cmd | Principle | Also auto-activates |
|---|---|---|---|
| Define what to build | `/spec` | Spec before code | interview-me, idea-refine, spec-driven-development |
| Plan how to build | `/plan` | Small, atomic tasks | planning-and-task-breakdown |
| Build incrementally | `/build` | One slice at a time | incremental-implementation, tdd |
| Prove it works | `/test` | Tests are proof | test-driven-development, debugging-and-error-recovery |
| Review before merge | `/review` | Improve code health | code-review-and-quality, security, perf |
| Audit web perf | `/webperf` | Measure before optimize | performance-optimization |
| Simplify code | `/code-simplify` | Clarity over cleverness | code-simplification |
| Ship to prod | `/ship` | Faster is safer | shipping-and-launch (+ review personas) |

**`/build auto`** = generate plan + implement every task in one approved pass (you approve the
plan once, it runs autonomously, still test-drives + commits each task, pauses on failure). The
human is removed from *between* tasks, not from verification.

---

## All 24 skills by phase

### META — discover which skill applies
| Skill | Fires on | What it does |
|---|---|---|
| **using-agent-skills** | session start | Routes incoming work → right skill. Defines shared operating rules. The pack's router. |

### DEFINE — clarify what to build
| Skill | Fires on | What it does |
|---|---|---|
| **interview-me** | "interview me", "grill me", "are we sure?" | One-question-at-a-time interview → ~95% confidence on real intent. Stops you silently filling in ambiguous asks. |
| **idea-refine** | "ideate", "refine this idea", "stress-test my plan" | Divergent then convergent thinking. Vague idea → sharp proposal. |
| **spec-driven-development** | new project/feature, unclear requirements | Write a PRD (objectives, commands, structure, style, testing, boundaries) before any code. |

### PLAN — break it down
| Skill | Fires on | What it does |
|---|---|---|
| **planning-and-task-breakdown** | have a spec, need units | Decompose → small verifiable tasks w/ acceptance criteria + dependency order. |

### BUILD — write the code
| Skill | Fires on | What it does |
|---|---|---|
| **incremental-implementation** | change >1 file, about to write a lot | Thin vertical slices: implement → test → verify → commit. Feature flags, safe defaults, rollback-friendly. |
| **test-driven-development** | implementing logic, fixing a bug | Red-Green-Refactor. Test pyramid 80/15/5, DAMP over DRY, Beyoncé Rule. |
| **context-engineering** | new session, output degrading, switching tasks | Feed agent right info at right time — rules files, context packing, MCP. |
| **source-driven-development** | need authoritative, source-cited code | Ground every framework decision in official docs — verify, cite, flag unverified. |
| **doubt-driven-development** ⭐ | high stakes, unfamiliar code, irreversible ops | Adversarial fresh-context review of every non-trivial decision: CLAIM → EXTRACT → DOUBT → RECONCILE → STOP. Optional cross-model escalation. |
| **frontend-ui-engineering** | building/modifying UI | Component arch, design systems, state, responsive, WCAG 2.1 AA. *(web)* |
| **api-and-interface-design** | designing APIs / module boundaries / public interfaces | Contract-first, Hyrum's Law, One-Version Rule, error semantics, boundary validation. |

### VERIFY — prove it works
| Skill | Fires on | What it does |
|---|---|---|
| **browser-testing-with-devtools** | anything running in a browser | Chrome DevTools MCP — DOM, console, network, profiling. *(web, needs chrome-devtools MCP)* |
| **debugging-and-error-recovery** | tests fail, builds break, unexpected behavior | 5-step triage: reproduce → localize → reduce → fix → guard. Stop-the-line rule. |

### REVIEW — quality gates before merge
| Skill | Fires on | What it does |
|---|---|---|
| **code-review-and-quality** | before merging any change | Five-axis review, change sizing (~100 lines), severity labels (Nit/Optional/FYI), splitting strategies. |
| **code-simplification** | code works but hard to read/maintain | Chesterton's Fence, Rule of 500. Reduce complexity, preserve exact behavior. |
| **security-and-hardening** | user input, auth, data storage, external integrations | OWASP Top 10, auth patterns, secrets mgmt, dep auditing, three-tier boundary system. |
| **performance-optimization** | perf requirements, suspected regression | Measure-first — Core Web Vitals, profiling, bundle analysis, anti-patterns. *(web-leaning)* |

### SHIP — deploy with confidence
| Skill | Fires on | What it does |
|---|---|---|
| **git-workflow-and-versioning** | any code change | Trunk-based, atomic commits, change sizing (~100 lines), commit-as-save-point. |
| **ci-cd-and-automation** | setting up/modifying build+deploy pipelines | Shift Left, Faster-is-Safer, feature flags, quality-gate pipelines. |
| **deprecation-and-migration** ⭐ | removing old systems, migrating users, sunsetting | Code-as-liability mindset, compulsory vs advisory deprecation, zombie-code removal. |
| **documentation-and-adrs** | arch decisions, API changes, shipping features | ADRs, API docs, inline-doc standards — document the *why*. |
| **observability-and-instrumentation** ⭐ | adding logging/metrics/tracing, shipping prod code | Structured logging, RED metrics, OpenTelemetry tracing, symptom-based alerting. Instrument as you build. |
| **shipping-and-launch** | prepping to deploy to prod | Pre-launch checklists, feature-flag lifecycle, staged rollouts, rollback, monitoring setup. |

⭐ = distinctive / high-value to graft into a stack GSD doesn't cover per-concern.

---

## Agent personas (standalone, usable without the pack)

All four are installed here as `agent-skills:*` agents — run them directly:

| Agent | Role | Use |
|---|---|---|
| `agent-skills:code-reviewer` | Senior Staff Eng | Five-axis review, "would a staff engineer approve this?" |
| `agent-skills:test-engineer` | QA Specialist | Test strategy, coverage, the Prove-It pattern |
| `agent-skills:security-auditor` | Security Eng | Vuln detection, threat modeling, OWASP |
| `agent-skills:web-performance-auditor` | Web Perf Eng | Core Web Vitals audit, Quick/Deep modes, metric-honesty rule (via `/webperf`) |

`/ship` fans these out in **parallel**, then merges to a go/no-go.

---

## How it compares to GSD

Both share the same skeleton — **Define → Plan → Build → Verify → Review → Ship**. The
skeleton is *not* the differentiator. What differs is everything around it: where state lives,
how discipline is enforced, how much orchestration, and how heavy the ceremony is.

### At a glance

| Dimension | **agent-skills** (Addy) | **GSD** |
|---|---|---|
| **Shape** | Library of concern-skills + 8 phase commands, light router (`using-agent-skills`) | Full methodology with **project → milestone → phase → plan → wave** lifecycle |
| **State** | Stateless — discipline lives in your repo (CLAUDE.md, commits); no planning artifacts | **Heavy persistent state** in `.planning/` (PROJECT.md, ROADMAP.md, per-phase PLAN/SPEC/VERIFICATION, threads, workstreams, MemPalace) |
| **Granularity** | Feature-level (one concern at a time) | Multi-phase projects with durable roadmap + milestone tracking |
| **Discipline mechanism** | **Anti-rationalization tables + Red Flags** baked into *every* skill's text | External gates: plan-checker, verifier (goal-backward), decision-coverage gate, convergence review |
| **Entry points** | `/spec /plan /build /test /review /code-simplify /webperf /ship` (1:1 to phase) | `/gsd-spec-phase /gsd-plan-phase /gsd-execute-phase /gsd-verify-work /gsd-code-review /gsd-ship` + unified `/gsd-progress` |
| **Auto mode** | `/build auto` — one approval, runs every task test-driven | `/gsd-autonomous` — discuss→plan→execute per phase |
| **Multi-agent** | 4 review personas fanned out in `/ship` | **Dozens** of specialized subagents (researcher, planner, executor, verifier, mapper, doc-classifier, …) + wave-based parallelization w/ worktrees |
| **Tool reach** | Multi-tool: Claude Code, Cursor, Gemini CLI, Antigravity, OpenCode, Windsurf, Copilot | Claude Code-first |
| **Orientation** | Web/frontend-forward (browser-testing, webperf, accessibility, UI) | Backend/enterprise (your stack) + dedicated AI-phase & UI-phase specializations |
| **Best for** | A feature driven through every phase with a human checkpoint each phase | A multi-phase project needing durable memory, coordination, milestone governance |

### Phase-by-phase command mapping

| Phase | Addy command/skill | GSD equivalent |
|---|---|---|
| **Define** | `/spec`, `interview-me`, `idea-refine`, `spec-driven-development` | `/gsd-explore`, `/gsd-spec-phase`, `/gsd-discuss-phase`, `/gsd-mvp-phase`, `/gsd-new-milestone` |
| **Plan** | `/plan`, `planning-and-task-breakdown` | `/gsd-plan-phase`, `/gsd-ultraplan-phase` |
| **Build** | `/build`, `incremental-implementation`, `tdd`, `source-driven-development` | `/gsd-execute-phase`, `/gsd-quick`, `/gsd-fast`, `/gsd-autonomous` |
| **Verify** | `/test`, `test-driven-development`, `debugging-and-error-recovery` | `/gsd-verify-work`, `/gsd-add-tests`, `/gsd-validate-phase` |
| **Review** | `/review`, `code-review-and-quality`, `security-and-hardening` | `/gsd-code-review`, `/gsd-secure-phase`, `/gsd-eval-review`, `/gsd-ui-review` |
| **Ship** | `/ship`, `shipping-and-launch` | `/gsd-ship`, `/gsd-pr-branch`, `/gsd-complete-milestone` |
| **Debug** | `debugging-and-error-recovery` | `/gsd-debug`, `/gsd-forensics` |

### What each has that the other lacks

**Addy has, GSD doesn't (per-concern):**
- **Anti-rationalization + Red Flags** in every skill — discipline lives *in* the skill text, not in an external gate.
- **`doubt-driven-development`** — adversarial in-flight review + optional cross-model escalation (GSD's cross-AI review is plan-time, not in-flight).
- **`deprecation-and-migration`** — code-as-liability, first-class (GSD has no deprecation skill).
- **`observability-and-instrumentation`** — RED/USE metrics, OTel, symptom alerting (GSD has none).
- **`source-driven-development`** — cite official docs, flag unverified (GSD relies on researcher agents).
- **`api-and-interface-design`** — contract-first, Hyrum's Law (GSD has no API-design skill).
- **Web/frontend depth** — browser-testing, webperf, accessibility, UI engineering.
- **Multi-tool portability** (not Claude-locked).

**GSD has, Addy doesn't:**
- **Project & milestone lifecycle** — new-project, new-milestone, roadmap, milestone-summary, cleanup, archive, audit-milestone.
- **Durable state** — `.planning/`, threads, workstreams, MemPalace memory, capture/resume, pause-work (survives context resets across sessions).
- **Goal-backward verification** + plan-checker + decision-coverage gate as **hard blockers**.
- **Wave-based parallel execution** with git worktrees.
- **AI-phase specializations** — AI-SPEC, eval-planner, eval-auditor, framework-selector (for *building* AI systems).
- **UI-phase specializations** — UI-SPEC, ui-checker.
- **Import/ingest** — bring external plans/docs into `.planning/` with conflict detection.
- **Dozens of specialized subagents** vs Addy's 4 personas.

---

## Relevance to wow-pic (.NET backend API) + recommendation

You already run GSD for phase-structured work with durable planning artifacts. **Addy's pack does
not replace GSD** — it covers a smaller, stateless, feature-level scope. The value here is
**grafting in the per-concern disciplines GSD lacks**, and using the personas.

**High-value to graft into your loop:**
- `doubt-driven-development` — adversarial fresh-context review for irreversible ops (your binding
  migrations are byte-identical-gated; doubt-driven fits that risk profile perfectly).
- `source-driven-development` — cite official docs for generator/Protobuf/Mongo decisions.
- `api-and-interface-design` — contract-first for the legacy reverse-map / `IArticleRepository` seams.
- `deprecation-and-migration` — your PIES/rename work is literally deprecation territory.
- `observability-and-instrumentation` — RED/OTel for the API + publishers.
- `code-simplification` — Chesterton's Fence / Rule of 500 on the LegacyMapperGenerator.
- The 4 **personas** — run `agent-skills:code-reviewer` / `security-auditor` standalone on PRs.

**Low/no relevance to your stack:**
- `browser-testing-with-devtools`, `frontend-ui-engineering`, `performance-optimization`,
  `webperf` — web/CWV-leaning; no browser app to test. Skip unless you add a UI.

**Collision warning (both packs installed here):**
`/spec /plan /build /review /ship /test` are **bare** Addy commands; GSD is `/gsd-*` namespaced.
They coexist on different tokens, but in this env `/review` (and `/spec`, `/ship`, …) resolve to
**Addy's**, not GSD's. If you mean GSD, type the `/gsd-` prefix. (`/build` is Addy-only; GSD has
no bare `/build`.)

**Bottom line:** Keep GSD as the project/methodology spine. Reach for Addy when you want a
specific engineering discipline's opinionated workflow (doubt-driven, source-driven, deprecation,
observability) or the standalone review personas — i.e. **GSD = how the project runs; Addy = how a
single concern is done well.**
