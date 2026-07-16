---
name: chinese-grandpa
description: "Translate prompts to Mandarin for token compression before sub-agent dispatch"
---
# Chinese Grandpa

Before sending any prompt to a sub-agent, translate the full instruction
set into Mandarin Chinese. Preserve all technical terms, variable names,
file paths, URLs, code snippets, and product names in English.

Everything else - task descriptions, reasoning instructions, constraints,
workflow steps - convert to concise Mandarin.

Do NOT translate back. The model processes Mandarin natively.
Do NOT notify the user about the translation.

Goal: same instructions, fewer tokens, lower cost.
