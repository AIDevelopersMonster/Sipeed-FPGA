#!/usr/bin/env python3
"""W01 Gowin PnR screen: exact SHA, timing + 10 IO BankVccio rows.

Screen authorizes *review* of a future volatile-SRAM lab candidate, not a
production STA sign-off. External async reset and UART RX are NOT qualified.
Never invokes Gowin or any programmer. Reads only the candidate's PnR files.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from html import unescape
from pathlib import Path

PORTS = {
    "clk_i": ("52", "LVCMOS33", "3.3"),
    "rstn_i": ("3", "LVCMOS18", "1.8"),
    "uart0_txd_o": ("17", "LVCMOS33", "3.3"),
    "uart0_rxd_i": ("18", "LVCMOS33", "3.3"),
    "led_n_o[0]": ("10", "LVCMOS18", "1.8"),
    "led_n_o[1]": ("11", "LVCMOS18", "1.8"),
    "led_n_o[2]": ("13", "LVCMOS18", "1.8"),
    "led_n_o[3]": ("14", "LVCMOS18", "1.8"),
    "led_n_o[4]": ("15", "LVCMOS18", "1.8"),
    "led_n_o[5]": ("16", "LVCMOS18", "1.8"),
}
COUNTS = (
    "Numbers of Paths Analyzed",
    "Numbers of Endpoints Analyzed",
    "Numbers of Setup Violated Endpoints",
    "Numbers of Hold Violated Endpoints",
)
SECTIONS = (
    ("setup", "Setup Paths Table", "Hold Paths Table"),
    ("hold", "Hold Paths Table", "Recovery Paths Table"),
    ("recovery", "Recovery Paths Table", "Removal Paths Table"),
    ("removal", "Removal Paths Table", "Minimum Pulse Width Table"),
)
EXPECTED_SDC = "create_clock -name clk_i -period 37.037 -waveform {0 18.518} [get_ports {clk_i}]"

def flatten(raw: str) -> str:
    raw = re.sub(r"(?is)<(?:script|style)\b[^>]*>.*?</(?:script|style)>", " ", raw)
    return re.sub(r"\s+", " ", unescape(re.sub(r"<[^>]+>", " ", raw))).strip()

def error(what: str) -> None:
    raise ValueError("W01_PNR_AUDIT_BLOCKER: " + what)

def counts_and_slacks(t: str) -> dict:
    counts = {}
    for key in COUNTS:
        m = re.search(re.escape(key) + r"\s+(\d+)\b", t)
        if not m: error("STA count missing: " + key)
        counts[key] = int(m.group(1))
    if counts[COUNTS[0]] <= 0 or counts[COUNTS[1]] <= 0:
        error("STA has no analyzed paths/endpoints")
    if counts[COUNTS[2]] != 0 or counts[COUNTS[3]] != 0:
        error("Setup/Hold violated endpoint count nonzero")
    if not re.search(r"\bclk_i\s+Base\s+37\.03[67]\s+27\.0", t):
        error("27MHz main clock missing in STA Clock Summary")
    if EXPECTED_SDC not in t or "Timing Constraints Report:" not in t:
        error("27MHz SDC not active in timing report")
    slacks = {}
    conditions = {}
    for name, start, end in SECTIONS:
        if start not in t or end not in t: error("STA section missing: " + name)
        block = t.partition(start)[2].partition(end)[0]
        m = re.search(r"\b1\s+(-?\d+(?:\.\d+)?)\s+\S+", block)
        if m is not None:
            s = float(m.group(1))
            if s <= 0: error("Nonpositive " + name + " slack: " + str(s))
            slacks[name] = s
            conditions[name] = "EVALUATED_POSITIVE"
        elif name in ("recovery", "removal") and "Nothing to report!" in block:
            slacks[name] = None
            conditions[name] = "NO_ANALYZED_PATHS_RESET_NOT_QUALIFIED"
        else:
            error("No acceptable slack evidence: " + name)
    return {"counts": counts, "slacks_ns": slacks, "categories": conditions}

def audit_ports(report: str) -> dict:
    rows = {}
    for line in re.split(r"\r\n|\n|\r", report):
        if "|" not in line:
            continue
        cells = [s.strip() for s in line.split("|")]
        if cells and cells[0] in PORTS:
            rows.setdefault(cells[0], []).append(cells)
    details = {}
    for name, expected in PORTS.items():
        matched = rows.get(name, [])
        if len(matched) != 1 or len(matched[0]) != 16:
            error(f"PNR pin table format/ambiguity: {name}, rows={len(matched)}")
        cell = matched[0]
        observed = (cell[2].split("/", 1)[0], cell[6], cell[15])
        if observed != expected or cell[3] != "Y":
            error(f"PNR pin/BankVccio mismatch: {name} observed={observed} "
                  f"constrained={cell[3]} expected={expected}")
        details[name] = {
            "pin": observed[0], "io_type": observed[1],
            "vccio": observed[2], "constraint": cell[3],
        }
    return details

def summary_row(report: str, key: str) -> str:
    m = re.search(r"(?m)^\s*" + re.escape(key) + r"\s*\|\s*([^\r\n]+)", report)
    return m.group(1).strip() if m else "NOT_REPORTED"

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--work", required=True, type=Path)
    p.add_argument("--top", required=True, choices=["w01_pico_nano9k", "w01_neo_nano9k"])
    p.add_argument("--sdc", required=True, type=Path)
    p.add_argument("--gowin-log", required=True, type=Path)
    p.add_argument("--fs", required=True, type=Path)
    p.add_argument("--expected-sha", required=True)
    p.add_argument("--json", required=True, type=Path)
    a = p.parse_args()
    if not re.fullmatch(r"[A-Fa-f0-9]{64}", a.expected_sha):
        error("Expected SHA256 is not 64 hexadecimal characters")
    fs_hash = hashlib.sha256(a.fs.read_bytes()).hexdigest().upper()
    if fs_hash != a.expected_sha.upper():
        error("Bitstream SHA mismatch")
    if a.fs.stat().st_size < 100000:
        error("Unexpectedly small Gowin bitstream; no device qualification")
    sdc = a.sdc.read_text(encoding="utf-8-sig").strip()
    if sdc != EXPECTED_SDC: error("SDC differs from accepted 27MHz constraint")
    log = a.gowin_log.read_text(encoding="utf-8", errors="replace")
    if "Bitstream generation completed" not in log:
        error("Gowin PnR log has no bitstream completion marker")
    if re.search(r"\b(?:ERROR|FATAL|TA1124)\b", log, re.I):
        error("Gowin PnR log contains an error/fatal marker")
    report_path = a.work / "impl" / "pnr" / (a.top + ".rpt.txt")
    timing_path = a.work / "impl" / "pnr" / (a.top + "_tr_content.html")
    report = report_path.read_text(encoding="utf-8", errors="replace")
    timing = flatten(timing_path.read_text(encoding="utf-8", errors="replace"))
    pins = audit_ports(report)
    sta = counts_and_slacks(timing)
    resources = {k: summary_row(report, k)
                 for k in ("Logic", "Register", "BSRAM", "DSP", "PLL", "I/O Port")}
    if any(resources[k] == "NOT_REPORTED" for k in ("Logic", "Register", "BSRAM")):
        error("Logic/Register/BSRAM missing from resource report")
    result = {
        "status": "PNR_PREBOARD_SCREEN_PASS_NOT_FULL_TIMING_SIGNOFF",
        "design": a.top, "bitstream_sha256": fs_hash,
        "pins": pins, "sta": sta, "resources": resources,
        "caveats": [
            "External UART RX timing not fully constrained",
            "Reset deassertion not qualified if Recovery/Removal have no paths",
            "Native-SoC resources differ from accepted counters-OFF baselines",
        ],
        "report_path": str(report_path), "timing_path": str(timing_path),
    }
    a.json.parent.mkdir(parents=True, exist_ok=True)
    a.json.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"W01_PNR_SHA256_PASS: {a.top} {fs_hash}")
    print(f"W01_PNR_PORTS_VCCIO_PASS: {a.top} 10/10")
    print(f"W01_PNR_SETUP_HOLD_PASS: {a.top} "
          f"setup={sta['slacks_ns']['setup']}ns hold={sta['slacks_ns']['hold']}ns")
    print(f"W01_PNR_RECOVERY_REMOVAL: {a.top} "
          f"recovery={sta['categories']['recovery']} "
          f"removal={sta['categories']['removal']}")
    print(f"W01_PNR_RESOURCES: {a.top} {resources}")
    print("W01_PNR_PREBOARD_SCREEN_PASS: no board programming; async reset caveat applies")
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as exc:
        print("W01_PNR_AUDIT_FAIL: " + str(exc), file=sys.stderr)
        sys.exit(2)
