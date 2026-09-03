<!-- agent-project-guides:routing:start -->
## Agent routing

Package adaptation: status={{ADAPTATION_STATUS}}; package_revision={{PACKAGE_REVISION}}; verified_at={{VERIFIED_AT}}; scope={{ADAPTATION_SCOPE}}; reason={{ADAPTATION_REASON}}

1. Trigger is active only if this injected root has both managed marker names `agent-project-guides:adapter-trigger:start` and `agent-project-guides:adapter-trigger:end`. Routing/state and `pending/stale` are not triggers; bootstrap is template-only. If absent, never re-read/search; route now.
2. Before pwd/list/glob/read, an assigned compatible role/mode wins: content-grep its exact quoted `id` or literal label across `{{GUIDES_PATH}}/routing/*.roles.jsonl`; use one record. No fuzzy regex, discovery, planes/full registries, re-asking or rediscovery. Unmatched labels are unresolved: ask, never infer.
3. Only when unassigned read two-line `{{GUIDES_PATH}}/routing/planes.jsonl`; if unclear use the structured question tool (DSH: `ask_user_question`) and wait.
4. In that registry grep one exact role. If unclear, use the same tool and wait before its guide.
5. Blocking questions use stable IDs, 2–4 exclusive choices and impacts, not prose lists; free text only if choices mislead; ask directly only without a tool.
6. Resolve record `guide`/`procedure_by_mode` under `{{GUIDES_PATH}}/`, never relative to registry/cwd. Read only those paths; a failure is package integrity, not permission to glob.
7. Without a trigger, ask adapt-now vs continue only if intent is unclear and state is not `adapted`; explicit adaptation needs no question. Installer owns `pending/stale`; initialize/readapt records `partial/adapted/blocked`.
8. Roles never grant production credentials, real data, cost or destructive actions.

Subagents receive explicit role/mode, scope, writable paths, environment/data permissions and deliverable; missing/conflicting authority goes to parent/captain, never end user or self-expansion.
<!-- agent-project-guides:routing:end -->
