#!/bin/zsh
set -euo pipefail

repository_root="${0:A:h:h}"
dist_directory="${EASYFLOW_DIST_DIR:-$repository_root/dist}"
app_bundle="$repository_root/.build/release-app/EasyFlow.app"
archive="$dist_directory/EasyFlow.zip"
checksum="$dist_directory/EasyFlow.zip.sha256"

rm -rf "$dist_directory"
mkdir -p "$dist_directory"

"$repository_root/scripts/build-release-app.sh"

if [[ ! -d "$app_bundle" ]]; then
  print -u2 -r -- "Release build failed: EasyFlow.app was not produced."
  exit 1
fi

bundle_id="$(plutil -extract CFBundleIdentifier raw "$app_bundle/Contents/Info.plist")"
if [[ "$bundle_id" != "io.github.natizh.easyflow" ]]; then
  print -u2 -r -- "Unexpected bundle identifier: $bundle_id"
  exit 1
fi

codesign --verify --deep --strict "$app_bundle"

ditto -c -k --sequesterRsrc --keepParent "$app_bundle" "$archive"

if ! unzip -Z1 "$archive" | grep -q '^EasyFlow.app/Contents/MacOS/EasyFlow$'; then
  print -u2 -r -- "Release archive verification failed."
  exit 1
fi

archive_hash="$(shasum -a 256 "$archive" | awk '{print $1}')"
print -r -- "$archive_hash  EasyFlow.zip" > "$checksum"

print -r -- "Packaged EasyFlow release: $archive"
print -r -- "SHA-256: $archive_hash"
