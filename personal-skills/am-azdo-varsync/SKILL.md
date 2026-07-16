---
name: am-azdo-varsync
description: Deterministically add or delete Azure DevOps variable-group keys from an embedded rename-map. Dry-run/diff by default; writes are gated behind an explicit --apply. Idempotent (check-then-create-or-update), secret-safe (hard-stops rather than writing an empty secret), and looped per-environment across the four target variable groups. PAT is read only from AZURE_DEVOPS_EXT_PAT — never hard-coded.
---

# /am-azdo-varsync — Deterministic Azure DevOps Variable-Group Key Sync

Adds or deletes Azure DevOps variable-group keys against a fixed rename-map, copying each
new key's value (and its secret flag) from a named old key in the same variable group.
Default behaviour is a per-environment **dry-run/diff** — nothing is written until you pass
`--apply`. `add` mode is strictly non-destructive (the old key is never touched, never
renamed-in-place). `delete` mode is a first-class peer for the later, gated cleanup that
removes the old keys.

## Usage

```
/am-azdo-varsync add                     # dry-run: print the per-env diff, write nothing
/am-azdo-varsync add --apply             # perform the additive writes (idempotent)
/am-azdo-varsync delete                  # dry-run: print which old keys would be removed
/am-azdo-varsync delete --apply          # remove the named old keys (gated cleanup)
```

**Modes**

- `add` — for each pair in the rename-map, create the **new** key in each target group,
  copying the **value** and the **secret flag** from the named **old** key in that same group.
  Never modifies, renames, or deletes the old key.
- `delete` — remove a named key from each target group. Intended for the gated cleanup that
  retires the old keys after the new ones are live. Do **not** run `delete` during an `add` run.

**Inputs** (operator-supplied at invocation):

- `ORG` — the Azure DevOps org URL, e.g. `https://dev.azure.com/<org>`.
- `PROJECT` — the Azure DevOps project name.
- The four target group names and the rename-map are **embedded below** (not free-form input)
  so names are driven from verified literals and never reconstructed by string-mangling.

**Auth:** export `AZURE_DEVOPS_EXT_PAT` with a PAT scoped to **Library → Variable Groups
(Read, create, & manage)** — least privilege. The CLI authenticates non-interactively from
that env var. The PAT is never written to a file, never echoed, never committed.

## Engine

This skill drives the `azure-devops` CLI extension:

- `az pipelines variable-group list` — resolve a group **name** to its `--group-id`.
- `az pipelines variable-group variable list` — read each source key's `value` + `isSecret`.
- `az pipelines variable-group variable create` — add a new key (errors if it already exists).
- `az pipelines variable-group variable update` — update an existing key (errors if it doesn't).
- `az pipelines variable-group variable delete` — remove a named key (delete mode only).

## Process

### Step 1: Preflight / auth

```bash
: "${AZURE_DEVOPS_EXT_PAT:?Set AZURE_DEVOPS_EXT_PAT to a PAT with Library (Read, create & manage) scope}"
ORG="https://dev.azure.com/<org>"   # operator-supplied
PROJECT="<project>"                  # operator-supplied
```

- Hard-stop with a clear message if `AZURE_DEVOPS_EXT_PAT` is unset. Never echo its value.
- Bind `ORG` and `PROJECT` from the operator-supplied inputs.

### Step 2: Resolve each group id by EXACT name

For each of the four target groups, resolve the numeric id with an **exact-name** JMESPath
filter and hard-stop on zero or more than one match (guards the `aas` trap and partial-wildcard
collisions). Never target an `aas` group.

```bash
GROUP_ID=$(az pipelines variable-group list \
  --org "$ORG" --project "$PROJECT" \
  --group-name "$GROUP_NAME" \
  --query "[?name=='$GROUP_NAME'].id | [0]" -o tsv)

if [[ -z "$GROUP_ID" || "$GROUP_ID" == "null" ]]; then
  echo "✘ Group not found (or not unique): $GROUP_NAME" >&2; exit 1
fi
```

### Step 3: Read each source key's value + secret flag

```bash
SRC_JSON=$(az pipelines variable-group variable list \
  --org "$ORG" --project "$PROJECT" --group-id "$GROUP_ID" -o json)
# Output shape: { "<name>": { "value": "...", "isSecret": true|false } }

SRC_VALUE=$(echo "$SRC_JSON"     | jq -r --arg n "$OLD_KEY" '.[$n].value')
SRC_IS_SECRET=$(echo "$SRC_JSON" | jq -r --arg n "$OLD_KEY" '.[$n].isSecret // false')
```

Read the source value from the **same group** you are writing to — disable flags and KEDA
thresholds legitimately differ per environment, so never share a value across the env loop.

### Step 4: Secret-source hard-stop

Azure DevOps returns `null` for the `value` of any **secret** variable by design — its
`isSecret` flag is still readable. Do NOT copy a null value into a new secret key.

```bash
if [[ "$SRC_IS_SECRET" == "true" ]]; then
  # Copy the secret FLAG, never an empty value. Require an operator-supplied value via
  # AZURE_DEVOPS_EXT_PIPELINE_VAR_<NewKey>, or hard-stop naming the key.
  SUPPLIED="${AZURE_DEVOPS_EXT_PIPELINE_VAR_FOR_NEW_KEY:-}"
  if [[ -z "$SUPPLIED" ]]; then
    echo "✘ $OLD_KEY is secret; its value is unreadable. Supply a value for $NEW_KEY" >&2
    echo "  (set AZURE_DEVOPS_EXT_PIPELINE_VAR_<NewKey>) — refusing to write an empty secret." >&2
    exit 1
  fi
fi
```

### Step 5: Compute and print the per-environment diff (default = stop here)

For each target key, classify it and print the diff. In default mode **write nothing** and
stop after printing. Never print secret values or the PAT.

```
[+ ADD]    LegacyArticleService__ArticleDelta__Disabled = "false"   (from PicToArticleService__ArticleDelta__Disabled)
[= SKIP]   pic-legacy-articleservice-article-full-threshold         (already present, matches)
[! SECRET] <key>   source is secret — value unreadable, operator must supply or this stops
```

### Step 6: Apply gate — idempotent check-then-create-or-update (add mode)

Only when `--apply` is passed, write each new key. Use check-then-create-or-update so a re-run
after a partial success is a no-op, not an error. Always double-quote `--name` and `--value`
so the `__` config separator survives shell expansion.

```bash
EXISTING=$(az pipelines variable-group variable list \
  --org "$ORG" --project "$PROJECT" --group-id "$GROUP_ID" -o json)

if echo "$EXISTING" | jq -e --arg n "$NEW_KEY" 'has($n)' >/dev/null; then
  az pipelines variable-group variable update \
    --org "$ORG" --project "$PROJECT" --group-id "$GROUP_ID" \
    --name "$NEW_KEY" --value "$VAL" --secret "$SRC_IS_SECRET"
else
  az pipelines variable-group variable create \
    --org "$ORG" --project "$PROJECT" --group-id "$GROUP_ID" \
    --name "$NEW_KEY" --value "$VAL" --secret "$SRC_IS_SECRET"
fi
```

In `add` mode NEVER touch the old key and NEVER use `--new-name` — `--new-name` renames the
old key in place (i.e. deletes it), which is forbidden in additive mode.

### Step 7: Delete mode (gated cleanup, not run during add)

```bash
# Only with --apply, and only for the gated cleanup that retires the old keys.
az pipelines variable-group variable delete \
  --org "$ORG" --project "$PROJECT" --group-id "$GROUP_ID" \
  --name "$KEY" --yes
```

`delete` is gated behind `--apply` the same way as `add`. Do not exercise `delete` during an
additive run.

### Step 8: Evidence capture

Write the per-environment diff and the post-run `variable list` output to an operator-chosen,
**gitignored** location (e.g. a `*/.local/` path) — never a tracked repo file — and redact any
secret value and the PAT before saving.

## Rename-map (the contract — embedded, grep-checkable)

Drive every name from these literal strings. Never reconstruct a name by string-mangling.

### Target variable groups (aae only — NEVER aas)

| Environment | Group name           |
|-------------|----------------------|
| DEV         | `PIC Service DEV AAE`  |
| UAT         | `PIC Service UAT AAE`  |
| PT          | `PIC Service PT AAE`   |
| PROD        | `PIC Service PROD AAE` |

> NEVER resolve, read, or write any `AAS`-region group. The `AAS` groups are out of scope for
> this skill; an exact-name match against the four `AAE` names above is the only allowed target.

### 6 config-disable pairs (`__` is the .NET config nesting separator)

| Old key                                            | New key                                            |
|----------------------------------------------------|----------------------------------------------------|
| `PicToArticleService__ArticleDelta__Disabled`      | `LegacyArticleService__ArticleDelta__Disabled`      |
| `PicToArticleService__ArticleFull__Disabled`       | `LegacyArticleService__ArticleFull__Disabled`       |
| `PicToArticleService__ArticleStoreDelta__Disabled` | `LegacyArticleService__ArticleStoreDelta__Disabled` |
| `PicToArticleService__ArticleStoreFull__Disabled`  | `LegacyArticleService__ArticleStoreFull__Disabled`  |
| `PicToArticleService__HierarchyDelta__Disabled`    | `LegacyArticleService__HierarchyDelta__Disabled`    |
| `PicToArticleService__HierarchyFull__Disabled`     | `LegacyArticleService__HierarchyFull__Disabled`     |

### 12 KEDA pairs (must match deployment/deploy.yaml verbatim)

| Old key                                                       | New key                                                       |
|---------------------------------------------------------------|---------------------------------------------------------------|
| `pic-pictoarticleservice-article-delta-keda-enabled`          | `pic-legacy-articleservice-article-delta-keda-enabled`          |
| `pic-pictoarticleservice-article-delta-threshold`             | `pic-legacy-articleservice-article-delta-threshold`             |
| `pic-pictoarticleservice-article-full-keda-enabled`           | `pic-legacy-articleservice-article-full-keda-enabled`           |
| `pic-pictoarticleservice-article-full-threshold`              | `pic-legacy-articleservice-article-full-threshold`              |
| `pic-pictoarticleservice-article-store-delta-keda-enabled`    | `pic-legacy-articleservice-article-store-delta-keda-enabled`    |
| `pic-pictoarticleservice-article-store-delta-threshold`       | `pic-legacy-articleservice-article-store-delta-threshold`       |
| `pic-pictoarticleservice-article-store-full-keda-enabled`     | `pic-legacy-articleservice-article-store-full-keda-enabled`     |
| `pic-pictoarticleservice-article-store-full-threshold`        | `pic-legacy-articleservice-article-store-full-threshold`        |
| `pic-pictoarticleservice-hierarchy-delta-keda-enabled`        | `pic-legacy-articleservice-hierarchy-delta-keda-enabled`        |
| `pic-pictoarticleservice-hierarchy-delta-threshold`           | `pic-legacy-articleservice-hierarchy-delta-threshold`           |
| `pic-pictoarticleservice-hierarchy-full-keda-enabled`         | `pic-legacy-articleservice-hierarchy-full-keda-enabled`         |
| `pic-pictoarticleservice-hierarchy-full-threshold`            | `pic-legacy-articleservice-hierarchy-full-threshold`            |

> The 12 new KEDA names above must match the `$(...)` references in `deployment/deploy.yaml`
> **verbatim**. A single typo means the deploy-time `$(...)` substitution resolves to empty and
> the scaler silently breaks. Cross-check each new KEDA name against deploy.yaml before applying.

## Safety

- **Non-destructive add.** In `add` mode the old key is never modified, renamed, or deleted;
  `--new-name` is never used. Old and new keys coexist.
- **Write gate.** Nothing is written without an explicit `--apply`. The default is a dry-run diff.
- **Idempotent.** Check-then-create-or-update; a re-run after partial success is a no-op.
- **PAT handling.** Read only from `AZURE_DEVOPS_EXT_PAT`; never echoed, never written to disk,
  never committed. Least-privilege Library (Read, create & manage) scope.
- **Secret-source hard-stop.** Branch on `isSecret`; a secret source with no operator-supplied
  value hard-stops naming the key rather than writing an empty secret.
- **Exact-group match.** Resolve group ids by exact name; hard-stop on zero-or-multiple matches;
  `AAE`-only allowlist; never touch `AAS`.
- **Quoting.** Always double-quote `--name "$KEY"` and `--value "$VAL"` so the `__` separator and
  special characters survive shell expansion.
- **Evidence redaction.** Diff and `variable list` evidence go to a gitignored location with
  secret values and the PAT redacted.
