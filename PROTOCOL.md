# Vision Toolkit Windows Edge Protocol v1

This contract binds the WSL host companion to the Windows rendering service.
It is deliberately narrower than MCP: one authenticated screenshot operation,
one request per TCP connection, and no server-side output path.

## Relation to the generalized WIN-WSL MCP template

The project follows the role and transport invariants in
`onshape_docs/guide/win-wsl-bridge-architecture.md`, with one explicit scope
difference: this package is a native DSH companion, not an MCP server. Agents
therefore see the existing DSH `vision_html_screenshot` tool instead of a stdio
MCP facade. If this component is ever exposed as MCP, a standards-compliant WSL
stdio JSON-RPC facade must be added; the private protocol below remains an
implementation detail.

| General template | This companion |
|---|---|
| WSL facade | Host-only Cordis `tools/execute` wrapper using Node built-ins |
| Windows engine | Authenticated listener plus one-shot Playwright/Edge worker |
| Project-selected internal transport | Framed loopback TCP v1 with raw PNG payload |
| Windows owns heavy runtime | Private Windows `.venv`, Playwright, Edge and logs |
| Lazy heavy dependency | Listener imports no Playwright; only the requested worker imports it |
| Windows owns persistent Windows state | No browser profile/session is persisted; all Windows runtime state stays in the deployment |
| WSL owns client artifact state | DSH path fence, PNG validation and atomic Artifact commit remain with DSH |
| Development/deployment split | Source and offline checks in WSL; copied runtime under `C:\MCP` |

## Ownership

| Side | Owns | Must not own |
|---|---|---|
| WSL | DSH `tools/execute` companion, source/output path fence, token copy, framing, PNG validation, staging and atomic artifact commit | Playwright, Chromium, Edge profile/session, Windows logs or `.venv` |
| Windows | loopback listener, private `.venv`, `pythonw.exe` task, UNC source validation, short-lived Playwright/Edge worker | DSH artifact path, WSL output writes, public listener, persistent Edge/profile |

The WSL source tree contains only development sources and standard-library
helpers. Runtime `.venv`, `token`, `config.json`, and `logs/` live only in the
Windows deployment at `C:\MCP\dsh-vision-toolkit-windows-edge`.

## Transport

- IPv4 TCP `127.0.0.1:8767` only; WSL2 mirrored networking supplies loopback.
- One request per connection; the listener closes the connection after response.
- First 4 bytes: unsigned big-endian JSON header length.
- JSON header maximum: 16 KiB, UTF-8, protocol field `v: 1`.
- Authentication: shared random 256-bit token, compared with constant-time HMAC comparison.
- Success response: framed JSON header followed immediately by exactly `bytes`
  raw PNG bytes; maximum PNG size 64 MiB.
- Failure response: framed JSON header only.

## Screenshot request

```json
{
  "v": 1,
  "op": "screenshot",
  "token": "<shared-token>",
  "source": "\\\\wsl.localhost\\<distro>\\...\\page.html",
  "viewport": { "width": 1280, "height": 800, "scale": 1 },
  "fullPage": false,
  "waitMs": 0,
  "timeoutMs": 30000,
  "maxPixels": 20000000,
  "maxSourceBytes": 4194304
}
```

The listener rejects unknown fields. No request may contain an output path,
command line, Edge arguments, provider credential, URL, or browser profile.

## Success response

```json
{
  "v": 1,
  "ok": true,
  "mime": "image/png",
  "bytes": 24852,
  "sha256": "<lowercase-hex>",
  "width": 640,
  "height": 360,
  "browser": "msedge",
  "browserVersion": "151.0.4129.93"
}
```

A full-page response also includes positive integer `pageHeight`. WSL rejects a
wrong protocol version, renderer, media type, byte count, SHA-256, PNG signature,
IHDR dimensions, requested viewport dimensions, or pixel limit before committing
the artifact.

## Errors

Stable error codes are `AUTH`, `BUSY`, `TIMEOUT`, `INVALID_REQUEST`, and
`RENDER`. Errors contain no token, provider secret, source contents, or stack
trace. A busy listener rejects immediately rather than queueing a second Edge.

## Browser boundary

Each request starts a fresh offline Playwright context with installed Microsoft
Edge (`channel="msedge"`). HTTP, HTTPS, WebSocket, service workers, and downloads
are blocked. `file://` subresources must remain within configured canonical
`\\wsl.localhost\...` roots; `data:`, `blob:`, and `about:` are the only other
schemes allowed. A hard timeout kills the worker and Edge process tree.

## Deployment handoff

1. Modify and syntax-test the WSL source tree.
2. Run `install.sh`; it synchronizes every existing supported DSH profile, stops the old task/listener, and copies Windows sources.
3. `setup-runtime.ps1` creates/updates the plugin-owned Windows `.venv` without
   downloading a browser.
4. `register-task.ps1` registers `DshVisionToolkitWindowsEdge` with its private
   `pythonw.exe`, current-user logon, restart-on-failure, and hidden launch.
5. Verify loopback listener, wrong-token rejection, fixed viewport, full page,
   PNG integrity, and DSH Artifact projection.
