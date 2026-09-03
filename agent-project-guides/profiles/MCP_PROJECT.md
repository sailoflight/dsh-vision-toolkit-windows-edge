# MCP project profile

> Read only after the `mcp` primary type is selected. This file owns MCP-specific artifact decisions and acceptance; shared adaptation order stays in the procedure and conditional bridge details stay in the selected subtype spec.

## 1. Selection boundary

Select `mcp` when the current scope primarily delivers an MCP server, gateway, or tool provider. Internal libraries/adapters do not change that type. Select another primary type when MCP is only a secondary interface to a primarily CLI, service, UI, or data deliverable.

### Conditional architecture subtype

Only after selecting `mcp`, exact-grep `routing/mcp-subtypes.jsonl` when bounded topology evidence matches one subtype. Never enumerate or preload subtype specs. `windows-wsl-bridge` applies to WSL/Linux clients calling a Windows Engine that owns native resources or persistent state; its exact spec owns all Facade/Engine/client rules. Other MCP topologies read no subtype.

## 2. Artifact preset

| Artifact | Decision | Target or template | Condition |
|---|---|---|---|
| Project constraints | required | `templates/ROOT_AGENTS.md` | MCP protocol, generated-source, side-effect and production gates |
| Documentation routing | required | `templates/DOC_INDEX.md` | May merge with development start only for a very small server |
| Development start | required | `templates/DEVELOPMENT_START.md` | Server, generation, test and transport entrypoints |
| MCP architecture | required | `templates/ARCHITECTURE_OVERVIEW.md` -> `docs/architecture/MCP.md` | Registry, dispatch, state, prompt delivery and client boundary |
| MCP architecture subtype | conditional | exact `spec` from `routing/mcp-subtypes.jsonl` | Map a precisely matched generic subtype to project entities |
| Verification matrix | required | `templates/VERIFICATION_MATRIX.md` | Protocol/client/offline/live gates |
| Module contract | conditional | `templates/MODULE_CONTRACT.md` | Public, stateful or high-risk registry/transport/tool boundary |
| Consumer usage | conditional | `templates/USER_USAGE.md` -> `docs/usage/MCP_CONSUMER.md` | External consumer exists |
| Operator runbook | conditional | `templates/OPERATOR_RUNBOOK.md` -> `docs/operations/MCP_RUNBOOK.md` | Deployed or long-running server exists |
| Field evaluation | conditional | `templates/FIELD_EVALUATION.md` | Approved non-production client workflow exists |

## 3. Evidence map

| Decision | Preferred evidence | Derived view |
|---|---|---|
| Tool identity/schema | executable registry/schema | generated reference and MCP discovery |
| Handler ownership | registration, implementation and tests | module contract summary |
| Production guidance | one canonical dual-role prompt plus protocol/client tests | runtime instructions or generated companion |
| Risk/effects | structured metadata and tests | User warning, verification gate, Operator note |
| Transport/client compatibility | initialization and compatibility tests | architecture matrix |

Never hand-maintain complete tools, parameters or schemas in README, usage, architecture and runtime prompt simultaneously.

## 4. MCP contract

Architecture/module authorities identify registry/schema/handler ownership, external versus internal calls, transport/session/state ownership, client capability behavior, and credential/network/confirmation/dry-run/budget/retry/idempotency rules.

Every MCP also owns one bounded canonical runtime prompt with actionable `Production / User` and `Production / Operator` routing, authority and transition rules. Each supported client must make it model-visible after initialization and before its first tool decision. It is not a product introduction, README, tool description or repository root instruction. A working tool catalog without that prompt fails compatibility; unsupported clients require an install-time companion generated from the same source/revision.

When tool volume materially affects context:

```text
small stable entry -> bounded capability search -> exact schema -> execute
```

Candidate results carry identity, intent and compact risk; full schemas enter context only when selected.

## 5. Verification preset

Verify unique tool names, registry/schema/handler correspondence, generated-reference drift, protocol-clean stdout, capability negotiation, canonical prompt initialization and model visibility in every supported client. Tool descriptions alone do not pass. Mutations require confirmation and applicable dry-run or a documented impossibility; live tools require a hard request budget and stop condition.

## 6. Cold-start acceptance

1. Development locates one tool's schema, handler, tests and risk without loading the catalog.
2. External cwd/chat with no project instructions receives the User contract and uses public MCP surfaces without repository/deployment inspection.
3. Availability/deployment/recovery in the same environment receives the Operator contract without product mutation authority.
4. Every supported client independently proves prompt delivery; `tools/list` success alone fails.
5. A selected architecture subtype passes its conformance checklist without reading unrelated subtype specs.
