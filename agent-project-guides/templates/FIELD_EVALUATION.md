# Field evaluation template

Target: `<project>/docs/evaluation/<scenario>.md`. Create only for an actually executed non-production realistic evaluation; never store secrets or unsanitized production data.

```markdown
# <Scenario> field evaluation

Mode: scenario-validation | exploratory-evaluation
Environment: development | test | staging
Data: synthetic | fixture | sanitized-copy | approved-real-data-copy
Evaluated at: <ISO-8601 UTC>
Version/range: <build, commit, schema, client, and data version>

## Traceability

| Scenario/requirement | Contract/usage source | Acceptance or exploration question |
|---|---|---|
| <scenario> | `<link/version>` | <observable criterion> |

## Permission boundary

<Account, network, cost budget, allowed writes/cleanup, forbidden actions, and approval.>

## Setup and procedure

<Reproducible environment/data setup and steps; identify deviations from the source workflow.>

## Observations and evidence

| Step/time | Input/action | Observed output/effect | Evidence reference |
|---|---|---|---|
| <step> | <action> | <verified observation> | <log/screenshot/report> |

## Findings

| Finding | Class | Evidence | Impact/follow-up role |
|---|---|---|---|
| <finding> | product defect/environment/data/test gap/proposal | <reference> | <Maintainer/Developer/Operator> |

## Cleanup, limitations, and residual risk

<Test data/resource cleanup, unexecuted cases, non-reproducible factors, and remaining risk.>
```

Keep raw evidence in `evidence/` when large and link it. Clearly separate observed behavior, inference, and proposal; this record does not itself change the product contract.
