#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/.build"
dist_dir="$project_dir/dist"
app_dir="$dist_dir/BatteryDock.app"
xcode_developer_dir="/Applications/Xcode.app/Contents/Developer"
swift_cache_dir="/private/tmp/batterydock-swift-cache"
clang_cache_dir="/private/tmp/batterydock-clang-cache"

env \
  DEVELOPER_DIR="$xcode_developer_dir" \
  SWIFTPM_MODULECACHE_OVERRIDE="$swift_cache_dir" \
  CLANG_MODULE_CACHE_PATH="$clang_cache_dir" \
  swift build --disable-sandbox -c release --package-path "$project_dir"

/bin/rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$build_dir/release/BatteryDock" "$app_dir/Contents/MacOS/BatteryDock"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
codesign --force --deep --sign - "$app_dir"

echo "$app_dir"
