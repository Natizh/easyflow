#!/bin/zsh
set -euo pipefail

repository_root="${0:A:h:h}"
configuration="${1:-debug}"
binary_directory="$(cd "$repository_root" && swift build -c "$configuration" --show-bin-path)"
app_bundle="$repository_root/.build/dev/EasyFlow.app"

rm -rf "$app_bundle"
mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
cp "$repository_root/Support/Info.plist" "$app_bundle/Contents/Info.plist"
cp "$binary_directory/EasyFlow" "$app_bundle/Contents/MacOS/EasyFlow"

for resource_bundle in "$binary_directory"/*.bundle(N); do
  cp -R "$resource_bundle" "$app_bundle/Contents/Resources/"
done

codesign --force --deep --sign - "$app_bundle"
print -r -- "$app_bundle"
