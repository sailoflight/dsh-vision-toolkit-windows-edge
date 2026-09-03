# Architecture overview template

Default target: `<project>/docs/architecture/OVERVIEW.md`; a selected project profile may choose a more precise name such as `MCP.md`, `CLI.md`, `FRONTEND.md`, or `DATA_FLOW.md`.

````markdown
# <Scope> architecture

Status: verified | inferred | mixed
Scope: <repository/package/runtime>
Evidence: <current implementation/build/deploy/schema anchors>

## System context

<Current implemented capability, actors, external systems, and explicit exclusions.>

## Runtime topology

| Unit/process/package | Responsibility | Lifecycle owner | Communicates through |
|---|---|---|---|
| <unit> | <responsibility> | <owner> | <protocol/call/schema> |

## Module boundaries

| Module | Owns | Does not own | Entrypoint | Contract |
|---|---|---|---|---|
| <module> | <responsibility> | <exclusion/owner> | `<path/symbol>` | `../modules/<module>.md` |

## Dependency direction

```text
<upper layer> -> <lower layer> -> <adapter/infrastructure>
```

- Allowed: <rule evidenced by code/build checks>.
- Forbidden: <reverse/cross-boundary dependency>.

## Trust and side-effect boundaries

| Boundary/action | Input identity/trust | Effect | Gate/failure rule |
|---|---|---|---|
| <network/data/process/user boundary> | <trust> | <read/write/cost> | <gate> |

## Data and configuration ownership

| Item | Authority/owner | Lifecycle | Consistency/retention rule |
|---|---|---|---|
| <data/config/state> | <source/module> | <build/runtime/persistent> | <rule> |

## Failure and recovery model

<Timeout, retry, idempotency, partial-failure, restart, rollback, or recovery boundaries that shape architecture.>

## Invariants

- <Verified cross-module invariant and its evidence>.

## Unknowns and decisions

- Unknown: <fact not yet established and required evidence>.
- Decision: <link an ADR; do not repeat its historical discussion>.
````

Describe current architecture only. Keep deployment commands in runbooks, public workflows in usage, and historical arguments in ADRs.
