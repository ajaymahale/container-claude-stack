---
name: am-address-pr-comments
description: Fetch PR review comments, group into threads, present to user, create GSD phase, fix issues, commit, draft and push reply comments via gh api
---

# /am-address-pr-comments — Address PR Review Comments

Fetches unresolved review comment threads from a PR, presents them for triage, creates a GSD phase to track progress, implements fixes, and drafts/pushes reply comments to GitHub.

## Process

### Step 1: Identify PR

```bash
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
PR_NUMBER=$(gh pr list --head "$CURRENT_BRANCH" --json number --jq '.[0].number')
```

If no PR found for current branch, ask user for PR number.

### Step 2: Fetch review comments

```bash
# General PR comments
gh pr view $PR_NUMBER --json comments --jq '.comments'

# Inline review comments (if accessible)
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/comments 2>/dev/null || echo "inline comments not accessible"
```

Parse all comments. Filter out the current user's own comments. Group into threads by:
1. Top-level reviewer comment
2. All replies in chronological order

### Step 3: Present unresolved threads to user

For each thread, display:
- **Author** and **timestamp**
- **File/line** (if inline comment) or "general"
- **Summary** of the issue
- **Current resolution status** (resolved/unresolved based on replies)

```
## Thread {N}: {Author} on {file:line | general}
{First 200 chars of issue}

Status: [resolved by reply / unresolved]
Options: [Address] [Skip] [Already fixed]
```

### Step 4: User selects threads to address

Ask user which threads need code changes. For each selected thread:
- Read the referenced file and surrounding context
- Understand the specific issue
- Propose a fix approach

### Step 5: Create GSD phase for tracking

```bash
/gsd-add-phase {next_phase_number} "Address PR #{PR_NUMBER} Review Comments"
```

Create a PLAN.md with one task per selected thread, each with:
- Thread reference (author, file, line)
- Fix description
- Target files
- Suggested commit message

### Step 6: Implement fixes

For each task in the phase:
1. Read the target file(s)
2. Implement the fix
3. Build to verify: `dotnet build`
4. Commit with descriptive message
5. Note the commit hash for PR reply

### Step 7: Draft PR reply comments

For each addressed thread, draft a reply:
- Summarize the fix in 1-3 sentences
- Reference the commit hash
- Explain reasoning if the fix differs from the reviewer's suggestion

Present all drafts to user for approval before pushing.

### Step 8: Push reply comments to GitHub

For general comments:
```bash
gh pr comment $PR_NUMBER --body "{reply_text}"
```

For inline review comments (requires comment ID):
```bash
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/comments/{comment_id}/replies \
  -f body="{reply_text}"
```

### Step 9: Summary

Report:
- Threads addressed: {N}/{M}
- Commits pushed: list
- Reply comments pushed: list
- Remaining unresolved threads (if any)

## Notes

- Never push replies without user approval
- If a fix seems wrong or incomplete, flag it before committing
- If inline comments API returns 404 (private repo permissions), draft replies as a single general comment instead
- Keep reply comments concise — reviewers don't need essays
