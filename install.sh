#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB="$HOME/.dsh/profiles/web"
PLUGIN="$WEB/plugins/vision-toolkit-windows-edge"
OLD_PLUGIN="$WEB/plugins/wsl-edge-bridge"
STATE="$HOME/.dsh/vision-toolkit-windows-edge"
OLD_STATE="$HOME/.dsh/wsl-edge-bridge"
WIN="/mnt/c/MCP/dsh-vision-toolkit-windows-edge"
OLD_WIN="/mnt/c/MCP/dsh-wsl-edge-bridge"
PORT=8767
PS='/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'

[ -d "$WEB" ] || { echo "missing Web profile: $WEB" >&2; exit 1; }
[ -n "${WSL_DISTRO_NAME:-}" ] || { echo "WSL_DISTRO_NAME is not set" >&2; exit 1; }
[ -x "$PS" ] || { echo "Windows PowerShell is unavailable" >&2; exit 1; }

echo "stage: stop old runtime"
"$PS" -NoProfile -Command '
  foreach($name in @("DshWslEdgeBridge", "DshVisionToolkitWindowsEdge")) {
    Stop-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if(Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue) {
      Unregister-ScheduledTask -TaskName $name -Confirm:$false
    }
  }
  $c=Get-NetTCPConnection -LocalPort 8767 -State Listen -ErrorAction SilentlyContinue
  if($c){Stop-Process -Id $c.OwningProcess -Force}
  exit 0
'

echo "stage: migrate deployment"
if [ ! -d "$WIN" ] && [ -d "$OLD_WIN" ]; then mv "$OLD_WIN" "$WIN"; fi
if [ ! -d "$STATE" ] && [ -d "$OLD_STATE" ]; then mv "$OLD_STATE" "$STATE"; fi
mkdir -p "$PLUGIN" "$STATE" "$WIN/logs"

token=''
for candidate in "$WIN/token" "$STATE/token" "$OLD_WIN/token" "$OLD_STATE/token"; do
  if [ -s "$candidate" ]; then token="$(tr -d '\r\n' < "$candidate")"; break; fi
done
if [ -z "$token" ]; then
  token="$(node -e "process.stdout.write(require('node:crypto').randomBytes(32).toString('base64url'))")"
fi

rm -rf "$OLD_PLUGIN" "$OLD_STATE"
[ "$OLD_WIN" = "$WIN" ] || rm -rf "$OLD_WIN"
cp -R "$SRC/plugin/." "$PLUGIN/"
cp "$SRC/windows/bridge_server.py" \
   "$SRC/windows/render_worker.py" \
   "$SRC/windows/start-bridge.ps1" \
   "$SRC/windows/register-task.ps1" \
   "$SRC/windows/setup-runtime.ps1" \
   "$SRC/windows/requirements-browser.txt" \
   "$WIN/"
install -m 0755 "$SRC/wsl/microsoft-edge" "$HOME/.local/bin/microsoft-edge"
printf '%s\n' "$token" > "$WIN/token"
printf '%s\n' "$token" > "$STATE/token"
chmod 600 "$STATE/token"

echo "stage: write token and config"
HOME_WIN="$(wslpath -w "$HOME")"
TMP_WIN="$(wslpath -w /tmp)"
python3 - "$WIN/config.json" "$HOME_WIN" "$TMP_WIN" <<'PYCONFIG'
import json, sys
path, *roots = sys.argv[1:]
legacy = "\\\\wsl$\\"
canonical = "\\\\wsl.localhost\\"
roots = [canonical + root[len(legacy):] if root.lower().startswith(legacy.lower()) else root for root in roots]
with open(path, "w", encoding="utf-8") as stream:
    json.dump({"version": 1, "allowedRoots": roots}, stream, indent=2)
    stream.write("\n")
PYCONFIG

echo "stage: update profile patch"
python3 - "$WEB/cordis.patch.yml" <<'PYPATCH'
import os, re, sys, tempfile
path = sys.argv[1]
with open(path, encoding="utf-8") as stream:
    lines = stream.readlines()
ids = {"vision-toolkit-windows-edge", "wsl-edge-bridge"}
owned_comment = "# Windows Edge bridge for Vision Toolkit HTML screenshots"
out = []
i = 0
while i < len(lines):
    match = re.match(r"^\s{4}- id:\s*([A-Za-z0-9_-]+)\s*$", lines[i])
    if match and match.group(1) in ids:
        while out and out[-1].strip() == owned_comment:
            out.pop()
        i += 1
        while i < len(lines) and not re.match(r"^\s{4}- id:\s*", lines[i]):
            i += 1
        continue
    if lines[i].strip() != owned_comment:
        out.append(lines[i])
    i += 1
text = "".join(out)
if re.search(r"^-\s*insert:\s*$", text, re.M):
    text = re.sub(r"^\[\]\s*\n", "", text, flags=re.M)
elif re.fullmatch(r"(?:#.*\n)*\[\]\n?", text):
    text = re.sub(r"\[\]\s*$", "- insert:\n", text)
else:
    text = text.rstrip("\n") + "\n- insert:\n"
entry = (
    "    # Windows Edge bridge for Vision Toolkit HTML screenshots\n"
    "    - id: vision-toolkit-windows-edge\n"
    "      name: './plugins/vision-toolkit-windows-edge/index.js'\n"
    "      config:\n"
    "        port: 8767\n"
    "        tokenFile: '~/.dsh/vision-toolkit-windows-edge/token'\n"
    "        allowedDirs: []\n"
    "        timeoutMs: 30000\n"
    "        maxImageBytes: 4194304\n"
    "        maxImagePixels: 20000000\n"
)
result = []
inserted = False
for line in text.splitlines(keepends=True):
    result.append(line)
    if not inserted and re.match(r"^-\s*insert:\s*$", line):
        result.append(entry)
        inserted = True
directory = os.path.dirname(path) or "."
fd, temporary = tempfile.mkstemp(prefix=".cordis.patch.", suffix=".tmp", dir=directory)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as stream:
        stream.write("".join(result))
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
PYPATCH

echo "stage: setup private Windows runtime"
SETUP="$(wslpath -w "$WIN/setup-runtime.ps1")"
REGISTER="$(wslpath -w "$WIN/register-task.ps1")"
"$PS" -NoProfile -ExecutionPolicy Bypass -File "$SETUP"
echo "stage: register hidden scheduled task"
"$PS" -NoProfile -ExecutionPolicy Bypass -File "$REGISTER" -Port "$PORT"
echo "installed dsh-vision-toolkit-windows-edge; restart dsh web"
