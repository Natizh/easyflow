#!/bin/zsh
set -euo pipefail

repository_root="${0:A:h:h}"
configuration="${1:-debug}"
print -r -- "Building EasyFlow ($configuration)..."
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

icon_master="$repository_root/assets/brand/easyflow-app-icon.png"
if [[ -f "$icon_master" ]]; then
  iconset="$repository_root/.build/generated/EasyFlow.iconset"
  rm -rf "$iconset"
  mkdir -p "$iconset"

  function render_icon() {
    local filename="$1"
    local size="$2"
    sips -z "$size" "$size" "$icon_master" --out "$iconset/$filename" >/dev/null
  }

  render_icon icon_16x16.png 16
  render_icon icon_16x16@2x.png 32
  render_icon icon_32x32.png 32
  render_icon icon_32x32@2x.png 64
  render_icon icon_128x128.png 128
  render_icon icon_128x128@2x.png 256
  render_icon icon_256x256.png 256
  render_icon icon_256x256@2x.png 512
  render_icon icon_512x512.png 512
  render_icon icon_512x512@2x.png 1024

  iconutil -c icns "$iconset" -o "$app_bundle/Contents/Resources/EasyFlow.icns"
else
  print -r -- "Warning: assets/brand/easyflow-app-icon.png is missing; using the macOS default icon."
fi

if [[ "${EASYFLOW_SKIP_CODESIGN:-0}" != "1" ]]; then
  codesign --force --deep --sign "${EASYFLOW_SIGN_IDENTITY:--}" "$app_bundle"
fi
print -r -- "Built EasyFlow.app: $app_bundle"
