# Library project profile

> Read only after the `library` record is selected. This profile covers public libraries, SDKs, reusable packages, and pure-function modules whose primary deliverable is imported by another program.

## 1. Selection boundary

Select `library` when the primary contract is an importable API. Select `cli` when the command surface is the primary deliverable, even if implementation is reusable. A private package inside a monorepo is classified within the selected package scope, not automatically as a repository-level library.

## 2. Artifact preset

| Artifact | Decision | Target or template | Condition |
|---|---|---|---|
| Project constraints | required | `templates/ROOT_AGENTS.md` | Record supported runtimes, compatibility, generated-file, and release red lines |
| Documentation routing | conditional | `templates/DOC_INDEX.md` | Required when multiple packages or distinct consumer/developer surfaces exist |
| Development start | required | `templates/DEVELOPMENT_START.md` | Install, build, type, test, generate, and release entrypoints |
| Architecture overview | conditional | `templates/ARCHITECTURE_OVERVIEW.md` | Required for multiple packages, layers, state, native code, or adapters |
| Module contract | conditional | `templates/MODULE_CONTRACT.md` | Required for public/high-risk packages; may carry small-library architecture |
| Verification matrix | required | `templates/VERIFICATION_MATRIX.md` | Unit, type, contract, compatibility, example, and optional performance checks |
| Consumer usage | conditional | `templates/USER_USAGE.md` -> `docs/usage/API.md` | Public package: required stable workflows and compatibility, not a copied symbol inventory |
| Operator runbook | conditional | `templates/OPERATOR_RUNBOOK.md` | Installation or hosted runtime creates real operator duties |
| Field evaluation | conditional | `templates/FIELD_EVALUATION.md` | Approved realistic integration evaluation is part of the product |

For a very small package, development start, architecture, and module ownership may be one existing authority if the index links it unambiguously.

## 3. Evidence map

| Decision | Preferred evidence | Derived view |
|---|---|---|
| Exported symbols and signatures | source exports, declarations, schema | generated API reference |
| Runtime behavior | implementation plus contract tests | usage examples and guarantees |
| Supported environments | build matrix and CI | compatibility statement |
| Version/deprecation policy | release configuration and policy | consumer migration guidance |
| Performance/resource limits | benchmark configuration and evidence | bounded published claim |

Do not maintain the same symbol table manually in README, API usage, generated reference, and module contracts.

## 4. Library contract

Public authorities must make stable exports, input/output types, error model, state/purity, concurrency, boundary conditions, compatibility, and resource constraints discoverable. Examples that form part of the public promise must compile or run in automated verification.

Generated references are derived facts. Handwritten usage should describe stable workflows, selection guidance, errors, and compatibility rather than duplicate declarations.

## 5. Verification preset

Verify public export/reference consistency, type and unit tests, contract tests, executable examples, supported runtime matrix, deprecation paths, and any claimed performance or property invariants. Release or publish commands remain gated and are never implied by Development role selection.

## 6. Cold-start acceptance

A Development agent can start from one public symbol and locate its declaration, implementation, tests, compatibility constraint, and generated reference. A User can complete a supported workflow from usage and generated API surfaces without loading internal architecture or repository instructions.
