#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const files = {
  planes: 'routing/planes.jsonl',
  production: 'routing/production.roles.jsonl',
  development: 'routing/development.roles.jsonl',
  projectTypes: 'routing/project-types.jsonl',
  mcpSubtypes: 'routing/mcp-subtypes.jsonl',
};

function fail(message) {
  console.error(`error: ${message}`);
  process.exit(1);
}

function safePath(relativePath, field) {
  if (typeof relativePath !== 'string' || !relativePath || path.isAbsolute(relativePath) || relativePath.split('/').includes('..')) {
    fail(`${field} must be a safe package-relative path`);
  }
  const absolute = path.resolve(packageRoot, relativePath);
  const stat = fs.lstatSync(absolute, { throwIfNoEntry: false });
  if (!absolute.startsWith(`${packageRoot}${path.sep}`) || !stat?.isFile() || stat.isSymbolicLink()) {
    fail(`${field} does not resolve to a package file: ${relativePath}`);
  }
}

function readJsonl(relativePath) {
  const absolute = path.join(packageRoot, relativePath);
  if (!fs.statSync(absolute, { throwIfNoEntry: false })?.isFile()) fail(`missing registry: ${relativePath}`);
  return fs.readFileSync(absolute, 'utf8').split(/\r?\n/).filter(Boolean).map((line, index) => {
    try {
      const value = JSON.parse(line);
      if (!value || Array.isArray(value) || typeof value !== 'object') throw new Error('record is not an object');
      return value;
    } catch (error) {
      fail(`${relativePath}:${index + 1}: ${error.message}`);
    }
  });
}

const planes = readJsonl(files.planes);
const production = readJsonl(files.production);
const development = readJsonl(files.development);
const projectTypes = readJsonl(files.projectTypes);
const mcpSubtypes = readJsonl(files.mcpSubtypes);

const expectedPlanes = new Map([['production', files.production], ['development', files.development]]);
if (planes.length !== expectedPlanes.size) fail('planes registry must contain exactly production and development');
for (const record of planes) {
  if (!expectedPlanes.has(record.id) || record.roles !== expectedPlanes.get(record.id) || typeof record.when !== 'string') {
    fail(`invalid plane record: ${JSON.stringify(record)}`);
  }
  safePath(record.roles, `plane ${record.id}.roles`);
}

const expectedRoles = new Set(['user', 'operator', 'developer', 'maintainer', 'reviewer', 'field-evaluator']);
const seen = new Set();
const roleLabels = new Map();
for (const [plane, records] of [['production', production], ['development', development]]) {
  for (const record of records) {
    if (!expectedRoles.has(record.id) || seen.has(record.id)) fail(`invalid or duplicate role id: ${record.id}`);
    seen.add(record.id);
    if (record.plane !== plane || typeof record.when !== 'string' || !Array.isArray(record.aliases) || record.aliases.length === 0 || !Array.isArray(record.modes) || record.modes.length === 0) {
      fail(`invalid role record: ${JSON.stringify(record)}`);
    }
    for (const label of [record.id, ...record.aliases]) {
      if (typeof label !== 'string' || !label.trim()) fail(`role ${record.id} has an invalid alias`);
      const key = label.trim().toLocaleLowerCase('und');
      if (roleLabels.has(key)) fail(`duplicate or ambiguous role label: ${label}`);
      roleLabels.set(key, record.id);
    }
    if (new Set(record.modes).size !== record.modes.length) fail(`duplicate modes for role: ${record.id}`);
    if (typeof record.guide !== 'string' || !record.guide.startsWith(`roles/${plane}/`)) fail(`role ${record.id} guide is outside its plane directory`);
    safePath(record.guide, `role ${record.id}.guide`);
    for (const [mode, procedure] of Object.entries(record.procedure_by_mode || {})) {
      if (!record.modes.includes(mode)) fail(`procedure references unknown mode ${record.id}.${mode}`);
      if (typeof procedure !== 'string' || !procedure.startsWith('procedures/')) fail(`procedure is outside procedures/: ${procedure}`);
      safePath(procedure, `role ${record.id}.${mode}.procedure`);
    }
  }
}
if (seen.size !== expectedRoles.size) fail(`missing role ids: ${[...expectedRoles].filter(id => !seen.has(id)).join(', ')}`);
for (const alias of ['实战评估者', '实战探索者', '探索评估者']) {
  if (roleLabels.get(alias) !== 'field-evaluator') fail(`required field-evaluator alias is missing or ambiguous: ${alias}`);
}

const expectedProjectTypes = new Map([
  ['mcp', 'profiles/MCP_PROJECT.md'],
  ['library', 'profiles/LIBRARY_PROJECT.md'],
  ['cli', 'profiles/CLI_PROJECT.md'],
  ['service', 'profiles/SERVICE_PROJECT.md'],
  ['application-ui', 'profiles/APPLICATION_UI_PROJECT.md'],
  ['data-automation', 'profiles/DATA_AUTOMATION_PROJECT.md'],
  ['monorepo', 'profiles/MONOREPO_PROJECT.md'],
]);
if (projectTypes.length !== expectedProjectTypes.size) fail('project-types registry must contain exactly the supported project types');
const seenProjectTypes = new Set();
const seenProfiles = new Set();
for (const record of projectTypes) {
  if (!expectedProjectTypes.has(record.id) || seenProjectTypes.has(record.id)) fail(`invalid or duplicate project type id: ${record.id}`);
  if (typeof record.when !== 'string' || !record.when.trim() || record.profile !== expectedProjectTypes.get(record.id)) {
    fail(`invalid project type record: ${JSON.stringify(record)}`);
  }
  if (seenProfiles.has(record.profile)) fail(`project types must not share a profile: ${record.profile}`);
  safePath(record.profile, `project type ${record.id}.profile`);
  seenProjectTypes.add(record.id);
  seenProfiles.add(record.profile);
}

if (mcpSubtypes.length !== 1) fail('MCP subtype registry must contain exactly the supported subtype');
const mcpSubtype = mcpSubtypes[0];
if (mcpSubtype.id !== 'windows-wsl-bridge' || typeof mcpSubtype.when !== 'string' || !mcpSubtype.when.trim() ||
    mcpSubtype.spec !== 'profiles/mcp/WINDOWS_WSL_BRIDGE.md') {
  fail(`invalid MCP subtype record: ${JSON.stringify(mcpSubtype)}`);
}
safePath(mcpSubtype.spec, `MCP subtype ${mcpSubtype.id}.spec`);
const mcpSubtypeText = fs.readFileSync(path.join(packageRoot, mcpSubtype.spec), 'utf8');
for (const marker of [
  '## 2. 角色与职责（核心契约）',
  '## 4. 双生产角色运行时提示（强制）',
  '## 5. 运行时提示的权威和投递路径',
  '## 8. 项目实例映射（必填）',
  '## 9. 验收检查清单（通用）',
]) {
  if (!mcpSubtypeText.includes(marker)) fail(`MCP subtype spec is missing contract marker: ${marker}`);
}

const profileHeadings = [
  '## 1. Selection boundary',
  '## 2. Artifact preset',
  '## 3. Evidence map',
  '## 5. Verification preset',
  '## 6. Cold-start acceptance',
];
for (const record of projectTypes) {
  const profileText = fs.readFileSync(path.join(packageRoot, record.profile), 'utf8');
  for (const heading of profileHeadings) {
    if (!profileText.includes(heading)) fail(`project profile ${record.profile} is missing contract heading: ${heading}`);
  }
  const presetSection = profileText.split('## 2. Artifact preset')[1]?.split('## 3. Evidence map')[0] || '';
  const presetRows = presetSection.split(/\r?\n/).filter(line => /^\|[^-].*\|$/.test(line.trim())).slice(1);
  if (presetRows.length === 0) fail(`project profile has no artifact preset rows: ${record.profile}`);
  for (const row of presetRows) {
    const cells = row.split('|').slice(1, -1).map(cell => cell.trim());
    if (!['required', 'conditional', 'omit', 'existing-authority'].includes(cells[1])) {
      fail(`project profile ${record.profile} has invalid artifact decision: ${cells[1] || '<missing>'}`);
    }
  }
  const templateRefs = [...profileText.matchAll(/`(templates\/[A-Z_]+\.md)`/g)].map(match => match[1]);
  if (templateRefs.length === 0) fail(`project profile does not reference an artifact template: ${record.profile}`);
  for (const templateRef of new Set(templateRefs)) safePath(templateRef, `project profile ${record.id}.template`);
}

const templateContracts = new Map([
  ['templates/ROOT_AGENTS.md', '## Repository map'],
  ['templates/DOC_INDEX.md', '## Current authorities'],
  ['templates/DEVELOPMENT_START.md', '## Supported environments'],
  ['templates/ARCHITECTURE_OVERVIEW.md', '## Trust and side-effect boundaries'],
  ['templates/MODULE_CONTRACT.md', '## Public surface and entrypoints'],
  ['templates/VERIFICATION_MATRIX.md', '## Command authorities'],
  ['templates/USER_USAGE.md', '## Supported workflows'],
  ['templates/OPERATOR_RUNBOOK.md', '## Change and rollback plan'],
  ['templates/FIELD_EVALUATION.md', '## Traceability'],
  ['templates/ADR.md', '## Validation and reversal'],
  ['templates/SUBAGENT_ASSIGNMENT.md', 'Authority/contract:'],
]);
for (const [templatePath, contractMarker] of templateContracts) {
  safePath(templatePath, `artifact template ${templatePath}`);
  if (!fs.readFileSync(path.join(packageRoot, templatePath), 'utf8').includes(contractMarker)) {
    fail(`artifact template ${templatePath} is missing contract marker: ${contractMarker}`);
  }
}
for (const obsolete of ['profiles/LIBRARY_AND_CLI_PROJECT.md', 'profiles/APPLICATION_SERVICE_MONOREPO.md']) {
  if (fs.existsSync(path.join(packageRoot, obsolete))) fail(`obsolete combined profile remains: ${obsolete}`);
}

const remoteFile = path.join(packageRoot, 'PACKAGE_REMOTE.json');
let remote;
try {
  remote = JSON.parse(fs.readFileSync(remoteFile, 'utf8'));
} catch (error) {
  fail(`invalid PACKAGE_REMOTE.json: ${error.message}`);
}
if (!remote || Array.isArray(remote) || typeof remote !== 'object' ||
    typeof remote.repository !== 'string' || !remote.repository.startsWith('https://github.com/') ||
    typeof remote.api_path !== 'string' || !remote.api_path.startsWith('repos/') || remote.api_path.includes('..') ||
    typeof remote.version_url !== 'string' || !remote.version_url.startsWith('https://raw.githubusercontent.com/')) {
  fail('PACKAGE_REMOTE.json must contain trusted repository and version_url fields');
}

console.log('Routing JSONL, MCP subtype specifications, and package remote metadata are valid.');
