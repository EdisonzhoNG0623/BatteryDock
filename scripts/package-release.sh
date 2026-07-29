#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
version="${1:-1.0.0}"
dist_dir="$project_dir/dist"
app_dir="$dist_dir/BatteryDock.app"
stage_dir="/private/tmp/BatteryDock-$version-dmg-stage"
dmg_path="$dist_dir/BatteryDock-$version-macOS-arm64.dmg"
zip_path="$dist_dir/BatteryDock-$version-macOS-arm64.zip"
checksums_path="$dist_dir/SHA256SUMS.txt"
plist_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/Resources/Info.plist")"

if [[ ! "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  echo "Version must use the form major.minor.patch" >&2
  exit 1
fi

if [[ "$version" != "$plist_version" ]]; then
  echo "Version mismatch: requested $version but Info.plist contains $plist_version" >&2
  exit 1
fi

"$project_dir/scripts/build-app.sh"

/bin/rm -rf "$stage_dir" "$dmg_path" "$zip_path" "$checksums_path"
mkdir -p "$stage_dir"
ditto --norsrc --noextattr --noqtn --noacl "$app_dir" "$stage_dir/BatteryDock.app"
ln -s /Applications "$stage_dir/Applications"
xattr -cr "$stage_dir/BatteryDock.app"
codesign --verify --deep --strict "$stage_dir/BatteryDock.app"

hdiutil create \
  -volname "BatteryDock $version" \
  -srcfolder "$stage_dir" \
  -ov \
  -format UDZO \
  "$dmg_path"

ditto -c -k --norsrc --noextattr --noqtn --noacl --keepParent "$app_dir" "$zip_path"

(
  cd "$dist_dir"
  shasum -a 256 "${dmg_path:t}" "${zip_path:t}" > "${checksums_path:t}"
)

/bin/rm -rf "$stage_dir"
echo "$dmg_path"
echo "$zip_path"
echo "$checksums_path"
