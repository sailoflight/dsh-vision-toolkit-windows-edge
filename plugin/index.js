import { createHash, randomUUID } from 'node:crypto';
import {
  lstat,
  mkdir,
  open,
  readFile,
  realpath,
  rename,
  rm,
  stat,
} from 'node:fs/promises';
import { createConnection } from 'node:net';
import { homedir, tmpdir } from 'node:os';
import {
  basename,
  extname,
  isAbsolute,
  join,
  relative,
  resolve,
  sep,
} from 'node:path';

export const name = 'vision-toolkit-windows-edge';
export const inject = ['tools'];

const TARGET = 'vision_html_screenshot';
const DEFAULT_PORT = 8767;
const MAX_HEADER_BYTES = 16 * 1024;
const MAX_PNG_BYTES = 64 * 1024 * 1024;
const PNG_SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

function integerInRange(value, fallback, minimum, maximum, label) {
  const resolved = value === undefined ? fallback : value;
  if (!Number.isSafeInteger(resolved) || resolved < minimum || resolved > maximum) {
    throw new TypeError(`${label} must be an integer from ${minimum} through ${maximum}`);
  }
  return resolved;
}

function expandHome(path) {
  if (path === '~') return homedir();
  if (path.startsWith('~/')) return join(homedir(), path.slice(2));
  return path;
}

function isWithin(parent, child) {
  const rel = relative(parent, child);
  return rel === '' || (rel !== '..' && !rel.startsWith(`..${sep}`) && !isAbsolute(rel));
}

async function pathPolicy(workspaceRaw, allowedDirs) {
  const workspace = await realpath(expandHome(workspaceRaw));
  const tempDir = await realpath(tmpdir());
  const roots = [workspace, tempDir];
  for (const raw of allowedDirs) {
    const expanded = expandHome(raw);
    roots.push(await realpath(isAbsolute(expanded) ? expanded : resolve(workspace, expanded)));
  }
  const outputRaw = join(workspace, '.dsh-vision-toolkit', 'artifacts');
  if (!roots.some(root => isWithin(root, outputRaw))) {
    throw new Error('artifact directory escapes the configured roots');
  }
  await mkdir(outputRaw, { recursive: true });
  const outputDir = await realpath(outputRaw);
  return { workspace, roots: [...new Set(roots)], outputDir };
}

async function resolveSource(raw, policy) {
  if (typeof raw !== 'string' || raw.trim().length === 0) {
    throw new TypeError('vision_html_screenshot.source must be a local HTML path');
  }
  const expanded = expandHome(raw.trim());
  const candidate = isAbsolute(expanded) ? expanded : resolve(policy.workspace, expanded);
  const source = await realpath(candidate).catch(() => {
    throw new Error(`HTML source not found: ${raw}`);
  });
  if (!policy.roots.some(root => isWithin(root, source))) {
    throw new Error(`HTML source escapes the allowed directories: ${raw}`);
  }
  const info = await stat(source);
  if (!info.isFile()) throw new Error(`HTML source is not a regular file: ${raw}`);
  if (!['.html', '.htm'].includes(extname(source).toLowerCase())) {
    throw new Error('HTML source must use .html or .htm');
  }
  return { path: source, bytes: info.size };
}

function resolveOutput(raw, policy, defaultName) {
  const name = raw === undefined || raw.trim().length === 0 ? defaultName : raw.trim();
  if (isAbsolute(name) || name.includes('/') || name.includes('\\') || name === '.' || name === '..') {
    throw new Error('output must be one filename inside the artifact directory');
  }
  if (extname(name).toLowerCase() !== '.png') throw new Error('output must use .png');
  const target = resolve(policy.outputDir, name);
  if (!isWithin(policy.outputDir, target)) throw new Error('output escapes the artifact directory');
  return target;
}

function toWindowsPath(path) {
  const drive = /^\/mnt\/([a-zA-Z])(?:\/(.*))?$/u.exec(path);
  if (drive !== null) {
    return `${drive[1].toUpperCase()}:\\${(drive[2] ?? '').replaceAll('/', '\\')}`;
  }
  const distro = process.env.WSL_DISTRO_NAME?.trim();
  if (!distro) throw new Error('WSL_DISTRO_NAME is unavailable');
  return `\\\\wsl.localhost\\${distro}${path.replaceAll('/', '\\')}`;
}

function pngDimensions(bytes) {
  if (bytes.length < 24 || !bytes.subarray(0, 8).equals(PNG_SIGNATURE)) {
    throw new Error('Windows Edge bridge returned invalid PNG bytes');
  }
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
}

async function bridgeRequest(request, signal, timeoutMs, port) {
  const encoded = Buffer.from(JSON.stringify(request));
  if (encoded.length > MAX_HEADER_BYTES) throw new Error('Windows Edge bridge request is too large');
  const frame = Buffer.allocUnsafe(4 + encoded.length);
  frame.writeUInt32BE(encoded.length, 0);
  encoded.copy(frame, 4);

  return new Promise((resolvePromise, reject) => {
    const socket = createConnection({ host: '127.0.0.1', port });
    let buffer = Buffer.alloc(0);
    let header;
    let total;
    let settled = false;

    const finish = (error, value) => {
      if (settled) return;
      settled = true;
      signal.removeEventListener('abort', abort);
      socket.destroy();
      if (error === undefined) resolvePromise(value);
      else reject(error);
    };
    const abort = () => finish(signal.reason instanceof Error ? signal.reason : new Error('Windows Edge screenshot cancelled'));
    if (signal.aborted) return abort();
    signal.addEventListener('abort', abort, { once: true });
    socket.setTimeout(timeoutMs + 5000, () => finish(new Error(`Windows Edge bridge timed out after ${timeoutMs} ms`)));
    socket.once('error', error => finish(new Error(`Windows Edge bridge connection failed: ${error.message}`)));
    socket.once('connect', () => socket.write(frame));
    socket.on('data', chunk => {
      buffer = Buffer.concat([buffer, chunk]);
      if (buffer.length > 4 + MAX_HEADER_BYTES + MAX_PNG_BYTES) {
        finish(new Error('Windows Edge bridge response exceeds 64 MiB'));
        return;
      }
      if (header === undefined && buffer.length >= 4) {
        const size = buffer.readUInt32BE(0);
        if (size <= 0 || size > MAX_HEADER_BYTES) {
          finish(new Error('Windows Edge bridge returned an invalid header length'));
          return;
        }
        if (buffer.length < 4 + size) return;
        try {
          header = JSON.parse(buffer.subarray(4, 4 + size).toString('utf8'));
        } catch {
          finish(new Error('Windows Edge bridge returned invalid JSON'));
          return;
        }
        if (!header || typeof header !== 'object') {
          finish(new Error('Windows Edge bridge returned an invalid header'));
          return;
        }
        if (header.v !== 1) {
          finish(new Error('Windows Edge bridge protocol version mismatch'));
          return;
        }
        if (header.ok !== true) {
          const code = header.error?.code ?? 'BRIDGE';
          const message = header.error?.message ?? 'Windows Edge bridge rejected the request';
          finish(new Error(`${code}: ${message}`));
          return;
        }
        if (header.mime !== 'image/png' || header.browser !== 'msedge') {
          finish(new Error('Windows Edge bridge returned an unexpected renderer or media type'));
          return;
        }
        if (!Number.isSafeInteger(header.bytes) || header.bytes < 0 || header.bytes > MAX_PNG_BYTES) {
          finish(new Error('Windows Edge bridge returned an invalid PNG length'));
          return;
        }
        total = 4 + size + header.bytes;
      }
      if (total !== undefined && buffer.length >= total) {
        if (buffer.length !== total) {
          finish(new Error('Windows Edge bridge returned trailing bytes'));
          return;
        }
        const size = buffer.readUInt32BE(0);
        finish(undefined, { header, png: buffer.subarray(4 + size) });
      }
    });
    socket.once('end', () => {
      if (!settled) finish(new Error('Windows Edge bridge closed before completing the response'));
    });
  });
}

async function writeStaged(path, bytes) {
  const handle = await open(path, 'wx', 0o600);
  try {
    await handle.writeFile(bytes);
    await handle.sync();
  } finally {
    await handle.close();
  }
  const info = await lstat(path);
  if (!info.isFile() || info.isSymbolicLink()) throw new Error('staged screenshot is not a regular file');
}

async function capture(config, args, exec) {
  const width = integerInRange(args.width, 1280, 1, 8192, 'vision_html_screenshot.width');
  const height = integerInRange(args.height, 800, 1, 8192, 'vision_html_screenshot.height');
  const scale = integerInRange(args.scale, 1, 1, 4, 'vision_html_screenshot.scale');
  const waitMs = integerInRange(args.waitMs, 0, 0, 120000, 'vision_html_screenshot.waitMs');
  const timeoutMs = integerInRange(args.timeoutMs, config.timeoutMs ?? 30000, 1000, 600000, 'vision_html_screenshot.timeoutMs');
  const maxImageBytes = integerInRange(config.maxImageBytes, 4194304, 1, 268435456, 'config.maxImageBytes');
  const maxImagePixels = integerInRange(config.maxImagePixels, 20000000, 1, 268435456, 'config.maxImagePixels');
  const fullPage = args.fullPage === true;
  if (width * height * scale * scale > maxImagePixels) throw new Error('requested viewport exceeds maxImagePixels');

  const workspace = exec.agent?.session.header.cwd ?? process.cwd();
  const policy = await pathPolicy(workspace, Array.isArray(config.allowedDirs) ? config.allowedDirs : []);
  const source = await resolveSource(args.source, policy);
  if (source.bytes > maxImageBytes) throw new Error(`HTML source exceeds maxImageBytes ${maxImageBytes}`);
  const stem = basename(source.path, extname(source.path));
  const finalPath = resolveOutput(args.output, policy, `${stem}.screenshot.png`);
  if (source.path === finalPath) throw new Error('output would overwrite the HTML source');
  const staged = join(policy.outputDir, `.vision-toolkit-${randomUUID()}.png`);

  try {
    const token = (await readFile(expandHome(config.tokenFile ?? '~/.dsh/vision-toolkit-windows-edge/token'), 'utf8')).trim();
    if (token.length < 32) throw new Error('Windows Edge bridge token is missing or invalid');
    const { header, png } = await bridgeRequest({
      v: 1,
      op: 'screenshot',
      token,
      source: toWindowsPath(source.path),
      viewport: { width, height, scale },
      fullPage,
      waitMs,
      timeoutMs,
      maxPixels: maxImagePixels,
      maxSourceBytes: maxImageBytes,
    }, exec.signal, timeoutMs, config.port ?? DEFAULT_PORT);

    const digest = createHash('sha256').update(png).digest('hex');
    if (digest !== header.sha256) throw new Error('Windows Edge bridge PNG hash mismatch');
    const dimensions = pngDimensions(png);
    if (dimensions.width !== header.width || dimensions.height !== header.height) {
      throw new Error('Windows Edge bridge PNG dimensions do not match its header');
    }
    const expectedWidth = width * scale;
    const pageHeight = fullPage ? header.pageHeight : undefined;
    if (fullPage && (!Number.isSafeInteger(pageHeight) || pageHeight <= 0)) {
      throw new Error('Windows Edge bridge returned an invalid pageHeight');
    }
    const expectedHeight = (pageHeight ?? height) * scale;
    if (dimensions.width !== expectedWidth || dimensions.height !== expectedHeight) {
      throw new Error(`Windows Edge screenshot dimensions ${dimensions.width}x${dimensions.height} do not match ${expectedWidth}x${expectedHeight}`);
    }
    if (dimensions.width * dimensions.height > maxImagePixels) throw new Error('Windows Edge screenshot exceeds maxImagePixels');

    await writeStaged(staged, png);
    await rename(staged, finalPath);
    const artifactInfo = await stat(finalPath);
    return {
      sourcePath: source.path,
      sourceBytes: source.bytes,
      viewport: { width, height, scale },
      width: dimensions.width,
      height: dimensions.height,
      ...(pageHeight === undefined ? {} : { pageHeight }),
      artifact: {
        path: finalPath,
        filename: basename(finalPath),
        mimeType: 'image/png',
        kind: 'image',
        description: 'Windows Edge screenshot of local HTML',
        sourceTool: TARGET,
        previewIntent: 'image',
        bytes: artifactInfo.size,
      },
    };
  } finally {
    await rm(staged, { force: true }).catch(() => {});
  }
}

export function apply(ctx, config = {}) {
  ctx.on('tools/execute', async (exec, next) => {
    if (exec.name !== TARGET || ctx.tools.get(TARGET, exec.agent) === undefined) return next();
    const value = await capture(config, exec.arguments, exec);
    return { isError: false, value, content: [] };
  });
}
