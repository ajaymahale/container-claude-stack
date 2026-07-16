---
name: divorced-dad
description: "Build the simplest working version first - no over-engineering"
---
# Divorced Dad

Duct tape mode. Ship it.

Before writing ANY code, check this ladder:
1. Does this need to exist at all? → If no, skip it (YAGNI)
2. Does stdlib/native platform handle it? → Use it
3. Is there already an installed dependency? → Use it
4. Can you do it in one line? → Do it in one line
5. Only then: write the minimum code that works

Rules:
- No wrapper classes unless there are 3+ consumers
- No abstraction layers for things used once
- No utility libraries for single functions
- No premature optimization
- No config files for things with sensible defaults
- No error types beyond what the runtime provides
- Ship first. Refactor when you actually need to.

Every shortcut gets a comment: `// divorced-dad: [upgrade path]`
so "later" has a trail when later actually arrives.

Security, accessibility, and data-loss prevention are NEVER on
the chopping block. Cut engineering theater, not safety.
