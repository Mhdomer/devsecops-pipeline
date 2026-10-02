"""DAST gate: decide pass/block from a ZAP baseline JSON report.

Blocks when either is true:
  * any alert has risk High (riskcode 3), whichever rule raised it
  * any alert comes from a rule marked FAIL in the rules file

Exit codes: 0 pass, 1 blocked, 2 report or rules file missing/unreadable, or
outside the working directory.

Usage: python zap/zap_gate.py <zap-report.json> <zap-baseline.conf>
"""
import json
import os
import sys
from pathlib import Path

HIGH = 3
RISK_NAMES = {0: "Info", 1: "Low", 2: "Medium", 3: "High"}


def confined_path(raw):
    """Resolve a CLI path and refuse anything outside the working directory.

    The gate only ever reads files the scan just wrote inside the checkout, so a
    path that resolves elsewhere (absolute, or ../ traversal) is an error.
    """
    base = os.path.normcase(str(Path.cwd().resolve()))
    resolved = Path(raw).resolve()
    if os.path.commonpath([base, os.path.normcase(str(resolved))]) != base:
        raise ValueError(f"{raw} is outside the working directory")
    return resolved


def load_fail_rules(conf_path):
    rules = set()
    for line in Path(conf_path).read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) >= 2 and parts[1].strip() == "FAIL":
            rules.add(parts[0].strip())
    return rules


def alerts(report):
    for site in report.get("site", []):
        yield from site.get("alerts", [])


def evaluate(report, fail_rules):
    """Return the alerts that block the pipeline."""
    return [
        a for a in alerts(report)
        if int(a["riskcode"]) >= HIGH or str(a["pluginid"]) in fail_rules
    ]


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2
    try:
        report = json.loads(confined_path(argv[0]).read_text(encoding="utf-8"))
        fail_rules = load_fail_rules(confined_path(argv[1]))
    except (OSError, ValueError) as err:
        print(f"ZAP gate: cannot read input: {err}")
        return 2

    found = list(alerts(report))
    blocking = evaluate(report, fail_rules)
    print(f"ZAP gate: {len(found)} alert type(s), {len(blocking)} blocking")
    for a in found:
        risk = RISK_NAMES.get(int(a["riskcode"]), a["riskcode"])
        mark = "BLOCK" if a in blocking else "warn "
        print(f"  {mark} [{a['pluginid']}] {risk:6} {a['name']} (x{a.get('count', '?')})")

    if blocking:
        print("BLOCKED: High-risk alert or FAIL-listed rule triggered.")
        return 1
    print("PASSED: no High-risk alerts, no FAIL-listed rules triggered.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
