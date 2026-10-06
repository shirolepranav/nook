#!/bin/bash
# Keeps test runs from filling the disk on this Mac, which also hosts the CI runner (D31).
# Removes only what Xcode can rebuild: simulators whose runtime is no longer installed, and
# iOS DeviceSupport folders older than the newest one per device model (Xcode re-creates a
# version's folder when a device on it connects). Then stops if the disk is still nearly full.
set -euo pipefail

MIN_FREE_GB=${MIN_FREE_GB:-10}

xcrun simctl delete unavailable

support="$HOME/Library/Developer/Xcode/iOS DeviceSupport"
if [ -d "$support" ]; then
    # Folders look like "iPhone14,4 27.0.1 (24A446)": keep the highest version per model.
    ls -1 "$support" | python3 -c '
import sys, re, collections
by_model = collections.defaultdict(list)
for name in sys.stdin.read().splitlines():
    m = re.match(r"(\S+) ([\d.]+)", name)
    if m: by_model[m[1]].append((tuple(int(p) for p in m[2].split(".")), name))
for versions in by_model.values():
    for _, name in sorted(versions)[:-1]: print(name)
' | while IFS= read -r old; do
        echo "  Removing old DeviceSupport: $old"
        rm -rf "$support/$old"
    done
fi

free_gb=$(df -g /System/Volumes/Data | awk 'NR==2 {print $4}')
if [ "$free_gb" -lt "$MIN_FREE_GB" ]; then
    echo "  ✘ Only ${free_gb} GB free (need ${MIN_FREE_GB}). Free space before running tests."
    exit 1
fi
echo "  ✔ ${free_gb} GB free"
