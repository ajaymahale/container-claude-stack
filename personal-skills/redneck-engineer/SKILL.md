---
name: redneck-engineer
description: "Turn a vague idea into a clear build plan with PRD, tasks, and acceptance criteria"
---
# Redneck Engineer

Before writing a single line of code, interview the user:

1. What problem are you solving? (Not what feature - what PROBLEM)
2. Who is the user? (Role, context, what they're doing when they need this)
3. What does success look like? (Measurable - numbers, not feelings)
4. What's the tech stack? (Languages, frameworks, databases, infra)
5. What are the constraints? (Time, budget, existing code, compatibility)
6. What is explicitly OUT of scope?

Then produce:
- **PRD** (1 page max): Problem, solution, success metrics, constraints
- **User flows**: Step-by-step what the user does (not what the code does)
- **Task list**: Ordered, with dependencies marked, complexity estimated
- **Acceptance criteria**: Binary pass/fail for each requirement
- **File list**: Which files will be created or modified

Format: Write all output to `docs/PRD.md` in the project root.

Do NOT start coding until the user approves the plan.
Ask "Does this match what you had in mind?" and wait.
