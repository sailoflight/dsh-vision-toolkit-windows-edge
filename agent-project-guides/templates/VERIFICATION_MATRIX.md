# `docs/verification/MATRIX.md` template

Target: `<project>/docs/verification/MATRIX.md`. It selects checks from current executable sources; it is not a historical test-results log.

```markdown
# Verification matrix

## Defaults and boundaries

- Default network: offline | mocked | live-approved-only
- Default production write: forbidden
- Default data: synthetic | fixture | sanitized
- Supported verification platforms: <range and evidence>
- Broader checks trigger on: <shared contract/risk/release conditions>

## Command authorities

| Check family | Command/config source | Working directory | Expected evidence |
|---|---|---|---|
| <unit/type/build/integration> | `<config or command>` | `<path>` | <exit/report/artifact> |

## Change matrix

| Change type/scope | Fast check | Required checks | Broader trigger | External risk/cost |
|---|---|---|---|---|
| Documentation only | <link/lint> | <docs check> | <generated reference changed> | 0 |
| Internal logic | <unit/static> | <target tests> | <shared boundary> | <risk> |
| Public API/tool/CLI | <schema/static> | <contract tests> | <compatibility/release> | <risk> |
| State/data/migration | <dry-run> | <fixture/replay> | <approved integration> | <risk> |
| UI/workflow | <component> | <interaction/accessibility> | <E2E/visual/platform> | <risk> |
| Deploy/config | <lint> | <sandbox smoke> | <staging/Operator approval> | <risk> |

## Live, destructive, and costly checks

| Check | Environment/data | Approval | Budget/stop condition | Cleanup/rollback |
|---|---|---|---|---|
| <check> | <scope> | <who/what> | <limit> | <procedure> |

## Evidence and incomplete verification

Report commands/checks actually run, scope, environment, result, and relevant artifact. For skipped or failed checks, report reason, remaining risk, and exact follow-up; never convert an unrun check into a pass.
```

Do not copy command definitions when a build tool can provide the authority; link the source and record only selection rules or safe wrappers.
