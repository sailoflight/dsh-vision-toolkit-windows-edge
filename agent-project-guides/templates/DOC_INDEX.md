# `docs/INDEX.md` template

Target: `<project>/docs/INDEX.md`. Create it when the project has more than one task or role entry; a very small project may merge this routing table into its existing authoritative start document.

```markdown
# Documentation index

## Current authorities

| Concern | Authority | Evidence/source |
|---|---|---|
| Current behavior | implementation and automated tests | <entry/config> |
| Public contract | <schema/types/command/tool definition> | <generated view> |
| Module boundaries | `architecture/` and `modules/` | <implementation evidence> |
| Verification selection | `verification/MATRIX.md` | build/test/CI config |
| Historical rationale | `decisions/` | linked contemporary evidence |

## Read by role

| Role | Start here | Do not preload |
|---|---|---|
| Developer | `development/START.md` | usage, operations, evidence unless needed |
| Maintainer | `development/START.md` or one module contract | production usage and operations |
| Reviewer | `verification/MATRIX.md` plus target diff/contract | package adaptation and production docs |
| Field Evaluator | one `evaluation/` scenario or non-production usage | production operations and repository source tree |
| User | one `usage/` entry or runtime delivery surface | development, internal architecture, operations |
| Operator | one `operations/` runbook | development, roadmap, broad User guidance |

## Read by task

| Need | First read | Next exact detail |
|---|---|---|
| Change source | `development/START.md` | one `modules/<module>.md` and matching tests |
| Understand a boundary | `architecture/<current>.md` | one module contract or ADR |
| Select validation | `verification/MATRIX.md` | exact build/test/CI source |
| Use a public capability | `usage/<entry>.md` | generated API/command/tool reference |
| Evaluate a scenario | `evaluation/<scenario>.md` | matching usage and environment authority |
| Operate/recover | `operations/<runbook>.md` | exact environment section |

## Non-authoritative collections

| Area | Contains | Must link back to |
|---|---|---|
| `evidence/` | raw reports, logs, screenshots | requirement, contract, or finding |
| `generated/` | derived reference | executable/schema source and generator |
| `knowledge/` | verified reusable conclusions | evidence and current affected authority |
| `roadmap/` | unimplemented plans | no claim of current behavior |
```

Delete absent roles, tasks, and directories. Every retained route must resolve; do not create empty documents to satisfy the table.
