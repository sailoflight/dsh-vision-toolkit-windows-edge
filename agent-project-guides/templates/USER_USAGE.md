# Consumer usage template

Target: an evidenced public surface such as `<project>/docs/usage/API.md`, `CLI.md`, `MCP_CONSUMER.md`, or `USER_FLOWS.md`. Create only when an external consumer exists.

```markdown
# <Capability> usage

Audience: <end user/API/SDK/CLI/MCP consumer>
Supported version/range: <version and authority>
Reference source: <generated schema/API/command/tool surface>

## Preconditions and access

<Install/endpoint/account/environment requirements and safe credential channel.>

## Supported workflows

| Goal | Entry/capability | Result | Side effect/gate |
|---|---|---|---|
| <goal> | <UI/API/SDK/CLI/tool> | <observable result> | <write/network/cost/confirmation> |

## Inputs and outputs

<Stable semantic rules. Link generated parameter/schema/reference details rather than copying them.>

## Errors and recovery

| Error/condition | Meaning | Safe next action |
|---|---|---|
| <error> | <contract meaning> | <retry/correct/stop/escalate> |

## Security, data, and cost boundaries

<Allowed identities/data, secret handling, destructive or paid actions, and confirmation behavior.>

## Examples

<Small executable or tested examples tied to the supported version.>

## Compatibility and deprecation

<Stability promise, platform/client range, deprecation and migration path.>
```

Keep internal builds, module design, deployment, and operator recovery out of consumer usage. MCP runtime delivery should derive from the same authored contract without requiring consumers to read repository instructions.
