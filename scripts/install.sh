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

"$repository_root/scripts/build-release-app.sh"

source_app="$repository_root/.build/release-app/EasyFlow.app"
if [[ ! -d "$source_app" ]]; then
  print -u2 -r -- "EasyFlow.app was not produced."
  exit 1
fi

pkill -x EasyFlow >/dev/null 2>&1 || true

if [[ -w /Applications ]]; then
  destination="/Applications/EasyFlow.app"
else
  mkdir -p "$HOME/Applications"
  destination="$HOME/Applications/EasyFlow.app"
fi

rm -rf "$destination"
ditto "$source_app" "$destination"
codesign --verify --deep --strict "$destination"

print -r -- "Installed EasyFlow: $destination"

if [[ "${EASYFLOW_INSTALL_NO_OPEN:-0}" != "1" ]]; then
  open "$destination"
fi
