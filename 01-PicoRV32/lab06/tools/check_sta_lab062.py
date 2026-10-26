#!/usr/bin/env python3
"""Conservative Tang Nano 9K / LAB-06.2B Gowin post-route STA screen.

This is a SCREEN, not final safety/CDC/board certification. Reports without
explicit positive timing evidence fail closed. Never programs the FPGA.
"""
from pathlib import Path
from html import unescape
import argparse
import re
import sys

def flatten(s):
    s = re.sub(r"<(?:script|style)\b[^>]*>.*?</(?:script|style)>", " ",
               s, flags=re.I | re.S)
    s = unescape(re.sub(r"<[^>]*>", " ", s))
    return re.sub(r"\s+", " ", s).strip()

def count(t, label):
    m = re.search(re.escape(label) + r"\s+(\d+)\b", t)
    if m is None:
        raise ValueError("Missing count: " + label)
    return int(m.group(1))

def slack(t, before, after):
    if before not in t or after not in t:
        return None
    part = t.partition(before)[2].partition(after)[0]
    # Gowin HTML flattened first data row: path index 1, slack, other columns.
    m = re.search(r"\b1\s+(-?\d+(?:\.\d+)?)\s+\S+", part)
    return float(m.group(1)) if m else None

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("timing_html", type=Path)
    p.add_argument("--log", type=Path)
    args = p.parse_args()
    t = flatten(args.timing_html.read_text(encoding="utf-8",errors="replace"))
    errors = []
    counts = {}
    for label in (
        "Numbers of Paths Analyzed",
        "Numbers of Endpoints Analyzed",
        "Numbers of Setup Violated Endpoints",
        "Numbers of Hold Violated Endpoints"
    ):
        counts[label] = count(t, label)
    if counts["Numbers of Paths Analyzed"] <= 0:
        errors.append("No timing paths analyzed")
    if counts["Numbers of Endpoints Analyzed"] <= 0:
        errors.append("No timing endpoints analyzed")
    if counts["Numbers of Setup Violated Endpoints"] != 0:
        errors.append("Setup violations")
    if counts["Numbers of Hold Violated Endpoints"] != 0:
        errors.append("Hold violations")
    values = {
        "setup": slack(t, "Setup Paths Table","Hold Paths Table"),
        "hold": slack(t, "Hold Paths Table","Recovery Paths Table"),
        "recovery": slack(t, "Recovery Paths Table","Removal Paths Table"),
        "removal": slack(t, "Removal Paths Table","Minimum Pulse Width Table")
    }
    for kind, v in values.items():
        if v is None or v <= 0:
            errors.append(f"Missing or non-positive {kind} minimum slack: {v}")
    if "lab062_nano9k.sdc" not in t:
        errors.append("Lab061 SDC not identified in timing report")
    # Same board as LAB-04; only a single constrained 27 MHz clock.
    if not re.search(r"\bclk_i\s+Base\s+37\.03[67]\s+27\.0", t):
        errors.append("Expected 27MHz clk_i clock not confirmed in timing report")
    if "Timing Constraints Report:" not in t:
        errors.append("Missing timing constraints report")
    if args.log:
        raw = args.log.read_text(encoding="utf-8", errors="replace")
        if re.search(r"\b(?:ERROR|FATAL|TA1124)\b", raw):
            errors.append("Gowin CLI log contains ERROR/FATAL/TA1124")
        if "Bitstream generation completed" not in raw:
            errors.append("Bitstream completion not confirmed by log")
    print(
        "LAB062_STA_SCREEN: "
        f"paths={counts['Numbers of Paths Analyzed']}, "
        f"endpoints={counts['Numbers of Endpoints Analyzed']}, "
        f"setup_viol={counts['Numbers of Setup Violated Endpoints']}, "
        f"hold_viol={counts['Numbers of Hold Violated Endpoints']}, "
        f"min_slacks={values}"
    )
    if errors:
        for e in errors:
            print("LAB062_STA_BLOCKER:",e)
        print("LAB062_STA_SCREEN_FAIL: DO NOT PROGRAM")
        return 1
    print("LAB062_STA_SCREEN_PRELIM_PASS: report positive slacks; detailed audit/board PENDING")
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, UnicodeError, ValueError) as e:
        print("LAB062_STA_AUDITOR_ERROR:", e, file=sys.stderr)
        sys.exit(2)
