# `docs/development/START.md` template

Target: `<project>/docs/development/START.md`. This is the executable Development entry, not a second architecture or usage guide.

````markdown
# Development start

## Supported environments

| Runtime/platform | Supported range | Evidence |
|---|---|---|
| <language/tool/platform> | <version/range> | <CI/build config> |

## Bootstrap

```text
<dependency/bootstrap command>
```

State working-directory requirements, offline/network behavior, and where secrets must come from. Never embed credentials.

## Entrypoints

| Purpose | Command/path | Scope/output | Side effects |
|---|---|---|---|
| Run | `<command/path>` | <scope> | <none/network/write> |
| Fast check | `<command/path>` | <scope> | <none> |
| Test | `<command/path>` | <scope> | <fixture/mock/live gate> |
| Build | `<command/path>` | <output> | <generated writes> |
| Generate | `<command/path>` | <output> | source: `<authority>` |

## Task routing

| Change area | Contract/entry | Matching verification |
|---|---|---|
| <module/package> | `<exact path>` | `../verification/MATRIX.md#<entry>` |

## Configuration, state, and data

| Item | Owner/source | Committed? | Local/test rule |
|---|---|---|---|
| <config/cache/state/fixture/secret> | <path/system> | yes/no | <rule> |

## Generated artifacts

| Output | Source | Regenerate | Check drift |
|---|---|---|---|
| <path> | <authority> | `<command>` | `<command>` |

## Common failures

| Symptom | Cheapest check | Exact detail/runbook |
|---|---|---|
| <symptom> | `<check>` | `<link>` |
````

Commands must be taken from current executable/build/CI evidence and tested at the documented working directory. Do not duplicate public usage steps or operator procedures here.
