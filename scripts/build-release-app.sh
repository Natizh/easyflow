#!/bin/zsh
set -euo pipefail

repository_root="${0:A:h:h}"
EASYFLOW_APP_OUTPUT="$repository_root/.build/release-app/EasyFlow.app" \
  "$repository_root/scripts/build-dev-app.sh" release
