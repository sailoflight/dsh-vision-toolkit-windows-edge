# Service project profile

> Read only after the `service` record is selected. This profile covers long-running APIs, workers, daemons, schedulers, and backend systems whose runtime lifecycle is part of the primary architecture.

## 1. Selection boundary

Select `service` when deployment, runtime health, external requests/jobs, and persistent or remote state are primary concerns. Select `application-ui` when the user-facing GUI is the primary adapted scope, and `data-automation` when batch data flow is primary.

## 2. Artifact preset

| Artifact | Decision | Target or template | Condition |
|---|---|---|---|
| Project constraints | required | `templates/ROOT_AGENTS.md` | Record production, migration, secret, network, and generated-file red lines |
| Documentation routing | required | `templates/DOC_INDEX.md` | Separate Development, User, and Operator surfaces |
| Development start | required | `templates/DEVELOPMENT_START.md` | Local runtime, dependencies, tests, schema/migration generation |
| Architecture overview | required | `templates/ARCHITECTURE_OVERVIEW.md` | Runtime topology, trust boundaries, data ownership, and dependencies |
| Module contract | conditional | `templates/MODULE_CONTRACT.md` | Required for evidenced public/high-risk API/job, persistence, integration, or migration boundaries |
| Verification matrix | required | `templates/VERIFICATION_MATRIX.md` | Static/unit/contract/integration/staging gates |
| Consumer usage | conditional | `templates/USER_USAGE.md` -> `docs/usage/API.md` | Required for an external API or product consumer |
| Operator runbook | conditional | `templates/OPERATOR_RUNBOOK.md` | Required when the service is deployed or long-running |
| Field evaluation | conditional | `templates/FIELD_EVALUATION.md` | Approved dev/test/staging workflows only |

## 3. Evidence map

| Decision | Preferred evidence | Derived view |
|---|---|---|
| API/message/job contract | schema and registration plus contract tests | generated reference and usage |
| Runtime topology | deploy manifests and process startup | architecture topology |
| Data/transaction ownership | models, migrations, repositories, tests | module and recovery contracts |
| Configuration/secrets | schema and runtime loader | operator configuration table |
| Health/alerts/recovery | implementation, deployment, exercised runbook | operator procedures |

## 4. Service contract

Document request/message/job entry, application/domain/adapter boundaries, transaction and consistency rules, external timeout/retry/idempotency, configuration and secret ownership, migration ordering, health semantics, observability, and rollback/recovery. Public schema, migration definitions, and configuration schema remain authoritative dynamic sources.

Production writes, real credentials, migrations, deployment, and incident actions require Operator authorization; repository adaptation does not grant it.

## 5. Verification preset

Verify schema/handler consistency, unit and contract behavior, persistence with fixtures, migration ordering and rollback policy, external dependency failure paths, configuration validation, health checks, and safe runbook commands. Live/staging checks require an explicit environment, budget, stop condition, and cleanup evidence.

## 6. Cold-start acceptance

A Development agent can start from one endpoint or job and locate schema, application logic, persistence/external effects, tests, and risk gates. An Operator can identify deployed version, health baseline, rollback point, and recovery steps without loading implementation guidance.
