#!/bin/bash
# Adds new user-facing strings to Nook/Resources/Localizable.xcstrings (CLAUDE.md: copy lives
# in the catalog). Xcode does this when building in the IDE; xcodebuild only emits .stringsdata.
# Usage: scripts/sync-strings.sh [DerivedData path]   (after a build)
set -euo pipefail
cd "$(dirname "$0")/.."
DD=${1:-.build/ci/DerivedData}
args=()
while IFS= read -r f; do args+=(--stringsdata "$f"); done < <(find "$DD/Build/Intermediates.noindex/Nook.build" -path "*Nook.build/Objects-normal*" -name "*.stringsdata")
[ ${#args[@]} -gt 0 ] || { echo "No .stringsdata under $DD; build first."; exit 1; }
xcrun xcstringstool sync Nook/Resources/Localizable.xcstrings "${args[@]}" 2>&1 | grep -v "staleness checking" || true
echo "✔ Strings synced"
