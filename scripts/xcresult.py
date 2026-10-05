#!/usr/bin/env python3
"""Reads an .xcresult for scripts/ci.sh. Exits 1 on any warning, error or failed test.

Usage: xcresult.py build <bundle>   |   xcresult.py tests <bundle>
"""
import json
import subprocess
import sys

kind, bundle = sys.argv[1], sys.argv[2]
args = ["build-results"] if kind == "build" else ["test-results", "summary"]
d = json.loads(subprocess.run(["xcrun", "xcresulttool", "get", *args, "--path", bundle],
                              capture_output=True, text=True, check=True).stdout)
if kind == "build":
    for w in d["warnings"] + d["errors"]:
        print("  ⚠", w["message"])
    print(f"  {d['warningCount']} warnings, {d['errorCount']} errors")
    sys.exit(1 if d["warningCount"] or d["errorCount"] else 0)

print(f"  {d['result']}: {d['passedTests']} passed, {d['failedTests']} failed, {d['skippedTests']} skipped")
for f in d.get("testFailures", []):
    print(f"  ✘ {f['testName']}: {f['failureText']}")
sys.exit(0 if d["result"] == "Passed" and d["passedTests"] > 0 else 1)
