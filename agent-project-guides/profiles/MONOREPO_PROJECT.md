# Monorepo project profile

> Read only after the `monorepo` record is selected for repository-level adaptation. This profile governs composition; it does not replace the primary-type profile selected later for an individual package scope.

## 1. Selection boundary

Select `monorepo` when the current scope is the repository root and multiple independently built, released, operated, or contracted packages/projects must be routed. Do not select it merely because the repository contains several directories. For a package-scoped pass, classify that package as `mcp`, `library`, `cli`, `service`, `application-ui`, or `data-automation` and read only that profile.

## 2. Artifact preset

| Artifact | Decision | Target or template | Condition |
|---|---|---|---|
| Root constraints | required | `templates/ROOT_AGENTS.md` | Only cross-package routing, shared red lines, and workspace-wide commands |
| Documentation routing | required | `templates/DOC_INDEX.md` | Route tasks to one package before package-local detail |
| Development start | required | `templates/DEVELOPMENT_START.md` | Workspace bootstrap, package selection, orchestration, generation, and root checks |
| Repository architecture | required | `templates/ARCHITECTURE_OVERVIEW.md` | Package inventory, dependency direction, shared contracts, release coupling |
| Package/module contract | conditional | `templates/MODULE_CONTRACT.md` | For independently owned, risky, public, or specially verified packages |
| Verification matrix | required | `templates/VERIFICATION_MATRIX.md` | Map package changes and shared contracts to affected checks |
| Repository-wide consumer usage | omit | package-scoped `templates/USER_USAGE.md` | Do not aggregate unrelated package usage at the root |
| Repository-wide operator runbook | conditional | `templates/OPERATOR_RUNBOOK.md` | Only for real shared workspace orchestration or runtime duties |
| Package local instructions | conditional | local section in `templates/MODULE_CONTRACT.md` | Only immediate package-specific rules that harness must inject on entry |

## 3. Evidence map

| Decision | Preferred evidence | Derived view |
|---|---|---|
| Package boundaries | workspace/build configuration | documentation task routing |
| Dependency direction | manifests, build graph, import rules | repository architecture graph |
| Shared schemas/protocols | schema source and compatibility tests | cross-package contract links |
| Build/test impact | task graph and CI selection | verification matrix |
| Release coupling | release configuration and history | compatibility/release order |

Do not hand-maintain a package list when the workspace tool can generate it; keep only stable ownership and routing annotations around the generated view.

## 4. Monorepo contract

Root authorities own cross-package dependency rules, shared schemas, workspace commands, task routing, compatibility/release order, and repository-wide risks. Package authorities own internal entrypoints, implementation, tests, and type-specific delivery surfaces. Local `AGENTS.md` files contain only differences that must apply before files are read and link the fuller contract.

A repository-level pass does not preload every package profile or source tree. Adapt high-risk packages one scope at a time and record partial scope when the whole repository is not verified.

## 5. Verification preset

Verify workspace graph validity, forbidden dependency directions, shared schema compatibility, affected-package test selection, root versus package command behavior, generated package index consistency, and release ordering where coupled. A root check that skips an affected package must be reported, not treated as full verification.

## 6. Cold-start acceptance

A Development agent can map a task to one package, identify its local authority and applicable project type, and avoid reading unrelated packages. A cross-package change exposes dependency, compatibility, affected-test, and release-order requirements before implementation.
