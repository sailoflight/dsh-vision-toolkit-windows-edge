# Root instruction template

Target: installer-selected `<project>/AGENTS.md` or `<project>/CLAUDE.md`.

Merge only evidenced project-specific content from this template outside the managed routing block. Keep managed routing first; preserve existing project-authored bytes after it. Do not copy role guides, generic adaptation workflow, usage, runbooks, or generated inventories into the auto-loaded root.

```markdown
# Repository agent instructions

## Project scope

<One sentence: primary deliverable, runtime form, and repository scope.>

## Repository map

| Area | Owns | Start at |
|---|---|---|
| <workspace/package/module> | <stable responsibility> | `<exact index/entry>` |

Keep this map bounded. Link a generated package index when membership is dynamic.

## Instruction scope

- The selected root file applies repository-wide.
- A nearer directory `AGENTS.md` adds only local differences for its subtree.
- Project details route through `docs/INDEX.md`; do not preload the documentation tree.

## Global invariants

- <Cross-module compatibility, dependency, safety, or behavior invariant.>
- <Generated source/output ownership and regeneration rule.>
- Preserve user and parallel-agent changes outside the authorized scope.

## Risk gates

| Action | Default | Required authorization/evidence |
|---|---|---|
| Production/network/data/migration/release/destructive action | <forbidden/read-only> | <exact gate> |

## Authoritative entrypoints

| Need | Authority |
|---|---|
| Development setup and commands | `docs/development/START.md` |
| Current boundaries | `docs/architecture/OVERVIEW.md` or exact project-type architecture |
| Change verification | `docs/verification/MATRIX.md` |
| Role/task routing | `docs/INDEX.md` |

Delete rows that do not exist; never leave a broken route.
```

Merge rules:

- Keep exactly one permanent managed routing block and accurate adaptation state.
- Do not repeat managed plane/role/mode routing in project-authored sections.
- Keep only facts needed before narrower evidence is read; move explanations to their authority.
- Create a local `AGENTS.md` only for rules that must apply immediately on entering that subtree, and link its module/package contract.
- Scheme 2 completion must leave no adapter-trigger markers.
