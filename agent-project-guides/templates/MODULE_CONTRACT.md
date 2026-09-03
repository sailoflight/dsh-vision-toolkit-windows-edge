# Module contract template

Target: `<project>/docs/modules/<module>.md`. Create for public, high-risk, cross-boundary, externally integrated, generated, state-owning, or frequently changed modules; do not create one per directory.

```markdown
# <Module> contract

Status: verified | inferred | mixed
Scope: `<paths/packages>`
Architecture parent: `<architecture link>`

## Owns

- <Responsibility, state, or contract owned here>.

## Does not own

- <Excluded responsibility> -> owner: `<module/authority>`.

## Public surface and entrypoints

| Kind | Path/symbol/schema | Consumer | Stability |
|---|---|---|---|
| runtime/public/test/generate | `<entry>` | <caller> | <internal/public/generated> |

## Contracts and invariants

- <Input/output, ordering, compatibility, concurrency, or lifecycle invariant>.

## Dependencies

- Allowed: <dependency and reason>.
- Forbidden: <dependency and owner to use instead>.

## State, data, configuration, and generated files

| Item | Authority/owner | Read/write behavior | Lifecycle/regeneration |
|---|---|---|---|
| <item> | <source> | <behavior> | <rule/command> |

## Side effects and failure behavior

| Action/failure | Effect | Idempotency/retry | Required gate |
|---|---|---|---|
| <network/file/process/data/error> | <effect> | <rule> | <permission/validation> |

## Verification and change impact

| Change | Required check | Other authority to update |
|---|---|---|
| <contract/dependency/state change> | `<MATRIX entry or command>` | <usage/architecture/operations/generated/none> |

## Unknowns

- <Unverified claim and evidence needed>.
```

Only when a rule must apply before an agent reads files in the module, also create `<project>/<module>/AGENTS.md`:

```markdown
# <Module> local agent instructions

- Scope: this directory and descendants only.
- Authority: `docs/modules/<module>.md`.
- Must: <immediate local rule>.
- Must not: <forbidden dependency/write/effect>.
- Verify: `<minimum check or exact MATRIX entry>`.
```

The local file contains only immediate differences and never repeats root routing, explanations, dynamic inventories, or the full module contract.
