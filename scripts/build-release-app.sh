#!/bin/zsh
set -euo pipefail

repository_root="${0:A:h:h}"
EASYFLOW_APP_OUTPUT="$repository_root/.build/release-app/EasyFlow.app" \
EASYFLOW_SKIP_CODESIGN=1 \
  "$repository_root/scripts/build-dev-app.sh" release
