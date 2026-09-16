#!/bin/zsh
set -euo pipefail
app_bundle="${1:?Usage: verify-release-app.sh path/to/EasyFlow.app}"
repository_root="${0:A:h:h}"
plist="$app_bundle/Contents/Info.plist"
for key in CFBundleIdentifier CFBundleShortVersionString CFBundleVersion CFBundleExecutable CFBundleIconFile; do
  expected="$(plutil -extract "$key" raw "$repository_root/Support/Info.plist")"
  actual="$(plutil -extract "$key" raw "$plist")"
  if [[ "$actual" != "$expected" ]]; then
    print -u2 -r -- "Bundle mismatch: $key"
    exit 1
  fi
done
[[ -x "$app_bundle/Contents/MacOS/EasyFlow" ]]
[[ -s "$app_bundle/Contents/Resources/EasyFlow.icns" ]]
codesign --verify --deep --strict "$app_bundle"
python3 - "$app_bundle" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
for path in root.rglob('*'):
    name=path.name.lower()
    if name in {'.agent-context','attachments','backups','preferences.plist','.env','.git'} or any(name.endswith(suffix) for suffix in ('.sqlite','.sqlite-wal','.sqlite-shm','.db','.p12','.pem')):
        raise SystemExit('Private state found in app bundle')
print('Bundle metadata, executable, icon, signature, and privacy checks passed.')
PY
