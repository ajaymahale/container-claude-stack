---
name: am-skills-primer
description: Generate a usage cheatsheet for any skill, skill family, or set of skills passed as an argument. Reads the skill content on disk, researches usage online, renders a markdown (and optional HTML) crash-course, then answers follow-up questions with research. Use when the user types /am-skills-primer <skill|family|prompt>, or asks "how do I use <skill>", "make a cheatsheet for <skills>", "explain the <X> skills".
---

# Skills Primer — on-demand cheatsheet generator

Takes an argument naming a skill, a family, or a set, and produces a cheatsheet specific
to it by **reading the skill source on disk + researching usage online**, then runs a
**Q&A loop** answering the user's follow-ups with research.

The argument can be:
- a single skill — `/am-skills-primer /grill-me` or `grill-me`
- a family — `matt pocock skills`, `gstack skills`, `gsd`, `am`, `ios`
- a set — `am-push, am-code-audit, am-azdo-varsync`
- a free-form prompt — `the skills I'd use to ship a feature`

If no argument is given: detect the families on disk (step 1), list them, and ask which to profile.

## Step 1 — Resolve the argument to a set of skill folders

Skills live in `~/.claude/skills/` (global) and `./.claude/skills/` (project). Resolve:
- Strip a leading `/`. If the token is an exact folder name → that single skill.
- Family keywords → glob the folders:
  - `gsd` → `gsd-*` · `am` / "my skills" → `am-*` · `ios` → `ios-*` · `gstack` → `gstack*`, `_gstack-command`, `open-gstack-browser`
  - `matt pocock` / `pocock` → the `mattpocock/skills` set. Authoritative current list = the repo tree
    `https://api.github.com/repos/mattpocock/skills/git/trees/main?recursive=1` (paths `skills/*/*/SKILL.md`).
    A worked example for this family already exists at `examples/matt-pocock.{md,html}` — reuse it.
- A comma/space list of known folder names → that set.
- Free-form → infer the set. If ambiguous (>~8 candidates, or unclear), list the candidates and
  ask the user with AskUserQuestion before generating.

Confirm the resolved set out loud (names + count) before doing heavy work.

## Step 2 — Read the source on disk

For each resolved skill, read its `SKILL.md` — frontmatter (`name`, `description`) for the
trigger/one-liner, and the body for arguments, procedure, and gotchas. Note whether each is
**user-invoked** (`/name`, orchestrates) or **model-invoked** (fires automatically / via the Skill tool) —
infer from the description's trigger phrasing.

## Step 3 — Research usage online

Establish each skill's origin, then fetch authoritative usage:
- Look in the SKILL.md body for a source URL/repo; otherwise infer (e.g. matt pocock → `github.com/mattpocock/skills`).
- WebSearch `"<skill> claude code skill"` + WebFetch the source repo's SKILL.md/README for real usage, args, and gotchas.
- Purely-local/custom skills (`am-*`, `gsd-*`, `gstack`) usually have **no** online docs — rely on disk content and say so rather than inventing sources.

## Step 4 — Render the cheatsheet

- **Single skill** → a focused card: purpose · how to invoke (and args) · when to use · a worked
  example or two · gotchas · related skills.
- **Family / set** → a TL;DR flow/grouping table first, then one compact card per skill, then a
  "which to reach for" note. Mirror the structure and HTML styling of `examples/matt-pocock.{md,html}`.

**Format:** default to **markdown**, printed inline. Also produce **HTML** when the user asks, or the
argument mentions `html`/`both` — emulate `examples/matt-pocock.html` (self-contained, inline CSS,
collapsible `<details>` cards). Markdown = greppable/edit-fast; HTML = color-coded onboarding poster.

## Step 5 — Save

Save generated files to `out/<slug>.md` (and `out/<slug>.html` if produced), where `<slug>` is a
kebab-case name for the argument (e.g. `grill-me`, `gsd-family`). Tell the user the paths. For
single-skill quick lookups, inline-only is fine — save on request.

## Step 6 — Q&A loop

After presenting, invite the user to ask questions about the skill(s). For each question,
research as needed (disk content + web) and answer concisely. Offer to fold notable answers back
into the saved cheatsheet. Continue until the user is done.

## Notes

- Cite the disk path and any web source you used so claims are checkable. Don't fabricate usage
  for skills with no docs — describe what the SKILL.md actually says.
- Flag relevance when obvious (e.g. TS-only skills in a .NET repo), as the Matt example does.
- `examples/matt-pocock.{md,html}` is both a worked output and the format template — keep it.
