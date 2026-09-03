#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/agent-project-guides-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  file=$1
  text=$2
  grep -Fq -- "$text" "$file" || fail "$file does not contain: $text"
}

assert_not_contains() {
  file=$1
  text=$2
  if grep -Fq -- "$text" "$file"; then
    fail "$file unexpectedly contains: $text"
  fi
}

copy_package() {
  destination=$1
  mkdir -p "$destination"
  cp -R "$ROOT/bootstrap" "$ROOT/routing" "$ROOT/scripts" "$ROOT/profiles" "$ROOT/templates" "$ROOT/roles" "$ROOT/procedures" "$destination/"
  cp "$ROOT/PACKAGE_VERSION" "$ROOT/PACKAGE_REMOTE.json" "$destination/"
}

assert_original_suffix() {
  original=$1
  merged=$2
  bytes=$(wc -c < "$original" | tr -d '[:space:]')
  [ "$bytes" -eq 0 ] || tail -c "$bytes" "$merged" | cmp - "$original" >/dev/null || fail 'original root instruction bytes are not preserved as the suffix'
}

assert_managed_first() {
  file=$1
  [ "$(sed -n '1p' "$file")" = '<!-- agent-project-guides:routing:start -->' ] || fail "$file does not start with managed routing"
}

"$ROOT/scripts/install.sh" --help >/dev/null
node "$ROOT/scripts/validate-routing.mjs" >/dev/null
for obsolete in \
  DEVELOPER_AGENT_GUIDE.md MAINTAINER_AGENT_GUIDE.md REVIEWER_AGENT_GUIDE.md \
  FIELD_EVALUATOR_AGENT_GUIDE.md USER_AGENT_GUIDE.md OPERATOR_AGENT_GUIDE.md \
  PACKAGE_ADAPTATION_PROCEDURE.md routing/PRODUCTION_ROLES.md routing/DEVELOPMENT_ROLES.md \
  templates/CORE_DOCUMENT_TEMPLATES.md profiles/LIBRARY_AND_CLI_PROJECT.md \
  profiles/APPLICATION_SERVICE_MONOREPO.md
do
  [ ! -e "$ROOT/$obsolete" ] || fail "obsolete preload-prone path remains: $obsolete"
done
[ "$(wc -c < "$ROOT/bootstrap/AGENTS.routing-block.md" | tr -d '[:space:]')" -le 2000 ] || fail 'per-step routing block exceeded token-oriented byte budget'
assert_contains "$ROOT/bootstrap/AGENTS.routing-block.md" 'ask_user_question'
assert_contains "$ROOT/bootstrap/AGENTS.routing-block.md" '`agent-project-guides:adapter-trigger:start`'
assert_contains "$ROOT/bootstrap/AGENTS.routing-block.md" '`agent-project-guides:adapter-trigger:end`'
assert_contains "$ROOT/bootstrap/AGENTS.routing-block.md" 'Routing/state and `pending/stale` are not triggers'
assert_contains "$ROOT/bootstrap/AGENTS.routing-block.md" 'Before pwd/list/glob/read'
assert_contains "$ROOT/bootstrap/AGENTS.routing-block.md" 'No fuzzy regex'
assert_contains "$ROOT/bootstrap/AGENTS.routing-block.md" 'Unmatched labels are unresolved: ask, never infer.'
assert_contains "$ROOT/bootstrap/AGENTS.routing-block.md" 'under `{{GUIDES_PATH}}/`, never relative to registry/cwd'
assert_contains "$ROOT/bootstrap/AGENTS.routing-block.md" 'failure is package integrity, not permission to glob'
assert_contains "$ROOT/bootstrap/AGENTS.routing-block.md" 'parent/captain, never end user'
[ "$(wc -c < "$ROOT/bootstrap/AGENTS.adapter-trigger.md" | tr -d '[:space:]')" -le 3000 ] || fail 'temporary trigger exceeded token-oriented byte budget'
[ "$(wc -c < "$ROOT/bootstrap/CLAUDE.scope-block.md" | tr -d '[:space:]')" -le 500 ] || fail 'optional CLAUDE scope gate exceeded compact byte budget'
assert_contains "$ROOT/bootstrap/CLAUDE.scope-block.md" 'resolve plane/role/mode'
assert_contains "$ROOT/bootstrap/CLAUDE.scope-block.md" "selected role's permitted scope"
[ -f "$ROOT/scripts/manage-root-blocks.mjs" ] || fail 'missing byte-preserving managed-block helper'
assert_contains "$ROOT/bootstrap/AGENTS.adapter-trigger.md" 'check-update'
assert_contains "$ROOT/bootstrap/AGENTS.adapter-trigger.md" 'package_missing'
assert_contains "$ROOT/bootstrap/AGENTS.adapter-trigger.md" 'Never Read/cat a registry'
assert_contains "$ROOT/bootstrap/AGENTS.adapter-trigger.md" 'Before repository discovery, explicit compatible role/mode wins'
assert_contains "$ROOT/bootstrap/AGENTS.adapter-trigger.md" 'assigned literal alias'
assert_contains "$ROOT/bootstrap/AGENTS.adapter-trigger.md" 'do not read `planes.jsonl`'
assert_contains "$ROOT/bootstrap/AGENTS.adapter-trigger.md" 'project_type'
assert_contains "$ROOT/bootstrap/AGENTS.adapter-trigger.md" 'resume only recorded scope/reason'
assert_contains "$ROOT/bootstrap/AGENTS.adapter-trigger.md" 'resolving both under `{{GUIDES_PATH}}/`, never relative to the registry or cwd'
assert_contains "$ROOT/bootstrap/AGENTS.adapter-trigger.md" 'never preload templates'
routing_bytes=$(wc -c < "$ROOT/routing/planes.jsonl")
routing_bytes=$((routing_bytes + $(wc -c < "$ROOT/routing/production.roles.jsonl") + $(wc -c < "$ROOT/routing/development.roles.jsonl")))
[ "$routing_bytes" -le 2200 ] || fail 'plane and role registries exceeded token-oriented byte budget'
maintainer_alias=$(grep -F '"仓库维护者"' "$ROOT/routing/development.roles.jsonl")
printf '%s\n' "$maintainer_alias" | grep -Fq '"id":"maintainer"' || fail '仓库维护者 alias does not resolve directly to maintainer'
[ "$(grep -Fc '"仓库维护者"' "$ROOT/routing/development.roles.jsonl")" -eq 1 ] || fail '仓库维护者 alias is not unique within development routing'
maintainer_guide=$(node -e 'const r=JSON.parse(process.argv[1]); process.stdout.write(r.guide)' "$maintainer_alias")
maintainer_procedure=$(node -e 'const r=JSON.parse(process.argv[1]); process.stdout.write(r.procedure_by_mode.readapt)' "$maintainer_alias")
[ -f "$ROOT/$maintainer_guide" ] || fail 'maintainer guide did not resolve from package root'
[ -f "$ROOT/$maintainer_procedure" ] || fail 'maintainer procedure did not resolve from package root'
[ ! -e "$ROOT/routing/$maintainer_guide" ] || fail 'test fixture accidentally permits registry-relative guide resolution'
[ ! -e "$ROOT/routing/$maintainer_procedure" ] || fail 'test fixture accidentally permits registry-relative procedure resolution'
field_evaluator_alias=$(grep -F '"实战探索者"' "$ROOT/routing/development.roles.jsonl")
printf '%s\n' "$field_evaluator_alias" | grep -Fq '"id":"field-evaluator"' || fail 'exploration/practical alias does not resolve directly to field-evaluator'
for alias in '"实战评估者"' '"实战探索者"' '"探索评估者"'; do
  [ "$(grep -Fc "$alias" "$ROOT/routing/development.roles.jsonl")" -eq 1 ] || fail "field-evaluator alias is not unique: $alias"
done
[ "$(wc -c < "$ROOT/routing/project-types.jsonl" | tr -d '[:space:]')" -le 1200 ] || fail 'project type registry exceeded token-oriented byte budget'
project_type_ids=$(node -e 'const fs=require("fs"); const rows=fs.readFileSync(process.argv[1],"utf8").trim().split(/\n/).map(JSON.parse); process.stdout.write(rows.map(r=>r.id).join(","))' "$ROOT/routing/project-types.jsonl")
[ "$project_type_ids" = 'mcp,library,cli,service,application-ui,data-automation,monorepo' ] || fail 'project type registry is not the exact ordered closed set'
[ "$(wc -c < "$ROOT/routing/mcp-subtypes.jsonl" | tr -d '[:space:]')" -le 400 ] || fail 'MCP subtype registry exceeded compact byte budget'
mcp_subtype=$(grep -F '"id":"windows-wsl-bridge"' "$ROOT/routing/mcp-subtypes.jsonl")
[ "$(printf '%s\n' "$mcp_subtype" | wc -l | tr -d '[:space:]')" -eq 1 ] || fail 'Windows-WSL MCP subtype is not uniquely routable'
mcp_subtype_spec=$(node -e 'const r=JSON.parse(process.argv[1]); process.stdout.write(r.spec)' "$mcp_subtype")
[ -f "$ROOT/$mcp_subtype_spec" ] || fail 'MCP subtype spec did not resolve from package root'
assert_contains "$ROOT/$mcp_subtype_spec" '## 4. 双生产角色运行时提示（强制）'
assert_contains "$ROOT/$mcp_subtype_spec" '不是 MCP 产品简介'
assert_contains "$ROOT/$mcp_subtype_spec" '无项目 `AGENTS.md` 的外部 cwd/聊天环境'
assert_contains "$ROOT/profiles/MCP_PROJECT.md" 'one bounded canonical runtime prompt'
assert_contains "$ROOT/profiles/MCP_PROJECT.md" 'Tool descriptions alone do not pass.'
assert_contains "$ROOT/README.md" '禁止 profile 复述 subtype 章节'
assert_contains "$ROOT/procedures/PACKAGE_ADAPTATION.md" '本文件只拥有适配算法'
assert_contains "$ROOT/profiles/MCP_PROJECT.md" 'conditional bridge details stay in the selected subtype spec'
assert_contains "$ROOT/profiles/mcp/WINDOWS_WSL_BRIDGE.md" '本文件独占该拓扑的通用职责'
assert_not_contains "$ROOT/bootstrap/AGENTS.adapter-trigger.md" 'library-cli'
assert_not_contains "$ROOT/bootstrap/AGENTS.adapter-trigger.md" 'application-service-monorepo'
for profile in MCP_PROJECT LIBRARY_PROJECT CLI_PROJECT SERVICE_PROJECT APPLICATION_UI_PROJECT DATA_AUTOMATION_PROJECT MONOREPO_PROJECT
do
  file="$ROOT/profiles/$profile.md"
  [ -f "$file" ] || fail "missing project profile: $profile"
  assert_contains "$file" '## 1. Selection boundary'
  assert_contains "$file" '## 2. Artifact preset'
  assert_contains "$file" '## 3. Evidence map'
  assert_contains "$file" '## 5. Verification preset'
  assert_contains "$file" '## 6. Cold-start acceptance'
done
assert_contains "$ROOT/templates/ROOT_AGENTS.md" '## Repository map'
assert_contains "$ROOT/templates/ROOT_AGENTS.md" 'Keep managed routing first'
assert_contains "$ROOT/templates/DOC_INDEX.md" '## Current authorities'
assert_contains "$ROOT/templates/DEVELOPMENT_START.md" '## Supported environments'
assert_contains "$ROOT/templates/ARCHITECTURE_OVERVIEW.md" '## Trust and side-effect boundaries'
assert_contains "$ROOT/templates/MODULE_CONTRACT.md" '## Public surface and entrypoints'
assert_contains "$ROOT/templates/VERIFICATION_MATRIX.md" '## Command authorities'
assert_contains "$ROOT/templates/USER_USAGE.md" '## Supported workflows'
assert_contains "$ROOT/templates/OPERATOR_RUNBOOK.md" '## Change and rollback plan'
assert_contains "$ROOT/templates/FIELD_EVALUATION.md" '## Traceability'
assert_contains "$ROOT/templates/ADR.md" '## Validation and reversal'
assert_contains "$ROOT/templates/SUBAGENT_ASSIGNMENT.md" 'Authority/contract:'
assert_contains "$ROOT/procedures/PACKAGE_ADAPTATION.md" '不得预读多个 profile'
assert_contains "$ROOT/procedures/PACKAGE_ADAPTATION.md" '禁止批量预读模板'
assert_contains "$ROOT/procedures/PACKAGE_ADAPTATION.md" '不得先询问是否跳过'
assert_contains "$ROOT/procedures/PACKAGE_ADAPTATION.md" '不提前提问'
assert_contains "$ROOT/procedures/PACKAGE_ADAPTATION.md" '必须与工具轨迹一致'
assert_contains "$ROOT/procedures/PACKAGE_ADAPTATION.md" '相对治理包根目录解析'
assert_contains "$ROOT/procedures/PACKAGE_ADAPTATION.md" '禁止用 glob 猜路径'
[ "$(wc -c < "$ROOT/roles/development/DEVELOPER.md" | tr -d '[:space:]')" -le 4000 ] || fail 'Developer guide regained initializer duplication'
[ "$(wc -c < "$ROOT/procedures/PACKAGE_ADAPTATION.md" | tr -d '[:space:]')" -le 9500 ] || fail 'adaptation procedure exceeded ownership budget'
[ "$(wc -c < "$ROOT/profiles/MCP_PROJECT.md" | tr -d '[:space:]')" -le 5500 ] || fail 'MCP profile regained subtype or procedure duplication'
[ "$(wc -c < "$ROOT/profiles/mcp/WINDOWS_WSL_BRIDGE.md" | tr -d '[:space:]')" -le 8500 ] || fail 'Windows-WSL subtype spec exceeded ownership budget'
[ "$(wc -c < "$ROOT/README.md" | tr -d '[:space:]')" -le 11000 ] || fail 'README regained procedure or profile duplication'
if grep -Eq '(^|[[:space:]])(dsh|claude|codex)([[:space:]]|$)' "$ROOT/scripts/install.sh"; then
  fail 'installer appears to invoke an LLM runner'
fi

# Scheme 1 places permanent routing first and preserves original content byte-for-byte as the suffix.
PROJECT_ONE="$TMP/scheme one"
PACKAGE_ONE="$PROJECT_ONE/tools/agent project guides"
mkdir -p "$PROJECT_ONE/.git" "$PROJECT_ONE/tools"
copy_package "$PACKAGE_ONE"
printf '# Original project rules\n\n- Preserve this exact rule.\n' > "$PROJECT_ONE/AGENTS.md"
cp "$PROJECT_ONE/AGENTS.md" "$TMP/original-one.md"

"$PACKAGE_ONE/scripts/install.sh" merge
assert_managed_first "$PROJECT_ONE/AGENTS.md"
assert_original_suffix "$TMP/original-one.md" "$PROJECT_ONE/AGENTS.md"
assert_contains "$PROJECT_ONE/AGENTS.md" '<!-- agent-project-guides:routing:start -->'
assert_contains "$PROJECT_ONE/AGENTS.md" 'status=pending; package_revision=1.4.3; verified_at=never; scope=repo; reason=not_adapted'
assert_not_contains "$PROJECT_ONE/AGENTS.md" '<!-- agent-project-guides:adapter-trigger:start -->'
assert_contains "$PROJECT_ONE/AGENTS.md" 'Routing/state and `pending/stale` are not triggers'
[ ! -e "$PROJECT_ONE/AGENTS_origin.md" ] || fail 'scheme 1 renamed or backed up original AGENTS.md'
"$PACKAGE_ONE/scripts/install.sh" check
before=$(sha256sum "$PROJECT_ONE/AGENTS.md" | cut -d' ' -f1)
"$PACKAGE_ONE/scripts/install.sh" merge >/dev/null
after=$(sha256sum "$PROJECT_ONE/AGENTS.md" | cut -d' ' -f1)
[ "$before" = "$after" ] || fail 'scheme 1 merge is not idempotent'

# Byte preservation includes roots without a trailing newline.
PROJECT_BYTES="$TMP/no-trailing-newline"
PACKAGE_BYTES="$PROJECT_BYTES/agent-project-guides"
mkdir -p "$PROJECT_BYTES/.git"
copy_package "$PACKAGE_BYTES"
printf '# No trailing newline' > "$PROJECT_BYTES/AGENTS.md"
cp "$PROJECT_BYTES/AGENTS.md" "$TMP/original-bytes.md"
"$PACKAGE_BYTES/scripts/install.sh" merge >/dev/null
assert_managed_first "$PROJECT_BYTES/AGENTS.md"
assert_original_suffix "$TMP/original-bytes.md" "$PROJECT_BYTES/AGENTS.md"
"$PACKAGE_BYTES/scripts/install.sh" unmerge >/dev/null
cmp "$PROJECT_BYTES/AGENTS.md" "$TMP/original-bytes.md" >/dev/null || fail 'no-newline root did not round-trip byte-for-byte'

# A legacy tail-position managed block is migrated to the prefix without changing project content.
sed -n '/<!-- agent-project-guides:routing:start -->/,/<!-- agent-project-guides:routing:end -->/p' "$PROJECT_ONE/AGENTS.md" > "$TMP/legacy-tail-routing.md"
node "$PACKAGE_ONE/scripts/manage-root-blocks.mjs" strip "$PROJECT_ONE/AGENTS.md" "$TMP/legacy-tail-content.md" \
  '<!-- agent-project-guides:routing:start -->' '<!-- agent-project-guides:routing:end -->'
cat "$TMP/legacy-tail-content.md" "$TMP/legacy-tail-routing.md" > "$PROJECT_ONE/AGENTS.md"
if "$PACKAGE_ONE/scripts/install.sh" check >/dev/null 2>&1; then
  fail 'check accepted routing behind project-authored instructions'
fi
"$PACKAGE_ONE/scripts/install.sh" merge >/dev/null
assert_managed_first "$PROJECT_ONE/AGENTS.md"
assert_original_suffix "$TMP/original-one.md" "$PROJECT_ONE/AGENTS.md"
"$PACKAGE_ONE/scripts/install.sh" check

# Cloud freshness checks are read-only and distinguish current, differing, and unavailable sources.
before=$(sha256sum "$PROJECT_ONE/AGENTS.md" | cut -d' ' -f1)
current=$(AGENT_PROJECT_GUIDES_VERSION_URL='data:text/plain,1.4.3%0A' "$PACKAGE_ONE/scripts/install.sh" check-update)
printf '%s\n' "$current" | grep -Fq '"status":"current"' || fail 'check-update did not report current remote revision'
different=$(AGENT_PROJECT_GUIDES_VERSION_URL='data:text/plain,9.9.9%0A' "$PACKAGE_ONE/scripts/install.sh" check-update)
printf '%s\n' "$different" | grep -Fq '"status":"remote_differs"' || fail 'check-update did not report differing remote revision'
unavailable=$(AGENT_PROJECT_GUIDES_VERSION_URL='data:text/plain,not%20a%20revision' "$PACKAGE_ONE/scripts/install.sh" check-update)
printf '%s\n' "$unavailable" | grep -Fq '"status":"unavailable"' || fail 'check-update did not report invalid remote metadata as unavailable'
mkdir -p "$TMP/fake-bin"
printf '#!/bin/sh\nprintf "MS40LjM=\\n"\n' > "$TMP/fake-bin/gh"
chmod 0755 "$TMP/fake-bin/gh"
private=$(PATH="$TMP/fake-bin:$PATH" "$PACKAGE_ONE/scripts/install.sh" check-update)
printf '%s\n' "$private" | grep -Fq '"transport":"gh"' || fail 'check-update did not use authenticated gh fallback for a private repository'
printf '%s\n' "$private" | grep -Fq '"status":"current"' || fail 'gh fallback did not decode the remote revision'
after=$(sha256sum "$PROJECT_ONE/AGENTS.md" | cut -d' ' -f1)
[ "$before" = "$after" ] || fail 'check-update modified root instructions'

# Scheme 2 places routing then one temporary trigger before project content; it never renames the root file.
PROJECT_TWO="$TMP/scheme-two"
PACKAGE_TWO="$PROJECT_TWO/agent-project-guides"
mkdir -p "$PROJECT_TWO/.git"
copy_package "$PACKAGE_TWO"
printf '# Existing safety rules\n\n- Production writes require approval.\n' > "$PROJECT_TWO/AGENTS.md"
cp "$PROJECT_TWO/AGENTS.md" "$TMP/original-two.md"

"$PACKAGE_TWO/scripts/install.sh" trigger
assert_managed_first "$PROJECT_TWO/AGENTS.md"
assert_original_suffix "$TMP/original-two.md" "$PROJECT_TWO/AGENTS.md"
assert_contains "$PROJECT_TWO/AGENTS.md" 'Source: https://github.com/sailoflight/agent-project-guides.'
assert_contains "$PROJECT_TWO/AGENTS.md" 'routing/project-types.jsonl'
[ ! -e "$PROJECT_TWO/AGENTS_origin.md" ] || fail 'scheme 2 renamed original AGENTS.md'
routing_line=$(grep -nF '<!-- agent-project-guides:routing:start -->' "$PROJECT_TWO/AGENTS.md" | cut -d: -f1)
trigger_line=$(grep -nF '<!-- agent-project-guides:adapter-trigger:start -->' "$PROJECT_TWO/AGENTS.md" | cut -d: -f1)
[ "$routing_line" -lt "$trigger_line" ] || fail 'temporary trigger does not follow permanent routing'
"$PACKAGE_TWO/scripts/install.sh" check
before=$(sha256sum "$PROJECT_TWO/AGENTS.md" | cut -d' ' -f1)
"$PACKAGE_TWO/scripts/install.sh" trigger >/dev/null
after=$(sha256sum "$PROJECT_TWO/AGENTS.md" | cut -d' ' -f1)
[ "$before" = "$after" ] || fail 'scheme 2 trigger is not idempotent'
if "$PACKAGE_TWO/scripts/install.sh" remove-trigger >/dev/null 2>&1; then
  fail 'pending trigger was removed before adaptation completed'
fi
before=$(sha256sum "$PROJECT_TWO/AGENTS.md" | cut -d' ' -f1)
if "$PACKAGE_TWO/scripts/install.sh" set-state --status adapted --verified-at never --scope repo --reason none >/dev/null 2>&1; then
  fail 'adapted state accepted an invalid timestamp'
fi
if "$PACKAGE_TWO/scripts/install.sh" set-state --status adapted --verified-at 2026-0x-24T12:00:00Z --scope repo --reason none >/dev/null 2>&1; then
  fail 'state accepted a non-digit timestamp'
fi
if "$PACKAGE_TWO/scripts/install.sh" set-state --status blocked --verified-at never --scope repo --reason 'secret;detail' >/dev/null 2>&1; then
  fail 'state accepted a non-compact reason'
fi
after=$(sha256sum "$PROJECT_TWO/AGENTS.md" | cut -d' ' -f1)
[ "$before" = "$after" ] || fail 'invalid state arguments changed root instructions'

# A partial result requires verified scope/time and a reason; blocked runs require explicit retry.
"$PACKAGE_TWO/scripts/install.sh" set-state --status partial --verified-at 2026-08-24T11:30:00Z --scope docs/api --reason remaining_modules >/dev/null
"$PACKAGE_TWO/scripts/install.sh" check
assert_contains "$PROJECT_TWO/AGENTS.md" 'status=partial; package_revision=1.4.3; verified_at=2026-08-24T11:30:00Z; scope=docs/api; reason=remaining_modules'
"$PACKAGE_TWO/scripts/install.sh" set-state --status blocked --verified-at never --scope repo --reason missing_owner_decision
assert_contains "$PROJECT_TWO/AGENTS.md" 'status=blocked; package_revision=1.4.3; verified_at=never; scope=repo; reason=missing_owner_decision'
"$PACKAGE_TWO/scripts/install.sh" check
"$PACKAGE_TWO/scripts/install.sh" trigger >/dev/null
assert_contains "$PROJECT_TWO/AGENTS.md" 'status=pending; package_revision=1.4.3; verified_at=never; scope=repo; reason=retry_requested'

# Crash recovery: adapted state may coexist briefly with the trigger, then cleanup removes only the trigger.
"$PACKAGE_TWO/scripts/install.sh" set-state --status adapted --verified-at 2026-08-24T12:00:00Z --scope repo --reason none
"$PACKAGE_TWO/scripts/install.sh" check
before=$(sha256sum "$PROJECT_TWO/AGENTS.md" | cut -d' ' -f1)
"$PACKAGE_TWO/scripts/install.sh" trigger >/dev/null
after=$(sha256sum "$PROJECT_TWO/AGENTS.md" | cut -d' ' -f1)
[ "$before" = "$after" ] || fail 'adapted crash recovery repeated or changed adaptation'
"$PACKAGE_TWO/scripts/install.sh" remove-trigger
assert_not_contains "$PROJECT_TWO/AGENTS.md" '<!-- agent-project-guides:adapter-trigger:start -->'
assert_managed_first "$PROJECT_TWO/AGENTS.md"
assert_original_suffix "$TMP/original-two.md" "$PROJECT_TWO/AGENTS.md"
"$PACKAGE_TWO/scripts/install.sh" check

# Explicit later trigger marks an adapted project stale for re-adaptation.
"$PACKAGE_TWO/scripts/install.sh" trigger >/dev/null
assert_contains "$PROJECT_TWO/AGENTS.md" 'status=stale; package_revision=1.4.3; verified_at=2026-08-24T12:00:00Z; scope=repo; reason=explicit_readaptation'
"$PACKAGE_TWO/scripts/install.sh" set-state --status adapted --verified-at 2026-08-24T13:00:00Z --scope repo --reason none >/dev/null
"$PACKAGE_TWO/scripts/install.sh" remove-trigger >/dev/null
assert_managed_first "$PROJECT_TWO/AGENTS.md"
assert_original_suffix "$TMP/original-two.md" "$PROJECT_TWO/AGENTS.md"
"$PACKAGE_TWO/scripts/install.sh" unmerge
assert_not_contains "$PROJECT_TWO/AGENTS.md" '<!-- agent-project-guides:routing:start -->'
cmp "$PROJECT_TWO/AGENTS.md" "$TMP/original-two.md" >/dev/null || fail 'unmerge did not restore original AGENTS.md bytes'

# Root selection prefers AGENTS.md, supports a sole small CLAUDE.md, and preserves siblings.
PROJECT_THREE="$TMP/root-selection-project"
PACKAGE_THREE="$PROJECT_THREE/agent-project-guides"
mkdir -p "$PROJECT_THREE"
printf 'gitdir: elsewhere\n' > "$PROJECT_THREE/.git"
copy_package "$PACKAGE_THREE"
if "$PACKAGE_THREE/scripts/install.sh" check 2> "$TMP/missing-root.err"; then
  fail 'check accepted missing selected root instructions'
fi
assert_contains "$TMP/missing-root.err" 'selected root AGENTS.md does not exist'

printf '# Claude-only project rules\n\n- Preserve this exact rule.\n' > "$PROJECT_THREE/CLAUDE.md"
cp "$PROJECT_THREE/CLAUDE.md" "$TMP/original-claude.md"
if "$PACKAGE_THREE/scripts/install.sh" trigger --sync-claude-scope >/dev/null 2>&1; then
  fail 'CLAUDE scope sync accepted a sole CLAUDE.md root'
fi
cmp "$PROJECT_THREE/CLAUDE.md" "$TMP/original-claude.md" >/dev/null || fail 'invalid scope sync changed sole CLAUDE.md'
"$PACKAGE_THREE/scripts/install.sh" trigger >/dev/null
assert_managed_first "$PROJECT_THREE/CLAUDE.md"
assert_original_suffix "$TMP/original-claude.md" "$PROJECT_THREE/CLAUDE.md"
assert_contains "$PROJECT_THREE/CLAUDE.md" 're-read `CLAUDE.md`'
[ ! -e "$PROJECT_THREE/AGENTS.md" ] || fail 'small CLAUDE-only install unnecessarily created AGENTS.md'
"$PACKAGE_THREE/scripts/install.sh" check
"$PACKAGE_THREE/scripts/install.sh" set-state --status adapted --verified-at 2026-08-24T14:30:00Z --scope repo --reason none >/dev/null
"$PACKAGE_THREE/scripts/install.sh" remove-trigger >/dev/null
"$PACKAGE_THREE/scripts/install.sh" unmerge >/dev/null
cmp "$PROJECT_THREE/CLAUDE.md" "$TMP/original-claude.md" >/dev/null || fail 'CLAUDE.md lifecycle changed original content'

printf '# Preferred agent rules\n' > "$PROJECT_THREE/AGENTS.md"
printf '# Local overlay\n' > "$PROJECT_THREE/AGENTS.local.md"
cp "$PROJECT_THREE/AGENTS.md" "$TMP/multi-root-agents.md"
cp "$PROJECT_THREE/CLAUDE.md" "$TMP/multi-root-claude.md"
cp "$PROJECT_THREE/AGENTS.local.md" "$TMP/multi-root-local.md"

# Without the opt-in flag, only the selected AGENTS.md changes.
"$PACKAGE_THREE/scripts/install.sh" merge >/dev/null
assert_managed_first "$PROJECT_THREE/AGENTS.md"
cmp "$PROJECT_THREE/CLAUDE.md" "$TMP/multi-root-claude.md" >/dev/null || fail 'multi-root merge changed non-selected CLAUDE.md without opt-in'
assert_not_contains "$PROJECT_THREE/CLAUDE.md" '<!-- agent-project-guides:claude-scope:start -->'
"$PACKAGE_THREE/scripts/install.sh" check
if "$PACKAGE_THREE/scripts/install.sh" check --sync-claude-scope >/dev/null 2>&1; then
  fail 'opt-in check accepted a missing CLAUDE scope block'
fi
"$PACKAGE_THREE/scripts/install.sh" unmerge >/dev/null
cmp "$PROJECT_THREE/AGENTS.md" "$TMP/multi-root-agents.md" >/dev/null || fail 'multi-root unmerge did not restore AGENTS.md'

# The opt-in scope sync prepends only a generic role gate and is idempotent.
"$PACKAGE_THREE/scripts/install.sh" merge --sync-claude-scope >/dev/null
assert_managed_first "$PROJECT_THREE/AGENTS.md"
[ "$(sed -n '1p' "$PROJECT_THREE/CLAUDE.md")" = '<!-- agent-project-guides:claude-scope:start -->' ] || fail 'opt-in CLAUDE scope block is not first'
assert_original_suffix "$TMP/multi-root-claude.md" "$PROJECT_THREE/CLAUDE.md"
assert_not_contains "$PROJECT_THREE/CLAUDE.md" '<!-- agent-project-guides:routing:start -->'
"$PACKAGE_THREE/scripts/install.sh" check --sync-claude-scope
agents_before=$(sha256sum "$PROJECT_THREE/AGENTS.md" | cut -d' ' -f1)
claude_before=$(sha256sum "$PROJECT_THREE/CLAUDE.md" | cut -d' ' -f1)
"$PACKAGE_THREE/scripts/install.sh" merge --sync-claude-scope >/dev/null
[ "$agents_before" = "$(sha256sum "$PROJECT_THREE/AGENTS.md" | cut -d' ' -f1)" ] || fail 'opt-in AGENTS merge is not idempotent'
[ "$claude_before" = "$(sha256sum "$PROJECT_THREE/CLAUDE.md" | cut -d' ' -f1)" ] || fail 'opt-in CLAUDE scope sync is not idempotent'

# A transaction marker makes interrupted two-root sync detectable and recoverable.
printf 'sync-claude-scope\n' > "$PROJECT_THREE/.agent-project-guides.transaction"
node "$PACKAGE_THREE/scripts/manage-root-blocks.mjs" strip "$PROJECT_THREE/CLAUDE.md" "$TMP/partial-claude.md" \
  '<!-- agent-project-guides:claude-scope:start -->' '<!-- agent-project-guides:claude-scope:end -->'
cp "$TMP/partial-claude.md" "$PROJECT_THREE/CLAUDE.md"
if "$PACKAGE_THREE/scripts/install.sh" check >/dev/null 2>&1; then
  fail 'check accepted an incomplete two-root transaction'
fi
"$PACKAGE_THREE/scripts/install.sh" merge --sync-claude-scope >/dev/null
[ ! -e "$PROJECT_THREE/.agent-project-guides.transaction" ] || fail 'scope recovery left a transaction marker'
[ "$claude_before" = "$(sha256sum "$PROJECT_THREE/CLAUDE.md" | cut -d' ' -f1)" ] || fail 'scope recovery did not restore canonical CLAUDE content'

"$PACKAGE_THREE/scripts/install.sh" merge >/dev/null
[ "$claude_before" = "$(sha256sum "$PROJECT_THREE/CLAUDE.md" | cut -d' ' -f1)" ] || fail 'ordinary merge removed or changed an existing optional CLAUDE scope'

# Interrupted unmerge is also resumed idempotently.
printf 'unmerge\n' > "$PROJECT_THREE/.agent-project-guides.transaction"
node "$PACKAGE_THREE/scripts/manage-root-blocks.mjs" strip "$PROJECT_THREE/CLAUDE.md" "$TMP/partial-unmerge-claude.md" \
  '<!-- agent-project-guides:claude-scope:start -->' '<!-- agent-project-guides:claude-scope:end -->'
cp "$TMP/partial-unmerge-claude.md" "$PROJECT_THREE/CLAUDE.md"
"$PACKAGE_THREE/scripts/install.sh" unmerge >/dev/null
[ ! -e "$PROJECT_THREE/.agent-project-guides.transaction" ] || fail 'unmerge recovery left a transaction marker'
cmp "$PROJECT_THREE/AGENTS.md" "$TMP/multi-root-agents.md" >/dev/null || fail 'scope unmerge did not restore AGENTS.md'
cmp "$PROJECT_THREE/CLAUDE.md" "$TMP/multi-root-claude.md" >/dev/null || fail 'scope unmerge did not restore CLAUDE.md'
cmp "$PROJECT_THREE/AGENTS.local.md" "$TMP/multi-root-local.md" >/dev/null || fail 'scope sync changed local overlay'

# Real routing markers in a non-selected root remain a hard conflict.
"$PACKAGE_THREE/scripts/install.sh" merge >/dev/null
printf '\n<!-- agent-project-guides:routing:start -->\n' >> "$PROJECT_THREE/CLAUDE.md"
if "$PACKAGE_THREE/scripts/install.sh" check >/dev/null 2>&1; then
  fail 'check accepted package routing markers in multiple root candidates'
fi
cp "$TMP/multi-root-claude.md" "$PROJECT_THREE/CLAUDE.md"
"$PACKAGE_THREE/scripts/install.sh" unmerge >/dev/null
rm "$PROJECT_THREE/AGENTS.md" "$PROJECT_THREE/AGENTS.local.md"

# A sole oversized CLAUDE.md remains untouched; routing moves to a new short AGENTS.md.
dd if=/dev/zero bs=16200 count=1 2>/dev/null | tr '\000' x > "$PROJECT_THREE/CLAUDE.md"
cp "$PROJECT_THREE/CLAUDE.md" "$TMP/oversized-claude.md"
if "$PACKAGE_THREE/scripts/install.sh" merge --sync-claude-scope >/dev/null 2>&1; then
  fail 'scope sync accepted a CLAUDE.md that would exceed the instruction cap'
fi
[ ! -e "$PROJECT_THREE/AGENTS.md" ] || fail 'failed CLAUDE scope preflight created AGENTS.md'
cmp "$PROJECT_THREE/CLAUDE.md" "$TMP/oversized-claude.md" >/dev/null || fail 'failed CLAUDE scope preflight changed original content'
"$PACKAGE_THREE/scripts/install.sh" merge >/dev/null
assert_contains "$PROJECT_THREE/AGENTS.md" '<!-- agent-project-guides:routing:start -->'
cmp "$PROJECT_THREE/CLAUDE.md" "$TMP/oversized-claude.md" >/dev/null || fail 'oversized CLAUDE.md fallback changed original content'
"$PACKAGE_THREE/scripts/install.sh" check
"$PACKAGE_THREE/scripts/install.sh" unmerge >/dev/null
rm "$PROJECT_THREE/AGENTS.md" "$PROJECT_THREE/CLAUDE.md"

# Legacy root-replacement handoff markers require explicit old-version recovery.
printf '# Legacy\n<!-- agent-project-guides:handoff:start -->\n' > "$PROJECT_THREE/AGENTS.md"
cp "$PROJECT_THREE/AGENTS.md" "$TMP/legacy-root.md"
if "$PACKAGE_THREE/scripts/install.sh" merge >/dev/null 2>&1; then
  fail 'managed-prefix merge accepted a legacy root-replacement handoff'
fi
cmp "$PROJECT_THREE/AGENTS.md" "$TMP/legacy-root.md" >/dev/null || fail 'legacy refusal changed root instructions'
rm "$PROJECT_THREE/AGENTS.md"

# Unbalanced reserved markers fail before any root rewrite.
printf '# Original\n<!-- agent-project-guides:routing:end -->\n' > "$PROJECT_THREE/AGENTS.md"
cp "$PROJECT_THREE/AGENTS.md" "$TMP/unbalanced-root.md"
if "$PACKAGE_THREE/scripts/install.sh" merge >/dev/null 2>&1; then
  fail 'merge accepted an unbalanced existing routing marker'
fi
cmp "$PROJECT_THREE/AGENTS.md" "$TMP/unbalanced-root.md" >/dev/null || fail 'marker preflight failure changed root instructions'
rm "$PROJECT_THREE/AGENTS.md"

# A balanced trigger without permanent routing is invalid and is not silently dropped.
printf '# Original\n<!-- agent-project-guides:adapter-trigger:start -->\n<!-- agent-project-guides:adapter-trigger:end -->\n' > "$PROJECT_THREE/AGENTS.md"
cp "$PROJECT_THREE/AGENTS.md" "$TMP/orphan-trigger.md"
if "$PACKAGE_THREE/scripts/install.sh" merge >/dev/null 2>&1; then
  fail 'merge accepted an adapter trigger without permanent routing'
fi
cmp "$PROJECT_THREE/AGENTS.md" "$TMP/orphan-trigger.md" >/dev/null || fail 'orphan-trigger refusal changed root instructions'
rm "$PROJECT_THREE/AGENTS.md"

# Root symlinks are refused so managed-prefix merge cannot change their semantics.
printf '# Shared instructions\n' > "$PROJECT_THREE/shared-agents.md"
ln -s shared-agents.md "$PROJECT_THREE/AGENTS.md"
if "$PACKAGE_THREE/scripts/install.sh" merge >/dev/null 2>&1; then
  fail 'merge replaced or followed a root AGENTS.md symlink'
fi
[ -L "$PROJECT_THREE/AGENTS.md" ] || fail 'failed symlink check changed root AGENTS.md'
rm "$PROJECT_THREE/AGENTS.md"

# Invalid UTF-8 and oversized roots fail before the original file is replaced.
printf '\377' > "$PROJECT_THREE/AGENTS.md"
if "$PACKAGE_THREE/scripts/install.sh" merge >/dev/null 2>&1; then
  fail 'invalid UTF-8 merge unexpectedly succeeded'
fi
[ "$(wc -c < "$PROJECT_THREE/AGENTS.md" | tr -d '[:space:]')" -eq 1 ] || fail 'UTF-8 refusal changed original instructions'
rm "$PROJECT_THREE/AGENTS.md"
dd if=/dev/zero bs=16000 count=1 2>/dev/null | tr '\000' x > "$PROJECT_THREE/AGENTS.md"
if "$PACKAGE_THREE/scripts/install.sh" merge >/dev/null 2>&1; then
  fail 'oversized root merge unexpectedly succeeded'
fi
[ "$(wc -c < "$PROJECT_THREE/AGENTS.md" | tr -d '[:space:]')" -eq 16000 ] || fail 'size refusal changed original instructions'

# Updating the package revision marks an existing adaptation stale without adding a trigger.
PROJECT_FOUR="$TMP/version-project"
PACKAGE_FOUR="$PROJECT_FOUR/agent-project-guides"
mkdir -p "$PROJECT_FOUR/.git"
copy_package "$PACKAGE_FOUR"
"$PACKAGE_FOUR/scripts/install.sh" merge >/dev/null
"$PACKAGE_FOUR/scripts/install.sh" set-state --status adapted --verified-at 2026-08-24T14:00:00Z --scope repo --reason none >/dev/null
printf '1.5.0\n' > "$PACKAGE_FOUR/PACKAGE_VERSION"
"$PACKAGE_FOUR/scripts/install.sh" merge >/dev/null
assert_contains "$PROJECT_FOUR/AGENTS.md" 'status=stale; package_revision=1.5.0; verified_at=2026-08-24T14:00:00Z; scope=repo; reason=package_revision_changed'
assert_not_contains "$PROJECT_FOUR/AGENTS.md" '<!-- agent-project-guides:adapter-trigger:start -->'
"$PACKAGE_FOUR/scripts/install.sh" check
"$PACKAGE_FOUR/scripts/install.sh" trigger >/dev/null
assert_contains "$PROJECT_FOUR/AGENTS.md" 'Trigger revision: 1.5.0'
assert_contains "$PROJECT_FOUR/AGENTS.md" 'status=stale; package_revision=1.5.0'
[ "$(grep -Fc '<!-- agent-project-guides:adapter-trigger:start -->' "$PROJECT_FOUR/AGENTS.md")" -eq 1 ] || fail 'version refresh duplicated the trigger'
"$PACKAGE_FOUR/scripts/install.sh" check

# A trigger already active during a package upgrade is refreshed, not dropped or duplicated.
PROJECT_FOUR_ACTIVE="$TMP/version-project-active-trigger"
PACKAGE_FOUR_ACTIVE="$PROJECT_FOUR_ACTIVE/agent-project-guides"
mkdir -p "$PROJECT_FOUR_ACTIVE/.git"
copy_package "$PACKAGE_FOUR_ACTIVE"
"$PACKAGE_FOUR_ACTIVE/scripts/install.sh" trigger >/dev/null
printf '1.5.0\n' > "$PACKAGE_FOUR_ACTIVE/PACKAGE_VERSION"
"$PACKAGE_FOUR_ACTIVE/scripts/install.sh" merge >/dev/null
assert_managed_first "$PROJECT_FOUR_ACTIVE/AGENTS.md"
assert_contains "$PROJECT_FOUR_ACTIVE/AGENTS.md" 'status=stale; package_revision=1.5.0'
assert_contains "$PROJECT_FOUR_ACTIVE/AGENTS.md" 'Trigger revision: 1.5.0'
[ "$(grep -Fc '<!-- agent-project-guides:adapter-trigger:start -->' "$PROJECT_FOUR_ACTIVE/AGENTS.md")" -eq 1 ] || fail 'active trigger upgrade changed trigger cardinality'
"$PACKAGE_FOUR_ACTIVE/scripts/install.sh" check

# Invalid JSONL or unresolved registry paths fail before root instructions change.
PROJECT_FIVE="$TMP/jsonl-project"
PACKAGE_FIVE="$PROJECT_FIVE/agent-project-guides"
mkdir -p "$PROJECT_FIVE/.git"
copy_package "$PACKAGE_FIVE"
printf '{invalid-json}\n' >> "$PACKAGE_FIVE/routing/planes.jsonl"
if "$PACKAGE_FIVE/scripts/install.sh" merge >/dev/null 2>&1; then
  fail 'installer accepted invalid routing JSONL'
fi
[ ! -e "$PROJECT_FIVE/AGENTS.md" ] || fail 'invalid JSONL failure created root instructions'
cp "$ROOT/routing/planes.jsonl" "$PACKAGE_FIVE/routing/planes.jsonl"
printf '{"id":"unknown","when":"x","profile":"profiles/MCP_PROJECT.md"}\n' >> "$PACKAGE_FIVE/routing/project-types.jsonl"
if "$PACKAGE_FIVE/scripts/install.sh" merge >/dev/null 2>&1; then
  fail 'installer accepted an undefined project type'
fi
[ ! -e "$PROJECT_FIVE/AGENTS.md" ] || fail 'undefined project type failure created root instructions'
cp "$ROOT/routing/project-types.jsonl" "$PACKAGE_FIVE/routing/project-types.jsonl"
sed -i 's#profiles/MCP_PROJECT.md#profiles/CLI_PROJECT.md#' "$PACKAGE_FIVE/routing/project-types.jsonl"
if "$PACKAGE_FIVE/scripts/install.sh" merge >/dev/null 2>&1; then
  fail 'installer accepted a mismatched or shared project profile'
fi
[ ! -e "$PROJECT_FIVE/AGENTS.md" ] || fail 'mismatched project profile failure created root instructions'
cp "$ROOT/routing/project-types.jsonl" "$PACKAGE_FIVE/routing/project-types.jsonl"
cp "$ROOT/profiles/MCP_PROJECT.md" "$PACKAGE_FIVE/profiles/MCP_PROJECT.md"
sed -i 's/| Project constraints | required |/| Project constraints | required when used |/' "$PACKAGE_FIVE/profiles/MCP_PROJECT.md"
if "$PACKAGE_FIVE/scripts/install.sh" merge >/dev/null 2>&1; then
  fail 'installer accepted a non-closed artifact preset decision'
fi
[ ! -e "$PROJECT_FIVE/AGENTS.md" ] || fail 'invalid artifact decision failure created root instructions'
cp "$ROOT/profiles/MCP_PROJECT.md" "$PACKAGE_FIVE/profiles/MCP_PROJECT.md"
sed -i 's#profiles/mcp/WINDOWS_WSL_BRIDGE.md#profiles/MCP_PROJECT.md#' "$PACKAGE_FIVE/routing/mcp-subtypes.jsonl"
if "$PACKAGE_FIVE/scripts/install.sh" merge >/dev/null 2>&1; then
  fail 'installer accepted an invalid MCP subtype spec path'
fi
[ ! -e "$PROJECT_FIVE/AGENTS.md" ] || fail 'invalid MCP subtype failure created root instructions'
cp "$ROOT/routing/mcp-subtypes.jsonl" "$PACKAGE_FIVE/routing/mcp-subtypes.jsonl"
sed -i 's/"production operator"/"仓库维护者"/' "$PACKAGE_FIVE/routing/production.roles.jsonl"
if "$PACKAGE_FIVE/scripts/install.sh" merge >/dev/null 2>&1; then
  fail 'installer accepted an ambiguous cross-plane role alias'
fi
[ ! -e "$PROJECT_FIVE/AGENTS.md" ] || fail 'ambiguous alias failure created root instructions'
cp "$ROOT/routing/production.roles.jsonl" "$PACKAGE_FIVE/routing/production.roles.jsonl"
printf '{"repository":"file:///tmp/pkg","version_url":"file:///tmp/version"}\n' > "$PACKAGE_FIVE/PACKAGE_REMOTE.json"
if "$PACKAGE_FIVE/scripts/install.sh" merge >/dev/null 2>&1; then
  fail 'installer accepted untrusted package remote metadata'
fi
[ ! -e "$PROJECT_FIVE/AGENTS.md" ] || fail 'invalid remote metadata failure created root instructions'

printf 'PASS: managed-prefix routing, recoverable CLAUDE scope transactions, exact aliases, project profiles, MCP subtypes, cloud freshness, state lifecycle, and safety guards\n'
