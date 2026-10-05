#!/bin/bash
# Fails when Swift code breaks a hard rule from CLAUDE.md (05 §2 policy greps).
cd "$(dirname "$0")/.." || exit 1
status=0

# $1 = rule, $2 = regex, remaining args = paths to search
check() {
    local rule=$1 pattern=$2; shift 2
    local hits
    hits=$(grep -rnE --include='*.swift' "$pattern" "$@" 2>/dev/null)
    if [ -n "$hits" ]; then
        echo "✘ $rule"; echo "$hits"; status=1
    fi
}

app_code=(Nook NookWidgets Packages/NookKit Packages/NookAI)

check "Size classes only: no UIScreen.main or idiom checks" 'UIScreen\.main|userInterfaceIdiom' Nook NookWidgets Packages
check "Only NookAI imports FoundationModels or Vision" '^import (FoundationModels|Vision)' Nook NookWidgets Packages/NookKit Packages/NookUI
check "No network: URLSession is not allowed" 'URLSession' Nook NookWidgets Packages
check "Tokens only: no color literals outside NookUI" 'Color\(red:|UIColor\(red:|Color\(#' "${app_code[@]}"
check "Tokens only: no font size literals outside NookUI" '\.system\(size:' "${app_code[@]}"
check "CloudKit-safe: no unique attributes" '@Attribute\(\.unique' Packages Nook

[ $status -eq 0 ] && echo "✔ Policy checks passed"
exit $status
