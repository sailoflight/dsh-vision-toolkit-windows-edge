# Data and automation project profile

> Read only after the `data-automation` record is selected. This profile covers batch pipelines, ETL/ELT, datasets, scheduled jobs, scripts, and workflow automation whose primary contract is reproducible input-to-output processing.

## 1. Selection boundary

Select `data-automation` when data lineage, repeatability, checkpoints, output ownership, or scheduled execution dominates the adapted scope. Select `cli` for a primarily interactive command product and `service` for a primarily long-running request/job runtime.

## 2. Artifact preset

| Artifact | Decision | Target or template | Condition |
|---|---|---|---|
| Project constraints | required | `templates/ROOT_AGENTS.md` | Record data, license, secret, overwrite, cost, and production boundaries |
| Documentation routing | conditional | `templates/DOC_INDEX.md` | Required for multiple pipelines, operators, or consumer surfaces |
| Development start | required | `templates/DEVELOPMENT_START.md` | Environment, fixture, dry-run, execute, resume, and validation entrypoints |
| Data-flow architecture | required | `templates/ARCHITECTURE_OVERVIEW.md` -> `docs/architecture/DATA_FLOW.md` | Inputs, transformations, outputs, state, schedules, external systems |
| Module contract | conditional | `templates/MODULE_CONTRACT.md` | For pipelines, connectors, schema transforms, or state/checkpoint owners |
| Verification matrix | required | `templates/VERIFICATION_MATRIX.md` | Schema, fixture, replay, determinism, idempotency, and bounded integration checks |
| Consumer usage | conditional | `templates/USER_USAGE.md` | Required for external invocation or delivered datasets/results |
| Operator runbook | conditional | `templates/OPERATOR_RUNBOOK.md` | Required for scheduled/production runs, backfills, and recovery |
| Field evaluation | conditional | `templates/FIELD_EVALUATION.md` | Only with approved non-production or sanitized data |

## 3. Evidence map

| Decision | Preferred evidence | Derived view |
|---|---|---|
| Input/output schema | schema, parser/writer, contract tests | generated field reference |
| Lineage/transforms | executable pipeline graph and code | architecture data flow |
| Scheduling/checkpoints | workflow config and state implementation | operator runbook |
| Reproducibility | lockfiles, seeds, fixtures, environment config | verification matrix |
| Data rights/retention | policy and source metadata | project/operator boundary |

Do not copy dynamic schemas or field lists manually across architecture, usage, and generated references.

## 4. Data and automation contract

Document source, format, version, license, validation, transformations, output location and overwrite semantics, deterministic inputs/seeds, incremental/checkpoint behavior, idempotency, cleanup/retention, anonymization, secrets, cost, and recovery. Production data is not a development fixture.

## 5. Verification preset

Verify schema and fixture consistency, deterministic replay where applicable, idempotent resume, overwrite protection, bounded samples, failure-stop behavior, checkpoint recovery, and output validation. Backfills, live connectors, paid services, and production writes require explicit environment, scope, budget, backup, and stop conditions.

## 6. Cold-start acceptance

A Development agent can trace one output to its input, transformation, schema, fixture, checkpoint, and verification. An Operator can identify schedule, run identity, safe retry/backfill boundary, output ownership, and recovery path without reading the full implementation.
