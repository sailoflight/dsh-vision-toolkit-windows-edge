# Subagent assignment template

Target: the parent/captain prompt sent to one subagent; never write it into root instructions. Replace every field. An explicitly assigned role skips self-classification and reads only that role's exact entry.

```text
Plane: Production | Development
Role: User | Operator | Developer | Maintainer | Reviewer | Field Evaluator
Submode: <exact registered mode>
Objective: <one verifiable outcome>
Deliverable: <report/code/tests/evidence/project document>
Authority/contract: <exact artifact or interface>
Read scope: <allowed paths/interfaces>
Write scope: report-only | <allowed paths>
Non-goals: <explicit exclusions>
Environment: production | development | test | sandbox | staging | none
Data: synthetic | fixture | sanitized | approved-real-data | none
Network and cost: forbidden | <hosts/actions/budget>
Credentials: none | <approved identity/channel; never include secret value>
Destructive actions: forbidden | <explicit approved action>
Verification: <commands/checks and expected evidence>
Return format: <findings/change summary/evidence/open decisions>
Role transitions: none | <pre-authorized role/mode and sequence>
Escalation: ask parent/captain; never ask the end user directly
```

The child inherits no role, credential, production, data, cost, or destructive permission that is not explicit above. Scope conflict or missing material authorization stops work and returns to the parent/captain; the child must not read other role guides to expand authority.
