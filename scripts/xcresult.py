#!/usr/bin/env python3
"""Reads an .xcresult for scripts/ci.sh. Exits 1 on any warning, error or failed test.
`tests` also fails on build warnings, so test code stays warning-free too.

Usage: xcresult.py build <bundle>   |   xcresult.py tests <bundle>
"""
import json
import subprocess
import sys

kind, bundle = sys.argv[1], sys.argv[2]


def get(*args):
    return json.loads(subprocess.run(["xcrun", "xcresulttool", "get", *args, "--path", bundle],
                                     capture_output=True, text=True, check=True).stdout)


b = get("build-results")
for w in b["warnings"] + b["errors"]:
    print("  ⚠", w["message"])
if kind == "build" or b["warningCount"] or b["errorCount"]:
    print(f"  {b['warningCount']} warnings, {b['errorCount']} errors")
if kind == "build":
    sys.exit(1 if b["warningCount"] or b["errorCount"] else 0)

d = get("test-results", "summary")
print(f"  {d['result']}: {d['passedTests']} passed, {d['failedTests']} failed, {d['skippedTests']} skipped")
for f in d.get("testFailures", []):
    print(f"  ✘ {f['testName']}: {f['failureText']}")
passed = d["result"] == "Passed" and d["passedTests"] > 0
sys.exit(0 if passed and not b["warningCount"] else 1)
