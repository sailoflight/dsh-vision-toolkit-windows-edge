# ADR template

Target: `<project>/docs/decisions/NNNN-<decision>.md`. Use for a consequential architecture or compatibility choice whose rationale will matter later, not for routine implementation notes.

```markdown
# NNNN: <Decision>

Status: proposed | accepted | superseded | rejected
Date: <YYYY-MM-DD>
Scope: <modules/contracts/environments>
Deciders/owner: <role or team, no secret identity data>
Supersedes: <ADR or none>
Superseded by: <ADR or none>

## Context and evidence

<Problem at decision time, verified facts, uncertainties, and evidence links.>

## Constraints and decision drivers

- <Compatibility, safety, cost, performance, schedule, or operational driver>.

## Decision

<Chosen direction and boundaries.>

## Alternatives considered

| Alternative | Benefit | Rejection/tradeoff reason |
|---|---|---|
| <option> | <benefit> | <reason at decision time> |

## Consequences

- Positive: <outcome>.
- Negative/risk: <cost and mitigation>.

## Validation and reversal

<How the decision is validated, signals that require review, and migration/reversal path.>

## Follow-up

- <Owner, action, and tracked location>.
```

ADR owns historical rationale. Current boundaries, commands, and runbooks must be updated in their own authorities and only link back here.
