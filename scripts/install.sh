#!/bin/zsh
set -euo pipefail

repository_root="${0:A:h:h}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 -r -- "EasyFlow can only be built and installed on macOS."
  exit 1
fi

if ! command -v swift >/dev/null 2>&1 || ! command -v xcrun >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Apple's developer command-line tools are required to build EasyFlow.

Install them with:
  xcode-select --install

Then run ./scripts/install.sh again.
EOF
  exit 1
fi

if [[ $# -gt 1 ]]; then
  print -u2 -r -- "Usage: ./scripts/install.sh [path/to/EasyFlow.app]"
  exit 1
fi
if [[ $# -eq 1 ]]; then
  source_app="${1:A}"
else
  "$repository_root/scripts/build-release-app.sh"
  source_app="$repository_root/.build/release-app/EasyFlow.app"
fi
"$repository_root/scripts/verify-release-app.sh" "$source_app"

if [[ ! -d "$source_app" ]]; then
  print -u2 -r -- "EasyFlow.app was not produced."
  exit 1
fi

if pgrep -x EasyFlow >/dev/null; then
  swift -e 'import AppKit; for app in NSRunningApplication.runningApplications(withBundleIdentifier: "io.github.natizh.easyflow") { _ = app.terminate() }'
  for attempt in {1..100}; do
    pgrep -x EasyFlow >/dev/null || break
    sleep 0.1
  done
  if pgrep -x EasyFlow >/dev/null; then
    print -u2 -r -- "EasyFlow is still running. Installation stopped to protect pending saves."
    exit 1
  fi
fi

if [[ -w /Applications ]]; then
  destination="/Applications/EasyFlow.app"
else
  mkdir -p "$HOME/Applications"
  destination="$HOME/Applications/EasyFlow.app"
fi

if [[ "$source_app" == "$destination" ]]; then
  print -u2 -r -- "Source and installation destination must differ."
  exit 1
fi
rm -rf "$destination"
ditto "$source_app" "$destination"
codesign --verify --deep --strict "$destination"

print -r -- "Installed EasyFlow: $destination"

if [[ "${EASYFLOW_INSTALL_NO_OPEN:-0}" != "1" ]]; then
  open "$destination"
fi
