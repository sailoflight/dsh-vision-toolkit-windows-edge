#!/usr/bin/env bash
set -euo pipefail
WEB="$HOME/.dsh/profiles/web"
WIN="/mnt/c/MCP/dsh-vision-toolkit-windows-edge"
OLD_WIN="/mnt/c/MCP/dsh-wsl-edge-bridge"
PS='/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'
if [ -x "$PS" ]; then
  "$PS" -NoProfile -Command '
    foreach($name in @("DshWslEdgeBridge", "DshVisionToolkitWindowsEdge")) {
      Stop-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
      if(Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $name -Confirm:$false
      }
    }
    $c=Get-NetTCPConnection -LocalPort 8767 -State Listen -ErrorAction SilentlyContinue
    if($c){Stop-Process -Id $c.OwningProcess -Force}
  ' || true
fi
rm -rf "$WEB/plugins/vision-toolkit-windows-edge" \
       "$WEB/plugins/wsl-edge-bridge" \
       "$HOME/.dsh/vision-toolkit-windows-edge" \
       "$HOME/.dsh/wsl-edge-bridge" \
       "$WIN" "$OLD_WIN"
rm -f "$HOME/.local/bin/microsoft-edge"
python3 - "$WEB/cordis.patch.yml" <<'PY'
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
if re.search(r"^-\s*insert:\s*$", text, re.M) and not re.search(r"^\s{4}- id:", text, re.M):
    text = text.split("- insert:", 1)[0] + "[]\n"
directory = os.path.dirname(path) or "."
fd, temporary = tempfile.mkstemp(prefix=".cordis.patch.", suffix=".tmp", dir=directory)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as stream:
        stream.write(text)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
PY
