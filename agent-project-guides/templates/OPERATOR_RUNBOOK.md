# Operator runbook template

Target: `<project>/docs/operations/<runbook>.md`. Create only for a deployed, scheduled, installed, or long-running system with real operator duties.

```markdown
# <System/environment> runbook

Audience: operator
Scope: <environment/service/component>
Authority/version: <deployment/config source and supported range>

## Preconditions and access

| Requirement | Source | Minimum permission | Validation |
|---|---|---|---|
| <identity/tool/secret/backup> | <secure source> | <permission> | `<read-only check>` |

## Runtime topology and health baseline

<Units, dependencies, data stores, expected version, health, traffic, and alert baseline.>

## Deploy, start, stop, or change

1. <Read-only precheck and impact window.>
2. <Backup/rollback point.>
3. <Bounded action with success signal.>
4. <Post-change health and user/data validation.>

## Configuration and secrets

| Setting class | Authority/precedence | Reload/restart | Secret rule |
|---|---|---|---|
| <setting> | <source> | <behavior> | <handling> |

## Observe and diagnose

| Signal/symptom | Query/check | Healthy threshold | Next section |
|---|---|---|---|
| <health/log/metric/alert> | `<check>` | <baseline> | <incident/recovery> |

## Incident and stop conditions

<Triage order, communication/evidence, hard stop thresholds, and Development handoff for code defects.>

## Backup, recovery, and data validation

<Recovery point, restore order, integrity checks, and accepted data-loss boundary.>

## Change and rollback plan

| Trigger | Rollback action | Verify restored state | Irreversible boundary |
|---|---|---|---|
| <condition> | `<procedure>` | `<check>` | <boundary> |

## Operation record and cleanup

<Time, actor/approval, commands/actions, versions, output/effects, temporary permissions, and remaining risk.>
```

Never embed secrets or unverified production commands. Adaptation may author and sandbox-check a runbook but does not grant production authorization.
