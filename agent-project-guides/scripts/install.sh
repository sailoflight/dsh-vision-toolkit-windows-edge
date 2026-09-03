#!/bin/sh
set -eu

ROUTING_START='<!-- agent-project-guides:routing:start -->'
ROUTING_END='<!-- agent-project-guides:routing:end -->'
TRIGGER_START='<!-- agent-project-guides:adapter-trigger:start -->'
TRIGGER_END='<!-- agent-project-guides:adapter-trigger:end -->'
CLAUDE_SCOPE_START='<!-- agent-project-guides:claude-scope:start -->'
CLAUDE_SCOPE_END='<!-- agent-project-guides:claude-scope:end -->'
LEGACY_HANDOFF='<!-- agent-project-guides:handoff:start -->'
STATE_PREFIX='Package adaptation:'
MAX_ROOT_BYTES=16384
RESERVED_MANAGED_BYTES=4096

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: scripts/install.sh <command> [--target DIR] [--sync-claude-scope]

Commands:
  merge           Scheme 1: place the permanent routing/state block first in the selected root instructions; never invokes an LLM.
  trigger         Scheme 2: ensure routing is first, then place one temporary package-adaptation trigger before project content.
  check           Validate routing position, adaptation state, optional trigger/scope block, UTF-8, and root size.
  check-update    Compare local PACKAGE_VERSION with the configured cloud source; never modifies files.
  set-state       Adapter submodes update status with --status, --verified-at, --scope, and --reason.
  remove-trigger  Remove the temporary trigger after adaptation reaches status=adapted.
  unmerge         Remove managed routing and any optional sibling CLAUDE scope after trigger removal.

When --target is omitted, the script walks upward from the package parent to the nearest .git marker.
Root selection is deterministic: AGENTS.md first, then a small CLAUDE.md; an oversized CLAUDE.md gets a new short AGENTS.md while remaining untouched.
With merge/trigger/check, --sync-claude-scope optionally prepends a small role-scope declaration to a sibling CLAUDE.md when AGENTS.md is selected.
EOF
}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
PACKAGE_DIR=$(dirname -- "$SCRIPT_DIR")
COMMAND=${1:-}
[ -n "$COMMAND" ] || {
  usage
  exit 2
}
case "$COMMAND" in
  -h|--help|help)
    usage
    exit 0
    ;;
esac
shift

TARGET=''
STATE_ARG=''
VERIFIED_AT_ARG=''
SCOPE_ARG=''
REASON_ARG=''
SYNC_CLAUDE_SCOPE=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --target)
      [ "$#" -ge 2 ] || fail '--target requires a directory'
      TARGET=$2
      shift 2
      ;;
    --status)
      [ "$#" -ge 2 ] || fail '--status requires a value'
      STATE_ARG=$2
      shift 2
      ;;
    --verified-at)
      [ "$#" -ge 2 ] || fail '--verified-at requires a value'
      VERIFIED_AT_ARG=$2
      shift 2
      ;;
    --scope)
      [ "$#" -ge 2 ] || fail '--scope requires a value'
      SCOPE_ARG=$2
      shift 2
      ;;
    --reason)
      [ "$#" -ge 2 ] || fail '--reason requires a value'
      REASON_ARG=$2
      shift 2
      ;;
    --sync-claude-scope)
      SYNC_CLAUDE_SCOPE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

if [ "$SYNC_CLAUDE_SCOPE" -eq 1 ]; then
  case "$COMMAND" in merge|trigger|check) ;; *) fail '--sync-claude-scope is supported only by merge, trigger, and check' ;; esac
fi

find_target_root() {
  current=$(dirname -- "$PACKAGE_DIR")
  while :; do
    if [ -e "$current/.git" ]; then
      printf '%s\n' "$current"
      return 0
    fi
    parent=$(dirname -- "$current")
    [ "$parent" != "$current" ] || return 1
    current=$parent
  done
}

if [ -n "$TARGET" ]; then
  [ -d "$TARGET" ] || fail "target directory does not exist: $TARGET"
  TARGET=$(CDPATH= cd -- "$TARGET" && pwd -P)
else
  TARGET=$(find_target_root) || fail 'no target project root found; pass --target DIR'
fi

case "$PACKAGE_DIR" in
  "$TARGET"/*) GUIDES_PATH=${PACKAGE_DIR#"$TARGET"/} ;;
  *) fail 'the package must be located inside the target project' ;;
esac

ROUTING_TEMPLATE="$PACKAGE_DIR/bootstrap/AGENTS.routing-block.md"
TRIGGER_TEMPLATE="$PACKAGE_DIR/bootstrap/AGENTS.adapter-trigger.md"
CLAUDE_SCOPE_TEMPLATE="$PACKAGE_DIR/bootstrap/CLAUDE.scope-block.md"
BLOCK_HELPER="$PACKAGE_DIR/scripts/manage-root-blocks.mjs"
VERSION_FILE="$PACKAGE_DIR/PACKAGE_VERSION"
ROUTING_VALIDATOR="$PACKAGE_DIR/scripts/validate-routing.mjs"
UPDATE_CHECKER="$PACKAGE_DIR/scripts/check-update.mjs"
REMOTE_FILE="$PACKAGE_DIR/PACKAGE_REMOTE.json"
TRANSACTION_FILE="$TARGET/.agent-project-guides.transaction"

select_root_instructions() {
  agents="$TARGET/AGENTS.md"
  claude="$TARGET/CLAUDE.md"
  CLAUDE_FILE=$claude
  ROOT_NAME=AGENTS.md
  ROOT_FILE=$agents

  if [ -e "$agents" ] || [ -L "$agents" ]; then
    return
  fi
  if [ ! -e "$claude" ] && [ ! -L "$claude" ]; then
    return
  fi

  ROOT_NAME=CLAUDE.md
  ROOT_FILE=$claude
  if [ -f "$claude" ] && [ ! -L "$claude" ]; then
    if grep -Fq "$ROUTING_START" "$claude" || grep -Fq "$TRIGGER_START" "$claude"; then
      return
    fi
    claude_bytes=$(wc -c < "$claude" | tr -d '[:space:]')
    if [ "$claude_bytes" -gt $((MAX_ROOT_BYTES - RESERVED_MANAGED_BYTES)) ]; then
      ROOT_NAME=AGENTS.md
      ROOT_FILE=$agents
    fi
  fi
}

select_root_instructions

[ -f "$ROUTING_TEMPLATE" ] || fail "missing template: $ROUTING_TEMPLATE"
[ -f "$TRIGGER_TEMPLATE" ] || fail "missing template: $TRIGGER_TEMPLATE"
[ -f "$CLAUDE_SCOPE_TEMPLATE" ] || fail "missing template: $CLAUDE_SCOPE_TEMPLATE"
[ -f "$BLOCK_HELPER" ] || fail "missing block helper: $BLOCK_HELPER"
[ -f "$VERSION_FILE" ] || fail "missing package version: $VERSION_FILE"
[ -f "$ROUTING_VALIDATOR" ] || fail "missing routing validator: $ROUTING_VALIDATOR"
[ -f "$UPDATE_CHECKER" ] || fail "missing update checker: $UPDATE_CHECKER"
[ -f "$REMOTE_FILE" ] || fail "missing package remote metadata: $REMOTE_FILE"
command -v node >/dev/null 2>&1 || fail 'node is required to validate routing JSONL'
node "$ROUTING_VALIDATOR" >/dev/null || fail 'routing JSONL validation failed'
for required_path in \
  templates/ROOT_AGENTS.md \
  templates/DOC_INDEX.md \
  templates/DEVELOPMENT_START.md \
  templates/ARCHITECTURE_OVERVIEW.md \
  templates/MODULE_CONTRACT.md \
  templates/VERIFICATION_MATRIX.md \
  templates/USER_USAGE.md \
  templates/OPERATOR_RUNBOOK.md \
  templates/FIELD_EVALUATION.md \
  templates/ADR.md \
  templates/SUBAGENT_ASSIGNMENT.md
do
  [ -f "$PACKAGE_DIR/$required_path" ] || fail "missing package entry: $PACKAGE_DIR/$required_path"
done

PACKAGE_REVISION=$(tr -d '\r\n' < "$VERSION_FILE")
case "$PACKAGE_REVISION" in
  ''|*[!A-Za-z0-9._-]*) fail 'PACKAGE_VERSION must contain one simple revision token' ;;
esac
PACKAGE_REPOSITORY=$(node -e "const fs=require('fs'); const value=JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); process.stdout.write(value.repository)" "$REMOTE_FILE")

escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[\\&|]/\\&/g'
}

render_common() {
  template=$1
  status=$2
  verified_at=$3
  scope=$4
  reason=$5
  guides=$(escape_sed_replacement "$GUIDES_PATH")
  revision=$(escape_sed_replacement "$PACKAGE_REVISION")
  status_value=$(escape_sed_replacement "$status")
  verified=$(escape_sed_replacement "$verified_at")
  scope_value=$(escape_sed_replacement "$scope")
  reason_value=$(escape_sed_replacement "$reason")
  repository=$(escape_sed_replacement "$PACKAGE_REPOSITORY")
  sed \
    -e "s|{{GUIDES_PATH}}|$guides|g" \
    -e "s|{{PACKAGE_REVISION}}|$revision|g" \
    -e "s|{{ADAPTATION_STATUS}}|$status_value|g" \
    -e "s|{{VERIFIED_AT}}|$verified|g" \
    -e "s|{{ADAPTATION_SCOPE}}|$scope_value|g" \
    -e "s|{{ROOT_INSTRUCTIONS}}|$ROOT_NAME|g" \
    -e "s|{{PACKAGE_REPOSITORY}}|$repository|g" \
    -e "s|{{ADAPTATION_REASON}}|$reason_value|g" \
    "$template"
}

count_marker() {
  marker=$1
  file=$2
  if [ ! -f "$file" ]; then
    printf '0\n'
    return
  fi
  count=$(grep -Fc "$marker" "$file" 2>/dev/null || true)
  printf '%s\n' "${count:-0}"
}

transaction_mode() {
  if [ ! -e "$TRANSACTION_FILE" ] && [ ! -L "$TRANSACTION_FILE" ]; then
    printf 'none\n'
    return 0
  fi
  [ -f "$TRANSACTION_FILE" ] && [ ! -L "$TRANSACTION_FILE" ] || fail 'installation transaction marker is not a regular file'
  transaction_value=$(tr -d '\r\n' < "$TRANSACTION_FILE")
  case "$transaction_value" in sync-claude-scope|unmerge) printf '%s\n' "$transaction_value" ;; *) fail 'installation transaction marker has invalid content' ;; esac
}

assert_no_transaction() {
  active_transaction=$(transaction_mode)
  [ "$active_transaction" = none ] || fail "incomplete $active_transaction transaction; run its matching recovery command"
}

begin_transaction() (
  requested_transaction=$1
  active_transaction=$(transaction_mode)
  if [ "$active_transaction" = "$requested_transaction" ]; then
    printf 'Recovering incomplete %s transaction.\n' "$requested_transaction"
    return 0
  fi
  [ "$active_transaction" = none ] || fail "cannot start $requested_transaction while $active_transaction recovery is required"
  transaction_tmp=$(mktemp "$TARGET/.agent-project-guides.transaction.XXXXXX")
  trap 'rm -f "$transaction_tmp"' EXIT HUP INT TERM
  printf '%s\n' "$requested_transaction" > "$transaction_tmp"
  chmod 0600 "$transaction_tmp"
  mv -f -- "$transaction_tmp" "$TRANSACTION_FILE"
  trap - EXIT HUP INT TERM
)

finish_transaction() {
  expected_transaction=$1
  [ "$(transaction_mode)" = "$expected_transaction" ] || fail "cannot finish missing $expected_transaction transaction"
  rm -f -- "$TRANSACTION_FILE"
}

root_has() {
  marker=$1
  [ -f "$ROOT_FILE" ] && grep -Fq "$marker" "$ROOT_FILE"
}

reject_conflicting_managed_roots() {
  for sibling_name in AGENTS.md CLAUDE.md AGENTS.local.md CLAUDE.local.md; do
    [ "$sibling_name" = "$ROOT_NAME" ] && continue
    sibling="$TARGET/$sibling_name"
    if [ -f "$sibling" ] && {
      grep -Fq "$ROUTING_START" "$sibling" || grep -Fq "$TRIGGER_START" "$sibling"
    }; then
      fail "$sibling_name contains package-managed markers but $ROOT_NAME is the selected root; reconcile duplicate installations"
    fi
  done
}

validate_text_file() {
  file=$1
  command -v iconv >/dev/null 2>&1 || fail 'iconv is required to validate UTF-8 instruction files'
  iconv -f UTF-8 -t UTF-8 "$file" >/dev/null 2>&1 || fail "$file is not valid UTF-8"
  bytes=$(wc -c < "$file" | tr -d '[:space:]')
  [ "$bytes" -le "$MAX_ROOT_BYTES" ] || fail "$file exceeds the $MAX_ROOT_BYTES-byte root instruction cap"
}

is_utc_timestamp() {
  printf '%s\n' "$1" | grep -Eq '^[0-9]{4}-(0[1-9]|1[0-2])-([0-2][0-9]|3[01])T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]Z$'
}

state_line() {
  sed -n "/$ROUTING_START/,/$ROUTING_END/{
    /^$STATE_PREFIX/p
  }" "$ROOT_FILE"
}

state_field() {
  field=$1
  line=$(state_line)
  printf '%s\n' "$line" | sed -n "s/.*$field=\([^;]*\).*/\1/p"
}

validate_routing() {
  [ -f "$ROOT_FILE" ] || fail "selected root $ROOT_NAME does not exist"
  [ "$(count_marker "$ROUTING_START" "$ROOT_FILE")" -eq 1 ] || fail 'routing start marker must appear exactly once'
  [ "$(count_marker "$ROUTING_END" "$ROOT_FILE")" -eq 1 ] || fail 'routing end marker must appear exactly once'
  [ "$(sed -n '1p' "$ROOT_FILE")" = "$ROUTING_START" ] || fail 'routing block must begin at byte 0 of the selected root instructions'

  managed=$(sed -n "/$ROUTING_START/,/$ROUTING_END/p" "$ROOT_FILE")
  ! printf '%s\n' "$managed" | grep -Fq '{{' || fail 'routing block contains unresolved placeholders'
  printf '%s\n' "$managed" | grep -Fq "$GUIDES_PATH/routing/planes.jsonl" || fail 'routing block points to a different plane registry'
  printf '%s\n' "$managed" | grep -Fq "$GUIDES_PATH/routing/*.roles.jsonl" || fail 'routing block points to a different role registry pattern'

  [ "$(printf '%s\n' "$managed" | grep -Fc "$STATE_PREFIX")" -eq 1 ] || fail 'adaptation state line must appear exactly once inside routing block'
  status=$(state_field status)
  revision=$(state_field package_revision)
  verified_at=$(state_field verified_at)
  scope=$(state_field scope)
  reason=$(state_field reason)

  case "$status" in pending|partial|adapted|stale|blocked) ;; *) fail "invalid adaptation status: $status" ;; esac
  [ "$revision" = "$PACKAGE_REVISION" ] || fail "routing revision $revision differs from package revision $PACKAGE_REVISION"
  if [ "$verified_at" = never ]; then
    case "$status" in adapted|partial) fail "$status status requires a real verified_at timestamp" ;; esac
  elif ! is_utc_timestamp "$verified_at"; then
    fail "verified_at must be never or ISO-8601 UTC: $verified_at"
  fi
  [ -n "$scope" ] || fail 'adaptation scope cannot be empty'
  [ -n "$reason" ] || fail 'adaptation reason cannot be empty'
  case "$scope" in *';'*) fail 'adaptation scope cannot contain semicolons' ;; esac
  case "$reason" in *';'*) fail 'adaptation reason cannot contain semicolons' ;; esac
  [ "$status" != adapted ] || [ "$reason" = none ] || fail 'adapted status requires reason=none'
  [ "$status" != partial ] || [ "$reason" != none ] || fail 'partial status requires a concrete reason code'
  [ "$status" != blocked ] || [ "$reason" != none ] || fail 'blocked status requires a concrete reason code'
}

validate_trigger() {
  start_count=$(count_marker "$TRIGGER_START" "$ROOT_FILE")
  end_count=$(count_marker "$TRIGGER_END" "$ROOT_FILE")
  [ "$start_count" -eq "$end_count" ] || fail 'adapter trigger markers are unbalanced'
  [ "$start_count" -le 1 ] || fail 'adapter trigger must appear at most once'
  if [ "$start_count" -eq 1 ]; then
    routing_end_line=$(grep -nF "$ROUTING_END" "$ROOT_FILE" | cut -d: -f1)
    trigger_start_line=$(grep -nF "$TRIGGER_START" "$ROOT_FILE" | cut -d: -f1)
    [ "$trigger_start_line" -eq $((routing_end_line + 1)) ] || fail 'adapter trigger must immediately follow the routing block'
    trigger=$(sed -n "/$TRIGGER_START/,/$TRIGGER_END/p" "$ROOT_FILE")
    ! printf '%s\n' "$trigger" | grep -Fq '{{' || fail 'adapter trigger contains unresolved placeholders'
    printf '%s\n' "$trigger" | grep -Fq "$GUIDES_PATH/routing/development.roles.jsonl" || fail 'adapter trigger points to a different development registry'
    printf '%s\n' "$trigger" | grep -Fq "Trigger revision: $PACKAGE_REVISION" || fail 'adapter trigger targets a different package revision'
    printf '%s\n' "$trigger" | grep -Fq "$PACKAGE_REPOSITORY" || fail 'adapter trigger points to a different package repository'
  fi
}

validate_claude_scope_template() {
  validate_text_file "$CLAUDE_SCOPE_TEMPLATE"
  [ "$(wc -c < "$CLAUDE_SCOPE_TEMPLATE" | tr -d '[:space:]')" -le 500 ] || fail 'CLAUDE scope template exceeds the 500-byte budget'
  [ "$(count_marker "$CLAUDE_SCOPE_START" "$CLAUDE_SCOPE_TEMPLATE")" -eq 1 ] || fail 'CLAUDE scope template start marker must appear exactly once'
  [ "$(count_marker "$CLAUDE_SCOPE_END" "$CLAUDE_SCOPE_TEMPLATE")" -eq 1 ] || fail 'CLAUDE scope template end marker must appear exactly once'
  [ "$(sed -n '1p' "$CLAUDE_SCOPE_TEMPLATE")" = "$CLAUDE_SCOPE_START" ] || fail 'CLAUDE scope template must start with its managed marker'
  [ "$(tail -n 1 "$CLAUDE_SCOPE_TEMPLATE")" = "$CLAUDE_SCOPE_END" ] || fail 'CLAUDE scope template must end with its managed marker'
  ! grep -Fq '{{' "$CLAUDE_SCOPE_TEMPLATE" || fail 'CLAUDE scope template contains unresolved placeholders'
  grep -Fq 'resolve plane/role/mode' "$CLAUDE_SCOPE_TEMPLATE" || fail 'CLAUDE scope template is missing the generic role gate'
}

validate_claude_scope() {
  start_count=$(count_marker "$CLAUDE_SCOPE_START" "$CLAUDE_FILE")
  end_count=$(count_marker "$CLAUDE_SCOPE_END" "$CLAUDE_FILE")
  [ "$start_count" -eq "$end_count" ] || fail 'CLAUDE scope markers are unbalanced'
  [ "$start_count" -le 1 ] || fail 'CLAUDE scope block must appear at most once'
  if [ "$start_count" -eq 1 ]; then
    [ "$ROOT_NAME" = AGENTS.md ] || fail 'CLAUDE scope block is valid only beside a selected AGENTS.md root'
    [ -f "$CLAUDE_FILE" ] && [ ! -L "$CLAUDE_FILE" ] || fail 'CLAUDE scope target must be a regular non-symlink file'
    validate_text_file "$CLAUDE_FILE"
    [ "$(sed -n '1p' "$CLAUDE_FILE")" = "$CLAUDE_SCOPE_START" ] || fail 'CLAUDE scope block must begin at byte 0'
    scope_block=$(sed -n "/$CLAUDE_SCOPE_START/,/$CLAUDE_SCOPE_END/p" "$CLAUDE_FILE")
    ! printf '%s\n' "$scope_block" | grep -Fq '{{' || fail 'CLAUDE scope block contains unresolved placeholders'
    printf '%s\n' "$scope_block" | grep -Fq 'resolve plane/role/mode' || fail 'CLAUDE scope block is not the package role gate'
  fi
}

build_claude_scope_file() (
  output=$1
  unmanaged=$(mktemp "$TARGET/.agent-project-guides.claude.unmanaged.XXXXXX")
  trap 'rm -f "$unmanaged" "$output"' EXIT HUP INT TERM
  node "$BLOCK_HELPER" strip "$CLAUDE_FILE" "$unmanaged" "$CLAUDE_SCOPE_START" "$CLAUDE_SCOPE_END"
  cat -- "$CLAUDE_SCOPE_TEMPLATE" > "$output"
  cat -- "$unmanaged" >> "$output"
  chmod --reference="$CLAUDE_FILE" "$output" 2>/dev/null || chmod 0644 "$output"
  rm -f "$unmanaged"
  trap - EXIT HUP INT TERM
)

preflight_claude_scope() {
  validate_claude_scope_template
  validate_claude_scope
  [ "$SYNC_CLAUDE_SCOPE" -eq 1 ] || return 0
  [ "$ROOT_NAME" = AGENTS.md ] || fail '--sync-claude-scope requires AGENTS.md to be the selected root'
  [ -e "$CLAUDE_FILE" ] || fail '--sync-claude-scope requires a sibling CLAUDE.md'
  [ ! -L "$CLAUDE_FILE" ] || fail 'sibling CLAUDE.md is a symlink; reconcile it explicitly before scope sync'
  [ -f "$CLAUDE_FILE" ] || fail 'sibling CLAUDE.md is not a regular file'
  validate_text_file "$CLAUDE_FILE"
  preview=$(mktemp "$TARGET/.agent-project-guides.claude.preview.XXXXXX")
  build_claude_scope_file "$preview"
  trap 'rm -f "$preview"' EXIT HUP INT TERM
  validate_text_file "$preview"
  rm -f "$preview"
  trap - EXIT HUP INT TERM
}

sync_claude_scope() {
  [ "$SYNC_CLAUDE_SCOPE" -eq 1 ] || return 0
  tmp=$(mktemp "$TARGET/.agent-project-guides.claude.merge.XXXXXX")
  build_claude_scope_file "$tmp"
  trap 'rm -f "$tmp"' EXIT HUP INT TERM
  validate_text_file "$tmp"
  mv -f -- "$tmp" "$CLAUDE_FILE"
  trap - EXIT HUP INT TERM
  validate_claude_scope
  printf 'Synchronized role-scope gate to sibling CLAUDE.md.\n'
}

rebuild_root_prefix() (
  routing_file=$1
  trigger_file=${2:-}
  unmanaged=$(mktemp "$TARGET/.agent-project-guides.md.unmanaged.XXXXXX")
  tmp=$(mktemp "$TARGET/.agent-project-guides.md.merge.XXXXXX")
  trap 'rm -f "$unmanaged" "$tmp"' EXIT HUP INT TERM

  if [ -e "$ROOT_FILE" ] || [ -L "$ROOT_FILE" ]; then
    [ ! -L "$ROOT_FILE" ] || fail "selected root $ROOT_NAME is a symlink; reconcile it explicitly before managed-prefix merge"
    [ -f "$ROOT_FILE" ] || fail "selected root $ROOT_NAME exists but is not a regular file"
    validate_text_file "$ROOT_FILE"
    node "$BLOCK_HELPER" strip "$ROOT_FILE" "$unmanaged" \
      "$ROUTING_START" "$ROUTING_END" "$TRIGGER_START" "$TRIGGER_END"
    chmod --reference="$ROOT_FILE" "$tmp" 2>/dev/null || chmod 0644 "$tmp"
  else
    : > "$unmanaged"
    chmod 0644 "$tmp"
  fi

  cat -- "$routing_file" > "$tmp"
  [ -z "$trigger_file" ] || cat -- "$trigger_file" >> "$tmp"
  cat -- "$unmanaged" >> "$tmp"
  validate_text_file "$tmp"
  mv -f -- "$tmp" "$ROOT_FILE"
  rm -f "$unmanaged"
  trap - EXIT HUP INT TERM
)

replace_marked_block() (
  start=$1
  end=$2
  replacement_file=$3
  tmp=$(mktemp "$TARGET/.agent-project-guides.md.replace.XXXXXX")
  trap 'rm -f "$tmp"' EXIT HUP INT TERM
  validate_text_file "$ROOT_FILE"
  node "$BLOCK_HELPER" replace "$ROOT_FILE" "$tmp" "$start" "$end" "$replacement_file"
  chmod --reference="$ROOT_FILE" "$tmp" 2>/dev/null || chmod 0644 "$tmp"
  validate_text_file "$tmp"
  mv -f -- "$tmp" "$ROOT_FILE"
  trap - EXIT HUP INT TERM
)

rewrite_state() {
  next_status=$1
  next_verified=$2
  next_scope=$3
  next_reason=$4
  block=$(mktemp "$TARGET/.agent-project-guides.routing.state.XXXXXX")
  trap 'rm -f "$block"' EXIT HUP INT TERM
  render_common "$ROUTING_TEMPLATE" "$next_status" "$next_verified" "$next_scope" "$next_reason" > "$block"
  replace_marked_block "$ROUTING_START" "$ROUTING_END" "$block"
  rm -f "$block"
  trap - EXIT HUP INT TERM
}

refresh_routing_for_revision() {
  old_verified=$(state_field verified_at)
  old_scope=$(state_field scope)
  block=$(mktemp "$TARGET/.agent-project-guides.routing.refresh.XXXXXX")
  trap 'rm -f "$block"' EXIT HUP INT TERM
  render_common "$ROUTING_TEMPLATE" stale "$old_verified" "$old_scope" package_revision_changed > "$block"
  replace_marked_block "$ROUTING_START" "$ROUTING_END" "$block"
  rm -f "$block"
  trap - EXIT HUP INT TERM
}

refresh_existing_trigger_for_revision() {
  [ "$(count_marker "$TRIGGER_START" "$ROOT_FILE")" -eq 1 ] || return 0
  [ "$(count_marker "$TRIGGER_END" "$ROOT_FILE")" -eq 1 ] || fail 'adapter trigger markers are unbalanced'
  existing_trigger=$(sed -n "/$TRIGGER_START/,/$TRIGGER_END/p" "$ROOT_FILE")
  printf '%s\n' "$existing_trigger" | grep -Fq "Trigger revision: $PACKAGE_REVISION" && return 0
  trigger_refresh_block=$(mktemp "$TARGET/.agent-project-guides.trigger.refresh.XXXXXX")
  trap 'rm -f "$trigger_refresh_block"' EXIT HUP INT TERM
  render_common "$TRIGGER_TEMPLATE" pending never repo trigger_requested > "$trigger_refresh_block"
  replace_marked_block "$TRIGGER_START" "$TRIGGER_END" "$trigger_refresh_block"
  rm -f "$trigger_refresh_block"
  trap - EXIT HUP INT TERM
  printf 'Refreshed existing trigger for package revision %s.\n' "$PACKAGE_REVISION"
}

canonicalize_root_prefix() {
  routing_block=$(mktemp "$TARGET/.agent-project-guides.routing.current.XXXXXX")
  trigger_block=''
  trap 'rm -f "$routing_block"; [ -z "$trigger_block" ] || rm -f "$trigger_block"' EXIT HUP INT TERM
  sed -n "/$ROUTING_START/,/$ROUTING_END/p" "$ROOT_FILE" > "$routing_block"
  if [ "$(count_marker "$TRIGGER_START" "$ROOT_FILE")" -eq 1 ]; then
    [ "$(count_marker "$TRIGGER_END" "$ROOT_FILE")" -eq 1 ] || fail 'adapter trigger markers are unbalanced'
    trigger_block=$(mktemp "$TARGET/.agent-project-guides.trigger.current.XXXXXX")
    sed -n "/$TRIGGER_START/,/$TRIGGER_END/p" "$ROOT_FILE" > "$trigger_block"
  fi
  rebuild_root_prefix "$routing_block" "$trigger_block"
  rm -f "$routing_block"
  [ -z "$trigger_block" ] || rm -f "$trigger_block"
  trap - EXIT HUP INT TERM
}

validate_existing_root_markers() {
  existing_routing_start=$(count_marker "$ROUTING_START" "$ROOT_FILE")
  existing_routing_end=$(count_marker "$ROUTING_END" "$ROOT_FILE")
  existing_trigger_start=$(count_marker "$TRIGGER_START" "$ROOT_FILE")
  existing_trigger_end=$(count_marker "$TRIGGER_END" "$ROOT_FILE")
  [ "$existing_routing_start" -eq "$existing_routing_end" ] || fail 'existing routing markers are unbalanced'
  [ "$existing_routing_start" -le 1 ] || fail 'multiple routing blocks already exist'
  [ "$existing_trigger_start" -eq "$existing_trigger_end" ] || fail 'existing adapter trigger markers are unbalanced'
  [ "$existing_trigger_start" -le 1 ] || fail 'multiple adapter triggers already exist'
  [ "$existing_trigger_start" -eq 0 ] || [ "$existing_routing_start" -eq 1 ] || fail 'adapter trigger exists without permanent routing'
}

merge_routing() {
  reject_conflicting_managed_roots
  validate_existing_root_markers
  if [ "$SYNC_CLAUDE_SCOPE" -eq 1 ]; then
    case "$(transaction_mode)" in none|sync-claude-scope) ;; *) fail 'another installation transaction requires recovery first' ;; esac
  else
    assert_no_transaction
  fi
  preflight_claude_scope
  [ "$SYNC_CLAUDE_SCOPE" -ne 1 ] || begin_transaction sync-claude-scope
  [ ! -L "$ROOT_FILE" ] || fail "selected root $ROOT_NAME is a symlink; reconcile it explicitly before managed-prefix merge"
  if root_has "$LEGACY_HANDOFF"; then
    fail 'legacy root-replacement handoff is present; restore it before using the managed-prefix installer'
  fi

  routing_count=$(count_marker "$ROUTING_START" "$ROOT_FILE")
  [ "$routing_count" -le 1 ] || fail 'multiple routing blocks already exist'
  if [ "$routing_count" -eq 1 ]; then
    [ "$(count_marker "$ROUTING_END" "$ROOT_FILE")" -eq 1 ] || fail 'routing markers are unbalanced'
    installed_revision=$(state_field package_revision)
    if [ "$installed_revision" != "$PACKAGE_REVISION" ]; then
      refresh_routing_for_revision
      printf 'Marked existing adaptation stale for package revision %s.\n' "$PACKAGE_REVISION"
    else
      printf 'Permanent routing block already installed.\n'
    fi
    refresh_existing_trigger_for_revision
    canonicalize_root_prefix
    sync_claude_scope
    validate_text_file "$ROOT_FILE"
    validate_routing
    validate_trigger
    [ "$SYNC_CLAUDE_SCOPE" -ne 1 ] || finish_transaction sync-claude-scope
    return
  fi

  block=$(mktemp "$TARGET/.agent-project-guides.routing.XXXXXX")
  trap 'rm -f "$block"' EXIT HUP INT TERM
  render_common "$ROUTING_TEMPLATE" pending never repo not_adapted > "$block"
  rebuild_root_prefix "$block" ''
  rm -f "$block"
  trap - EXIT HUP INT TERM
  sync_claude_scope
  validate_routing
  [ "$SYNC_CLAUDE_SCOPE" -ne 1 ] || finish_transaction sync-claude-scope
  printf 'Placed permanent routing first with adaptation status pending.\n'
}

append_trigger() {
  merge_routing
  trigger_count=$(count_marker "$TRIGGER_START" "$ROOT_FILE")
  [ "$trigger_count" -le 1 ] || fail 'multiple adapter triggers already exist'
  if [ "$trigger_count" -eq 1 ]; then
    existing_trigger=$(sed -n "/$TRIGGER_START/,/$TRIGGER_END/p" "$ROOT_FILE")
    if ! printf '%s\n' "$existing_trigger" | grep -Fq "Trigger revision: $PACKAGE_REVISION"; then
      block=$(mktemp "$TARGET/.agent-project-guides.trigger.refresh.XXXXXX")
      trap 'rm -f "$block"' EXIT HUP INT TERM
      render_common "$TRIGGER_TEMPLATE" pending never repo trigger_requested > "$block"
      replace_marked_block "$TRIGGER_START" "$TRIGGER_END" "$block"
      rm -f "$block"
      trap - EXIT HUP INT TERM
      printf 'Refreshed existing trigger for package revision %s.\n' "$PACKAGE_REVISION"
    fi
    validate_trigger
    existing_status=$(state_field status)
    if [ "$existing_status" = adapted ]; then
      printf 'Adaptation is complete; existing trigger only needs remove-trigger cleanup.\n'
    elif [ "$existing_status" = blocked ]; then
      rewrite_state pending never "$(state_field scope)" retry_requested
      validate_routing
      printf 'Reset blocked adaptation to pending for an explicit retry.\n'
    else
      printf 'Package adaptation trigger already installed.\n'
    fi
    return
  fi

  current_status=$(state_field status)
  current_scope=$(state_field scope)
  case "$current_status" in
    adapted)
      rewrite_state stale "$(state_field verified_at)" "$current_scope" explicit_readaptation
      ;;
    blocked)
      rewrite_state pending never "$current_scope" retry_requested
      ;;
  esac

  block=$(mktemp "$TARGET/.agent-project-guides.trigger.XXXXXX")
  routing_block=$(mktemp "$TARGET/.agent-project-guides.routing.current.XXXXXX")
  trap 'rm -f "$block" "$routing_block"' EXIT HUP INT TERM
  render_common "$TRIGGER_TEMPLATE" pending never repo trigger_requested > "$block"
  sed -n "/$ROUTING_START/,/$ROUTING_END/p" "$ROOT_FILE" > "$routing_block"
  rebuild_root_prefix "$routing_block" "$block"
  rm -f "$block" "$routing_block"
  trap - EXIT HUP INT TERM
  validate_trigger
  printf 'Placed one-time package-adaptation trigger before project content.\n'
}

remove_marked_block_from_file() (
  remove_target=$1
  remove_start=$2
  remove_end=$3
  remove_tmp=$(mktemp "$TARGET/.agent-project-guides.md.remove.XXXXXX")
  trap 'rm -f "$remove_tmp"' EXIT HUP INT TERM
  validate_text_file "$remove_target"
  node "$BLOCK_HELPER" strip "$remove_target" "$remove_tmp" "$remove_start" "$remove_end"
  chmod --reference="$remove_target" "$remove_tmp" 2>/dev/null || chmod 0644 "$remove_tmp"
  validate_text_file "$remove_tmp"
  mv -f -- "$remove_tmp" "$remove_target"
  trap - EXIT HUP INT TERM
)

remove_marked_block() {
  start=$1
  end=$2
  remove_marked_block_from_file "$ROOT_FILE" "$start" "$end"
}

set_adaptation_state() {
  assert_no_transaction
  validate_routing
  [ -n "$STATE_ARG" ] || fail 'set-state requires --status'
  [ -n "$VERIFIED_AT_ARG" ] || fail 'set-state requires --verified-at'
  [ -n "$SCOPE_ARG" ] || fail 'set-state requires --scope'
  [ -n "$REASON_ARG" ] || fail 'set-state requires --reason'
  case "$SCOPE_ARG" in *[!A-Za-z0-9._/,:=-]*) fail 'scope must be a compact path/token list without spaces or semicolons' ;; esac
  case "$REASON_ARG" in *[!A-Za-z0-9._:-]*) fail 'reason must be a compact non-secret code' ;; esac

  case "$STATE_ARG" in
    adapted)
      is_utc_timestamp "$VERIFIED_AT_ARG" || fail 'adapted requires an ISO-8601 UTC verified-at timestamp'
      [ "$REASON_ARG" = none ] || fail 'adapted requires --reason none'
      ;;
    partial)
      is_utc_timestamp "$VERIFIED_AT_ARG" || fail 'partial requires an ISO-8601 UTC verified-at timestamp'
      [ "$REASON_ARG" != none ] || fail 'partial requires a concrete reason code'
      ;;
    blocked)
      if [ "$VERIFIED_AT_ARG" != never ] && ! is_utc_timestamp "$VERIFIED_AT_ARG"; then
        fail 'blocked verified-at must be never or ISO-8601 UTC'
      fi
      [ "$REASON_ARG" != none ] || fail 'blocked requires a concrete reason code'
      ;;
    *) fail 'set-state accepts only adapted, partial, or blocked' ;;
  esac

  rewrite_state "$STATE_ARG" "$VERIFIED_AT_ARG" "$SCOPE_ARG" "$REASON_ARG"
  validate_routing
  printf 'Updated package adaptation state to %s.\n' "$STATE_ARG"
}

remove_trigger() {
  assert_no_transaction
  validate_routing
  [ "$(count_marker "$TRIGGER_START" "$ROOT_FILE")" -eq 1 ] || fail 'exactly one adapter trigger is required for removal'
  [ "$(count_marker "$TRIGGER_END" "$ROOT_FILE")" -eq 1 ] || fail 'adapter trigger markers are unbalanced'
  [ "$(state_field status)" = adapted ] || fail 'adapter trigger can be removed only after status=adapted'
  remove_marked_block "$TRIGGER_START" "$TRIGGER_END"
  [ "$(count_marker "$TRIGGER_START" "$ROOT_FILE")" -eq 0 ] || fail 'adapter trigger removal failed'
  validate_routing
  printf 'Removed one-time package-adaptation trigger; permanent routing remains.\n'
}

unmerge_routing() {
  [ -f "$ROOT_FILE" ] || fail "selected root $ROOT_NAME does not exist"
  active_transaction=$(transaction_mode)
  case "$active_transaction" in none|unmerge) ;; *) fail "incomplete $active_transaction transaction must be recovered before unmerge" ;; esac
  validate_claude_scope
  trigger_start_count=$(count_marker "$TRIGGER_START" "$ROOT_FILE")
  trigger_end_count=$(count_marker "$TRIGGER_END" "$ROOT_FILE")
  [ "$trigger_start_count" -eq "$trigger_end_count" ] || fail 'adapter trigger markers are unbalanced'
  [ "$trigger_start_count" -eq 0 ] || fail 'remove the adapter trigger before unmerging routing'
  routing_start_count=$(count_marker "$ROUTING_START" "$ROOT_FILE")
  routing_end_count=$(count_marker "$ROUTING_END" "$ROOT_FILE")
  [ "$routing_start_count" -eq "$routing_end_count" ] || fail 'routing markers are unbalanced'
  [ "$routing_start_count" -le 1 ] || fail 'multiple routing blocks prevent unmerge'
  if [ "$active_transaction" = none ]; then
    [ "$routing_start_count" -eq 1 ] || fail 'exactly one routing block is required for unmerge'
  fi
  begin_transaction unmerge
  if [ "$(count_marker "$CLAUDE_SCOPE_START" "$CLAUDE_FILE")" -eq 1 ]; then
    remove_marked_block_from_file "$CLAUDE_FILE" "$CLAUDE_SCOPE_START" "$CLAUDE_SCOPE_END"
  fi
  [ "$routing_start_count" -eq 0 ] || remove_marked_block "$ROUTING_START" "$ROUTING_END"
  finish_transaction unmerge
  printf 'Removed managed routing and optional CLAUDE scope; original instruction content remains.\n'
}

check_package_update() {
  node "$UPDATE_CHECKER"
}

check_installation() {
  assert_no_transaction
  reject_conflicting_managed_roots
  [ -f "$ROOT_FILE" ] || fail "selected root $ROOT_NAME does not exist"
  validate_text_file "$ROOT_FILE"
  validate_routing
  validate_trigger
  validate_claude_scope_template
  validate_claude_scope
  if [ "$SYNC_CLAUDE_SCOPE" -eq 1 ]; then
    [ "$ROOT_NAME" = AGENTS.md ] && [ -f "$CLAUDE_FILE" ] || fail '--sync-claude-scope check requires AGENTS.md plus sibling CLAUDE.md'
    [ "$(count_marker "$CLAUDE_SCOPE_START" "$CLAUDE_FILE")" -eq 1 ] || fail 'sibling CLAUDE.md is missing the requested scope block'
  fi
  printf 'Routing, adaptation state, and optional CLAUDE scope are valid.\n'
}

case "$COMMAND" in
  merge) merge_routing ;;
  trigger) append_trigger ;;
  check) check_installation ;;
  check-update) check_package_update ;;
  set-state) set_adaptation_state ;;
  remove-trigger) remove_trigger ;;
  unmerge) unmerge_routing ;;
  *) usage >&2; fail "unknown command: $COMMAND" ;;
esac
