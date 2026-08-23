#!/bin/zsh
set -euo pipefail

repository_root="${0:A:h:h}"
configuration="${1:-debug}"
(cd "$repository_root" && swift build -c "$configuration")
binary_directory="$(cd "$repository_root" && swift build -c "$configuration" --show-bin-path)"
app_bundle="${EASYFLOW_APP_OUTPUT:-$repository_root/.build/dev/EasyFlow.app}"

rm -rf "$app_bundle"
mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
cp "$repository_root/Support/Info.plist" "$app_bundle/Contents/Info.plist"
cp "$binary_directory/EasyFlow" "$app_bundle/Contents/MacOS/EasyFlow"

for resource_bundle in "$binary_directory"/*.bundle(N); do
  cp -R "$resource_bundle" "$app_bundle/Contents/Resources/"
done

icon_files=("$repository_root/Support/AppIcon.iconset"/*.png(N))
if (( ${#icon_files} > 0 )); then
  iconutil -c icns "$repository_root/Support/AppIcon.iconset" \
    -o "$app_bundle/Contents/Resources/EasyFlow.icns"
fi

if [[ "${EASYFLOW_SKIP_CODESIGN:-0}" != "1" ]]; then
  codesign --force --deep --sign "${EASYFLOW_SIGN_IDENTITY:--}" "$app_bundle"
fi
print -r -- "$app_bundle"
