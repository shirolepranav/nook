#!/bin/bash
# The full check run by CI on every PR, and by hand before a merge (05 §2, D31).
# Needs Xcode 27 and iOS 27.0 simulators named below.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=.build/ci
DD=$OUT/DerivedData
PHONE='platform=iOS Simulator,name=iPhone SE (3rd generation),OS=27.0'
IPAD='platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=27.0'
rm -rf "$OUT/results"; mkdir -p "$OUT/results"
# One simulator per destination, no clones: parallel testing can't boot extra devices
# on a busy Mac ("insufficient system resources").

step() { echo; echo "▶ $1"; }

summarize() { scripts/xcresult.py tests "$1"; }

step "Policy checks"
scripts/policy-check.sh

step "Design tokens"
python3 design/tools/check_tokens.py > "$OUT/tokens.log" || { cat "$OUT/tokens.log"; exit 1; }
tail -4 "$OUT/tokens.log" | sed "s/^/  /"

step "Build app and tests (zero warnings)"
xcodebuild build-for-testing -quiet -project Nook.xcodeproj -scheme Nook \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD" \
    -resultBundlePath "$OUT/results/build.xcresult" SWIFT_TREAT_WARNINGS_AS_ERRORS=YES > "$OUT/build.log" 2>&1 || true
scripts/xcresult.py build "$OUT/results/build.xcresult"

step "NookKit tests (swift test)"
swift test --quiet --package-path Packages/NookKit

for pkg in NookUI NookAI; do
    step "$pkg tests (iPhone SE)"
    (cd "Packages/$pkg" && xcodebuild test -quiet -scheme "$pkg" -destination "$PHONE" \
        -parallel-testing-enabled NO -derivedDataPath "../../$DD-$pkg" \
        -resultBundlePath "../../$OUT/results/$pkg.xcresult") > "$OUT/$pkg.log" 2>&1 || true
    summarize "$OUT/results/$pkg.xcresult"
done

for dest in "$PHONE" "$IPAD"; do
    name=$(echo "$dest" | sed 's/.*name=\([^,]*\).*/\1/')
    step "App unit and UI tests ($name)"
    xcodebuild test-without-building -quiet -project Nook.xcodeproj -scheme Nook -destination "$dest" \
        -parallel-testing-enabled NO -derivedDataPath "$DD" \
        -resultBundlePath "$OUT/results/app-${name// /_}.xcresult" > "$OUT/app-${name// /_}.log" 2>&1 || true
    summarize "$OUT/results/app-${name// /_}.xcresult"
done

echo; echo "✔ CI passed"
