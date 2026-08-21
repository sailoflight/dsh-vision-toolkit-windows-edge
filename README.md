# dsh-vision-toolkit-windows-edge

Host-only companion for `@anionex/dsh-vision-toolkit` on DSH running inside WSL.
It keeps the public `vision_html_screenshot` tool contract but renders local HTML
with the Windows-installed Microsoft Edge through an authenticated loopback bridge.

## Architecture

The exact two-sided wire and ownership contract is documented in [`PROTOCOL.md`](./PROTOCOL.md). It instantiates the generalized WIN-WSL role boundaries while remaining a native DSH companion rather than an MCP server.

```text
DSH / WSL tools/execute wrapper
  -> framed TCP 127.0.0.1:8767 + shared token
  -> Windows Task Scheduler listener
  -> one short-lived Windows Playwright worker
  -> chromium.launch(channel="msedge")
  -> PNG bytes + dimensions + SHA-256
  -> WSL random stage, validation, atomic artifact commit
```

The listener persists; Edge does not. Every call gets a new browser and context.
HTTP/HTTPS/WebSocket requests are blocked. Only `file://` resources inside the
configured WSL UNC roots plus data/blob/about resources are allowed.

## Install

```bash
bash install.sh
```

The installer copies the host plugin into each existing `web`, `dsh-tui`, and
`headless` profile, deploys one shared Windows bridge under
`C:\MCP\dsh-vision-toolkit-windows-edge`, creates a shared 256-bit token, and
registers a current-user `DshVisionToolkitWindowsEdge` login task. Vision Toolkit
must be installed in each profile; Web-only UI integrations remain scoped to Web. It creates and owns `C:\MCP\dsh-vision-toolkit-windows-edge\.venv`, installs only the pinned Playwright client there, and uses installed Edge through `channel="msedge"`; it does not download another browser. The scheduled task and immediate launcher both use this venv’s windowless `pythonw.exe`.

Restart any active DSH hosts after installation; on-demand profiles pick up the change at their next start. Windows and WSL must use mirrored networking,
as already required by the adjacent MCP bridges on ports 8765 and 8766.
