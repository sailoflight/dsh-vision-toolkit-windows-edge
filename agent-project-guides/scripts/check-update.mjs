#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const simpleRevision = /^[A-Za-z0-9._-]+$/;

function revision(value, source) {
  const result = value.replace(/[\r\n]/g, '');
  if (!simpleRevision.test(result)) throw new Error(`${source} is not a simple revision token`);
  return result;
}

function readRemote() {
  const value = JSON.parse(fs.readFileSync(path.join(packageRoot, 'PACKAGE_REMOTE.json'), 'utf8'));
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('PACKAGE_REMOTE.json must contain one object');
  if (typeof value.repository !== 'string' || !value.repository.startsWith('https://github.com/')) throw new Error('invalid repository URL');
  if (typeof value.api_path !== 'string' || !value.api_path.startsWith('repos/') || value.api_path.includes('..')) throw new Error('invalid GitHub API path');
  if (typeof value.version_url !== 'string' || !value.version_url.startsWith('https://raw.githubusercontent.com/')) throw new Error('invalid raw version URL');
  return value;
}

async function fetchText(url, headers = {}) {
  const response = await fetch(url, {
    redirect: 'follow',
    signal: AbortSignal.timeout(10000),
    headers: { 'user-agent': 'agent-project-guides-version-check', ...headers },
  });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  return response.text();
}

async function probe(remote) {
  const override = process.env.AGENT_PROJECT_GUIDES_VERSION_URL;
  if (override) return { value: await fetchText(override), transport: 'environment_override', source: override };

  const errors = [];
  const token = process.env.GH_TOKEN || process.env.GITHUB_TOKEN;
  if (token) {
    const url = `https://api.github.com/${remote.api_path}`;
    try {
      const payload = JSON.parse(await fetchText(url, { authorization: `Bearer ${token}`, accept: 'application/vnd.github+json' }));
      if (payload.encoding !== 'base64' || typeof payload.content !== 'string') throw new Error('GitHub content response lacks base64 content');
      return { value: Buffer.from(payload.content.replace(/\s/g, ''), 'base64').toString('utf8'), transport: 'github_token', source: url };
    } catch (error) {
      errors.push(`token: ${error.message}`);
    }
  }

  try {
    const encoded = execFileSync('gh', ['api', remote.api_path, '--jq', '.content'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      timeout: 10000,
    });
    return { value: Buffer.from(encoded.replace(/\s/g, ''), 'base64').toString('utf8'), transport: 'gh', source: remote.api_path };
  } catch (error) {
    errors.push(`gh: ${error.message}`);
  }

  try {
    return { value: await fetchText(remote.version_url), transport: 'anonymous_raw', source: remote.version_url };
  } catch (error) {
    errors.push(`raw: ${error.message}`);
  }
  throw new Error(errors.join('; '));
}

function report(value) {
  process.stdout.write(`${JSON.stringify(value)}\n`);
}

let localRevision;
let remote;
try {
  localRevision = revision(fs.readFileSync(path.join(packageRoot, 'PACKAGE_VERSION'), 'utf8'), 'PACKAGE_VERSION');
  remote = readRemote();
} catch (error) {
  report({ status: 'unavailable', reason: 'invalid_local_metadata', detail: error.message });
  process.exit(0);
}

try {
  const result = await probe(remote);
  const remoteRevision = revision(result.value, 'remote version');
  report({
    status: remoteRevision === localRevision ? 'current' : 'remote_differs',
    local_revision: localRevision,
    remote_revision: remoteRevision,
    repository: remote.repository,
    transport: result.transport,
    source: result.source,
  });
} catch (error) {
  report({
    status: 'unavailable',
    local_revision: localRevision,
    repository: remote.repository,
    reason: 'remote_probe_failed',
    detail: error.message,
  });
}
