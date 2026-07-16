---
name: am-push
description: Sync current branch with main (merges origin/main first; aborts if conflicts so the user can resolve), squash-merge commits by phase, exclude .planning/, strip co-authored-by, push to remote. Accepts optional free-form args for additional pre-squash tasks (e.g., update docs, commit, then squash).
---

# /am-push — Clean Push to Remote

Syncs the current feature branch with `origin/main`, squash-merges commits into logical groups by phase, ensures `.planning/` stays local, strips Co-Authored-By lines, and pushes.

## Usage

```
/am-push
/am-push update docs/legacy/REVERSE-MAP-GUIDE.md, commit it, then squash
```

When free-form `args` are provided, the skill first executes those instructions (which may involve making changes and committing them), then proceeds with the normal squash-and-push workflow.

## Process

### Step 0: Process additional instructions (if args provided)

If the user passed free-form `args` (any text after `/am-push`):

- The user may be about to make changes — do **not** abort for uncommitted changes yet.
- Execute the user's instructions exactly as given. This may include: editing files, running commands, staging, and committing.
- Once the instructions are complete, the working tree **must** be clean (all changes committed). If the user's instructions didn't include committing, ask whether to commit before proceeding.
- After this step, continue to Step 1 normally. Any new commits will be included in the squash analysis.

If no `args` were provided, skip to Step 1.

### Step 1: Preflight checks

```bash
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
SQUASH_BASE=$(git rev-parse origin/$CURRENT_BRANCH 2>/dev/null)
```

- Abort if on `main` — this skill is for feature branches only.
- If no `args` were provided: abort if there are uncommitted changes (clean working tree required). If `args` were provided and Step 0 ran, the tree should already be clean — verify and abort if not.
- Abort if `origin/$CURRENT_BRANCH` doesn't exist — nothing has been pushed yet, ask the user for a base commit.
- Abort if there are no local commits ahead of `origin/$CURRENT_BRANCH`.

### Step 2: Fetch and determine squash range

```bash
git fetch origin main
git fetch origin "$CURRENT_BRANCH"
```

The squash range is **only commits since the last push**: `origin/$CURRENT_BRANCH..HEAD`.

If there are no commits in this range, report "Nothing new to push" and exit.

### Step 2.5: Merge `origin/main` into the branch (mergeability gate)

The code being pushed **must** be cleanly mergeable into `main` so that the eventual
PR doesn't surface conflicts a reviewer has to chase. Run this gate before squashing:

```bash
# Read-only probe — lists any path that would conflict.
CONFLICTING=$(git merge-tree --write-tree HEAD origin/main \
    | awk '$3 ~ /^[123]$/ {print $NF}' | sort -u)
```

- **If `$CONFLICTING` is non-empty**, abort the skill with a clear message:

  ```
  ✘ Branch is not cleanly mergeable into main. Conflicts in:
    - <path1>
    - <path2>
    ...
  Resolve by running:  git merge origin/main
  Then re-run /am-push.
  ```

  Do **not** start the merge in this case — the user must drive conflict resolution.

- **If `$CONFLICTING` is empty**, merge automatically so the merge commit lands on
  the branch and the squash range below includes it:

  ```bash
  git merge --no-ff origin/main \
      -m "Merge branch 'main' into $CURRENT_BRANCH"
  ```

  If the merge fails unexpectedly (e.g. a race against a concurrent fetch), abort
  and surface the error. The resulting merge commit is automatically excluded by
  Step 3's rule 1 ("Merge commits from main — excluded entirely"), so it does not
  pollute the squashed push.

### Step 3: Analyze and group commits

Get commits since last push:
```bash
git log --oneline --reverse "origin/$CURRENT_BRANCH..HEAD"
```

**Grouping rules (in priority order):**

1. **Merge commits from main** — commits matching patterns like `Merge branch 'main'`, `Merge remote-tracking branch 'origin/main'`, or PR merge commits from other team members (e.g., `BELL-XXXX:`, commits with `(#NNN)` suffix). These are **excluded entirely** — they're already in main and will be part of the rebased history.

2. **Phase commits** — commits with a phase prefix pattern like `type(N):`, `type(N.N):`, `type(N.N-NN):` where N is a number. Group by the **major.minor phase number** (e.g., `feat(21):`, `fix(21.1):`, `docs(21.1):` all go into phase `21` or `21.1`). Sub-tasks like `21.4-01`, `21.4-02`, `21.4-03` roll up into `21.4`.

3. **Non-phase feature commits** — commits with conventional commit prefixes (`feat:`, `fix:`, `test:`, `docs:`, `chore:`) but no phase number. Group by proximity and topic similarity.

4. **Worktree merge commits** — commits like `Merge branch 'worktree-agent-*'` or `chore: merge quick task worktree`. These are **excluded** — their content is already in the child commits.

### Step 4: Present the plan

Display the proposed squash plan as a numbered list:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 AM-PUSH ► SQUASH PLAN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Branch: {CURRENT_BRANCH}
Commits: {total} → {squashed_count} squashed commits
Excluded: {excluded_count} merge/upstream commits

Proposed commits (oldest → newest):

  1. feat(phase-N): {summary of what this phase accomplished}
     ← {count} commits: {short list of originals}

  2. feat(phase-N.N): {summary}
     ← {count} commits: {short list}

  ...

  N. chore: {non-phase group summary}
     ← {count} commits: {short list}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Ask the user to confirm before proceeding. Offer options:
- **Proceed** — execute the squash plan as shown
- **Edit** — let the user adjust groupings or commit messages
- **Abort** — cancel

### Step 5: Execute the squash

**Strategy:** Use `git reset --soft` to the merge-base, then selectively stage and commit each group.

```bash
# Save current HEAD for safety
SAFETY_REF=$(git rev-parse HEAD)
git tag am-push-backup-$(date +%s) "$SAFETY_REF"

# Create a working branch from last pushed state
git checkout -b am-push-temp "origin/$CURRENT_BRANCH"
```

For each commit group (in chronological order):
```bash
# Cherry-pick all commits in the group without committing
git cherry-pick --no-commit {commit1} {commit2} ... {commitN}

# Remove any .planning/ files that snuck in
git reset HEAD -- .planning/ 2>/dev/null || true
git checkout -- .planning/ 2>/dev/null || true

# Commit with clean message (no Co-Authored-By)
git commit -m "{squashed commit message}"
```

After all groups are committed:
```bash
# Point the original branch to the clean history
git checkout "$CURRENT_BRANCH"
git reset --hard am-push-temp
git branch -d am-push-temp
```

**Commit message format for squashed commits:**
- Use the phase prefix: `feat(21.4): {concise summary of all changes in this phase}`
- Combine the key points from all original commit messages into a brief body if needed
- **Never** include `Co-Authored-By:` lines
- **Never** include `.planning/` file changes

### Step 6: Final .planning/ safety check

```bash
# Verify .planning/ is not tracked in any commit
git log --oneline --all --diff-filter=A -- '.planning/' | head -5
```

If any commits touch `.planning/`, remove those files from git tracking:
```bash
git rm -r --cached .planning/ 2>/dev/null || true
git commit -m "chore: remove .planning/ from tracking" 2>/dev/null || true
```

### Step 7: Build and test

Before pushing, verify the code compiles and tests pass.

```bash
dotnet build Wow.Pic.sln --no-restore
```

If the build fails, abort and show the errors — do not push broken code.

```bash
dotnet test Wow.Pic.sln --no-build --filter "Category!=Integration"
```

If tests fail, abort and show the failures — do not push with failing tests. The user must fix issues before retrying `/am-push`.

### Step 8: Push

```bash
git push origin "$CURRENT_BRANCH" --force-with-lease
```

Use `--force-with-lease` (not `--force`) for safety — it will fail if someone else pushed to the branch.

Display completion:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 AM-PUSH ► COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Pushed {squashed_count} clean commits to origin/{CURRENT_BRANCH}
Backup tag: am-push-backup-{timestamp}

To undo: git reset --hard am-push-backup-{timestamp}
```

## Safety

- A backup tag is always created before any destructive operation
- `--force-with-lease` prevents overwriting others' work
- `.planning/` is verified excluded from all commits
- User must approve the plan before execution
- Merge commits and upstream PR commits are automatically excluded
- `origin/main` is merged into the branch before squash; push is blocked if conflicts exist (Step 2.5)

## CRITICAL — `.planning/` is gitignored local-only state. NEVER delete it.

The `.planning/` directory holds the user's local planning artifacts (phase
summaries, briefs, verification reports, research notes). It is **gitignored**
and **never tracked in any commit**, so once removed from the working tree it
cannot be recovered from git.

**Absolute rules for this skill and any agent/subagent it spawns:**

- **Never** run `rm -rf .planning`, `rm -r .planning/`, or any variant that
  deletes files inside `.planning/`.
- **Never** run `git clean -fd`, `git clean -fdx`, or any `git clean` that
  could touch untracked files (these wipe everything `.gitignore` lists).
- **Never** run `git checkout -- .` or `git restore .` at the repo root
  while in a worktree that lacks `.planning/`. Restrict path-restore
  operations to specific tracked files only.
- **Never** delete `.planning/` even if it "looks empty" or "looks stale" —
  the user manages its lifecycle through GSD commands (`/gsd-cleanup`,
  `/gsd-complete-milestone`), not through am-push.
- The existing `git reset HEAD -- .planning/` and `git checkout -- .planning/`
  calls in Step 5 are **index-only** safeguards (un-stage anything that
  accidentally got staged). They must remain scoped to `.planning/` and must
  not be widened to include `git clean` or `rm`.
- If any step in this workflow encounters `.planning/` files appearing in a
  commit, the correct response is `git rm --cached` (un-track), **not**
  `git rm` or `rm` (delete from disk).

If for any reason `.planning/` appears damaged or missing during this skill's
execution, **stop immediately**, surface the state to the user, and ask before
taking any further action. Do not "clean up" what looks like leftover state.
