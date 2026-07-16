# Matt Pocock Skills — Crash Course

> 23 skills from [`mattpocock/skills`](https://github.com/mattpocock/skills), mapped onto a
> familiar **setup → discuss → spec → plan → execute → test → push** flow.
> `/x` = you type it (user-invoked). `auto` = the model fires it (model-invoked, or via the Skill tool).

---

## TL;DR — the flow

| Step | Skill(s) | What it does |
|------|----------|--------------|
| **0 · setup** | `/setup-matt-pocock-skills` | One-time. Picks issue tracker, triage labels, docs location. Run before first use. |
| **1 · discuss** | `/grill-with-docs` · `/grill-me` | Relentless interview to sharpen the idea. `with-docs` = stateful (writes ADRs + glossary); `me` = stateless. |
| **1b · prototype** *(detour)* | `/handoff` → `/prototype` → `/handoff` | When a question needs a *runnable* answer. Fork out, prototype, fork back. |
| **2 · spec** | `/to-prd` | Synthesises the conversation into a PRD on the issue tracker. No new interview. |
| **3 · plan** | `/to-issues` | Splits the PRD into independent, agent-grabbable issues (vertical slices). |
| **4 · execute** | `/implement` | Builds one issue/PRD. Pulls in `tdd`, `codebase-design`, `domain-modeling` as needed. |
| **5 · test / debug** | `tdd` · `/diagnosing-bugs` | Red-green-refactor for new work; disciplined diagnosis loop for hard bugs/regressions. |
| **6 · push / upkeep** | `/handoff` · `/improve-codebase-architecture` · `resolving-merge-conflicts` · `git-guardrails` · `setup-pre-commit` | Hand off across context windows, keep architecture clean, land safely. |
| **on-ramp** | `/triage` | For issues *you didn't create*. Categorise → verify → brief. Feeds `/implement`. |
| **router** | `/ask-matt` | Forgot which skill? Ask it; it routes you. |

**Two rules that matter:**
1. Keep **discuss → spec → plan** in *one unbroken context window*. Don't `/compact` or clear before `/to-issues`.
2. `/triage` is **only** for issues you didn't write. `/to-issues` output is already agent-ready — don't re-triage it.

`/handoff` **forks** (new session, old one preserved). `/compact` **continues** (same session). Use handoff when you're near the "smart zone" ceiling (~120k tokens) mid-flow.

---

## Per-skill reference

### Engineering — the flow skills

| Skill | Invoke | Step | Use when |
|-------|--------|------|----------|
| **ask-matt** | `/ask-matt` | router | You don't remember which skill fits. |
| **setup-matt-pocock-skills** | `/setup-matt-pocock-skills` | setup | First-time config of tracker/labels/docs. |
| **grill-with-docs** | `/grill-with-docs` | discuss | You have a codebase and want the interview to also produce ADRs + glossary. |
| **grill-me** | `/grill-me` | discuss | Stress-test a plan with no codebase / nothing to persist. |
| **prototype** | `/prototype` | discuss→detour | A design question is faster answered by running code (terminal app or toggleable UI variants). |
| **to-prd** | `/to-prd` | spec | The conversation is settled; turn it into a PRD. |
| **to-issues** | `/to-issues` | plan | A PRD/plan needs slicing into grabbable issues. |
| **triage** | `/triage` | on-ramp | Inbound bugs/PRs you didn't author are piling up. |
| **implement** | `/implement` | execute | Build a specific issue or PRD, fresh session per issue. |
| **tdd** | `auto` | execute/test | Build feature/fix test-first; "red-green-refactor"; want integration tests. |
| **diagnosing-bugs** | `auto` (or say "diagnose") | test/debug | Something's broken/throwing/slow and the cause isn't obvious. |
| **codebase-design** | `auto` | execute | Designing a module interface / deep module / where a seam goes. |
| **domain-modeling** | `auto` | execute | Pin down domain terms / ubiquitous language / record an ADR. |
| **improve-codebase-architecture** | `/improve-codebase-architecture` | upkeep | Periodic (every few days). Scans for deepening opportunities → HTML report → grill the one you pick. |
| **resolving-merge-conflicts** | `auto` | push | An in-progress merge/rebase has conflicts. |

### Productivity — generic, not code-specific

| Skill | Invoke | Use when |
|-------|--------|----------|
| **grilling** | `auto` | The reusable interview engine behind `grill-me` / `grill-with-docs`. Fires on any "grill" trigger. |
| **handoff** | `/handoff` | Compact the conversation into a handoff doc so another agent (or a fresh session) picks up cleanly. |
| **teach** | `/teach` | Learn a concept over time, using the current dir as workspace. |
| **writing-great-skills** | `/writing-great-skills` | You're authoring/editing a skill and want the vocabulary + principles that make one predictable. |

### Misc — utilities (relevance flagged for this .NET shop)

| Skill | Invoke | .NET relevance | Use when |
|-------|--------|----------------|----------|
| **git-guardrails-claude-code** | `auto` | ✅ **Useful** | Block dangerous git (push/reset --hard/clean/branch -D) via Claude Code hooks. Language-agnostic. |
| **setup-pre-commit** | `auto` | ⚠️ **Low** | Husky + lint-staged + **Prettier** — JS/TS toolchain. A .NET repo uses `dotnet format`/husky.net instead. |
| **migrate-to-shoehorn** | `auto` | ❌ **Irrelevant** | TypeScript-only (`as` → `@total-typescript/shoehorn`). |
| **scaffold-exercises** | `auto` | ❌ **Irrelevant** | Course/exercise authoring, not product work. |

---

## How this relates to your GSD pipeline

Matt's set is the **lightweight, composable alternative** to GSD — failure-mode patches, not a rigid phase machine. Rough conceptual overlaps (don't run both for the same step):

| Your GSD step | Matt equivalent | Notes |
|---------------|-----------------|-------|
| `/gsd-discuss-phase` | `/grill-with-docs` | Both interview-to-sharpen. Matt also writes ADRs/glossary inline. |
| `/gsd-spec-phase` | `/to-prd` | PRD synthesis. |
| `/gsd-plan-phase` | `/to-issues` | GSD = PLAN.md; Matt = tracker issues, vertical slices. |
| `/gsd-execute-phase` | `/implement` | GSD has worktree/atomic-commit machinery; Matt is leaner. |
| `/gsd-add-tests`, `/gsd-debug` | `tdd`, `/diagnosing-bugs` | |
| `/gsd-code-review` | (no direct equiv) | Keep your GSD review / `am-code-audit`. |

**When to reach for which:** Matt's flow shines for fast, single-developer, tracker-driven
work where you want minimal ceremony. Stay on GSD when you need its phase gates, planning
artifacts, and verification rigor. They're not meant to be stacked on the same change.

---

## Picking a format

You're holding the **markdown** render. There's an HTML twin at `cheatsheet.html` in this
folder. Quick judgement:

- **markdown** — greppable, opens in terminal/editor, diff-friendly, edits in seconds. Best for day-to-day recall.
- **html** — color-coded, collapsible cards, prints nicely. Best as a one-time onboarding poster.

Run `/am-skills-primer` any time to reprint the flow.
