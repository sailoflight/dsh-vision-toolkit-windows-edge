# CLI project profile

> Read only after the `cli` record is selected. This profile covers command-line tools whose primary contract is commands, arguments, output, exit status, and side effects.

## 1. Selection boundary

Select `cli` when users primarily invoke an executable. Select `library` when the CLI is only an example or thin secondary wrapper, and `service` when the executable primarily manages a long-running runtime.

## 2. Artifact preset

| Artifact | Decision | Target or template | Condition |
|---|---|---|---|
| Project constraints | required | `templates/ROOT_AGENTS.md` | Record platform, path, network, destructive-command, and generated-reference red lines |
| Documentation routing | conditional | `templates/DOC_INDEX.md` | Required for multiple command families or separate operator/developer surfaces |
| Development start | required | `templates/DEVELOPMENT_START.md` | Parser, command, domain, adapter, test, and package entrypoints |
| CLI architecture | conditional | `templates/ARCHITECTURE_OVERVIEW.md` -> `docs/architecture/CLI.md` | Required when command dispatch or side-effect adapters are nontrivial |
| Module contract | conditional | `templates/MODULE_CONTRACT.md` | For high-risk command families or filesystem/network/process adapters |
| Verification matrix | required | `templates/VERIFICATION_MATRIX.md` | Parser, output, exit-code, config precedence, and side-effect checks |
| Consumer usage | required | `templates/USER_USAGE.md` -> `docs/usage/CLI.md` | Task workflows and stable conventions |
| Operator runbook | conditional | `templates/OPERATOR_RUNBOOK.md` | Only for installation maintenance, scheduled operation, or daemon management |
| Field evaluation | conditional | `templates/FIELD_EVALUATION.md` | For approved non-production end-to-end workflows |

## 3. Evidence map

| Decision | Preferred evidence | Derived view |
|---|---|---|
| Commands/options/defaults | parser or command definition | `--help` and generated command reference |
| stdout/stderr/exit status | implementation plus black-box tests | usage contract |
| Configuration precedence | loader implementation and tests | compact user table |
| Filesystem/network/process effects | adapters and integration tests | risk/confirmation guidance |
| Platform/package behavior | build and release configuration | install compatibility statement |

`--help` is a delivery surface, not a second authority for parser facts.

## 4. CLI contract

Prefer the dependency direction:

```text
argument parsing -> command/application layer -> domain -> side-effect adapters
```

The public contract covers command/subcommand syntax, configuration precedence, current-working-directory and path behavior, stdout/stderr separation, machine-readable output, exit status, idempotency, dry-run, confirmation, and interactive versus non-interactive behavior.

## 5. Verification preset

Verify parser/reference consistency, help output, invalid-input diagnostics, exit statuses, configuration precedence, stable machine output, and side effects through temporary directories, fixtures, or mocks. Destructive commands require explicit confirmation behavior and failure-stop tests; dry-run must prove that writes do not occur.

## 6. Cold-start acceptance

A Development agent can start from one command and locate parser registration, application logic, side-effect adapter, tests, and output/exit contract. A User can complete the workflow from CLI usage and generated help without reading implementation docs.
