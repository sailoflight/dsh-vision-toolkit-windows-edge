# Application UI project profile

> Read only after the `application-ui` record is selected. This profile covers web, desktop, and mobile applications whose primary deliverable is an interactive user interface.

## 1. Selection boundary

Select `application-ui` when routes/views, interaction state, user workflows, and platform behavior are the primary adapted scope. A separately operated backend can be adapted under `service` in its own scope; do not force both profiles into one pass.

## 2. Artifact preset

| Artifact | Decision | Target or template | Condition |
|---|---|---|---|
| Project constraints | required | `templates/ROOT_AGENTS.md` | Record design-system, accessibility, generated-asset, backend, and platform red lines |
| Documentation routing | required | `templates/DOC_INDEX.md` | Route product flows, frontend architecture, verification, and release operations |
| Development start | required | `templates/DEVELOPMENT_START.md` | Dev server/build/test/story/asset generation entrypoints |
| Frontend architecture | required | `templates/ARCHITECTURE_OVERVIEW.md` -> `docs/architecture/FRONTEND.md` | Routes/views, state, data, permissions, platform boundary |
| Module contract | conditional | `templates/MODULE_CONTRACT.md` | Shared state, feature boundaries, design system, native/remote adapters |
| Verification matrix | required | `templates/VERIFICATION_MATRIX.md` | Unit, component, interaction, accessibility, E2E, visual, platform checks |
| User workflows | required | `templates/USER_USAGE.md` -> `docs/usage/USER_FLOWS.md` | Supported delivered workflows and behavior, not marketing copy |
| Operator runbook | conditional | `templates/OPERATOR_RUNBOOK.md` | Only for deploy, release, signing, store, or hosted runtime duties |
| Field evaluation | conditional | `templates/FIELD_EVALUATION.md` | Approved realistic usability/workflow evaluation |

## 3. Evidence map

| Decision | Preferred evidence | Derived view |
|---|---|---|
| Navigation and views | route/view definitions and interaction tests | frontend architecture map |
| State and permissions | stores/controllers and tests | module contract |
| Backend contract | generated client/schema and integration tests | usage/error behavior |
| Visual behavior | components, design tokens, stories | screenshots as evidence only |
| Platform support | build configuration and CI/device matrix | compatibility statement |

Screenshots and reports are evidence; they do not replace executable component, interaction, accessibility, or user-flow contracts.

## 4. Application contract

Document primary user workflows, navigation, view/state ownership, loading/error/empty/permission states, backend and native boundaries, accessibility, keyboard/touch behavior, responsive constraints, persistence, and supported platforms. Generated assets and clients must name their source and regeneration command.

## 5. Verification preset

Verify state logic, component behavior, key workflows, error and permission states, accessibility, responsive layout, and supported platforms. Use visual comparison only with stable viewports/data and keep evidence separate from normative behavior. Release, signing, store, and production deployment actions remain Operator-gated.

## 6. Cold-start acceptance

A Development agent can start from one user workflow and locate its route/view, state owner, backend/native contract, tests, and visual/accessibility checks. A User can follow supported workflows without repository development instructions.
