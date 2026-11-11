#!/usr/bin/env python3
"""LAB-06.2B read-only diagnosis: STA Recovery/Removal, BSRAM, BankVccio.

Reads the existing exact Gowin fit. DOES NOT build or program the FPGA.
Output is diagnostic only, never STA or hardware acceptance.
"""
from __future__ import annotations

import argparse
from hashlib import sha256
from html import unescape
from pathlib import Path
import json
import re
import sys

DEFAULT_SHA = "31691075B56BB4167758AEB9D99CE8E7F4CE0BE84333D527FD2659606025F4A0"
HEADINGS = (
    "Clock Summary",
    "Path Slacks Table",
    "Setup Paths Table",
    "Hold Paths Table",
    "Recovery Paths Table",
    "Removal Paths Table",
    "Recovery Analysis Report",
    "Removal Analysis Report",
    "Minimum Pulse Width Table",
    "Timing Constraints Report",
    "Timing Exceptions Report",
)
COUNTERS = (
    "Numbers of Paths Analyzed",
    "Numbers of Endpoints Analyzed",
    "Numbers of Setup Violated Endpoints",
    "Numbers of Hold Violated Endpoints",
    "Numbers of Recovery Violated Endpoints",
    "Numbers of Removal Violated Endpoints",
)
PINS = {
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

def plain_html(raw: str) -> str:
    no_script = re.sub(r"(?is)<(?:script|style)\b[^>]*>.*?</(?:script|style)>", " ", raw)
    return re.sub(r"\s+", " ", unescape(re.sub(r"<[^>]+>", " ", no_script))).strip()

def diagnose_sections(t: str):
    for heading in HEADINGS:
        hits = list(re.finditer(re.escape(heading), t, flags=re.I))
        if not hits:
            print(f"LAB062_STA_SECTION_MISSING: {heading}")
            continue
        # HTML repeats labels in its navigation pane. Show the LAST mention
        # plus context; never infer a PASS from a displayed heading alone.
        pos = hits[-1]
        context = t[pos.end():pos.end()+500].strip()
        print(f"LAB062_STA_SECTION: {heading}; occurrences={len(hits)}; AFTER=[{context}]")

def diagnose_pins(report: str) -> bool:
    rows = {}
    for line in re.split(r"\r\n|\n|\r", report):
        if "|" not in line:
            continue
        cells = [x.strip() for x in line.split("|")]
        if cells and cells[0] in PINS:
            rows.setdefault(cells[0], []).append(cells)
    all_match = True
    for name, expected in PINS.items():
        hits = rows.get(name, [])
        if len(hits) != 1 or len(hits[0]) != 16:
            print(f"LAB062_PIN_DIAGNOSTIC: {name} rows={len(hits)} columns={[len(x) for x in hits]}")
            all_match = False
            continue
        c = hits[0]
        observed = (c[2].split("/",1)[0], c[6], c[15])
        matches = observed == expected and c[3] == "Y"
        print(f"LAB062_PNR_PIN_ROW: {name} loc={c[2]} IOType={c[6]} "
              f"BankVccio={c[15]} constrained={c[3]} expected={expected[2]} "
              f"{'MATCH' if matches else 'MISMATCH'}")
        if not matches:
            all_match = False
    return all_match

def diagnose_memories(report: str):
    lines = re.split(r"\r\n|\n|\r", report)
    pat = re.compile(r"\b(?:BSRAM|DPB|SDPB|SPB|Memory|ROM|RAM|block\s+memory)\b", re.I)
    hits = [(i+1, line.strip()) for i,line in enumerate(lines) if pat.search(line)]
    print(f"LAB062_MEMORY_EVIDENCE_LINES: {len(hits)} total, up to 28 follows")
    for number, line in hits[:28]:
        print(f"  {number}: {line[:200]}")

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("fit_job", type=Path)
    ap.add_argument("--expected-sha", default=DEFAULT_SHA)
    args = ap.parse_args()
    job = args.fit_job.resolve(strict=True)
    artifacts = {
        "bitstream": job / "lab062_pico_nano9k.fs",
        "receipt": job / "fit_receipt.json",
        "timing": job / "work/impl/pnr/lab062_pico_nano9k_tr_content.html",
        "resources": job / "work/impl/pnr/lab062_pico_nano9k.rpt.txt",
        "sdc": job / "work/constraints/lab062_nano9k.sdc",
        "gowin": job / "gowin_cli.log",
    }
    for name, path in artifacts.items():
        if not path.is_file():
            raise ValueError(f"LAB062_MISSING_{name.upper()}: {path}")
    receipt = json.loads(artifacts["receipt"].read_text(encoding="utf-8-sig"))
    if not all((
        receipt.get("Stage") == "LAB062_FIT",
        receipt.get("SimStatus") == "PASS",
        receipt.get("PnR") == "PASS",
        receipt.get("Board") == "NOT_RUN",
    )):
        raise ValueError("LAB062_RECEIPT_WRONG_STAGE_OR_STATUS")
    expected = args.expected_sha.upper()
    if not re.fullmatch(r"[0-9A-F]{64}", expected):
        raise ValueError("LAB062_EXPECTED_SHA_FORMAT_FAIL")
    actual = sha256(artifacts["bitstream"].read_bytes()).hexdigest().upper()
    if actual != expected or actual != receipt.get("BitstreamCandidateSHA256"):
        raise ValueError(f"LAB062_SHA256_MISMATCH: observed={actual} expected={expected}")
    print(f"LAB062_EXISTING_FIT_SHA256_PASS: {actual}")
    print("LAB062_DIAGNOSTIC_ONLY: no Gowin run or FPGA access")
    timing = plain_html(artifacts["timing"].read_text(encoding="utf-8",errors="replace"))
    for label in COUNTERS:
        m = re.search(re.escape(label)+r"\s+(\d+)\b",timing,flags=re.I)
        print(f"LAB062_STA_COUNT: {label} = {m.group(1) if m else 'NOT_REPORTED'}")
    diagnose_sections(timing)
    resource_txt = artifacts["resources"].read_text(encoding="utf-8",errors="replace")
    diagnose_memories(resource_txt)
    pins_ok = diagnose_pins(resource_txt)
    sdc = artifacts["sdc"].read_text(encoding="utf-8",errors="replace").strip()
    print(f"LAB062_SDC_CLOCK: {sdc}")
    if sdc != 'create_clock -name clk_i -period 37.037 -waveform {0 18.518} [get_ports {clk_i}]':
        print("LAB062_SDC_NOT_EXPECTED: hold hardware gate")
    if not pins_ok:
        print("LAB062_PIN_BANK_NOT_ACCEPTED: hold hardware gate")
    print("LAB062_STA_DIAGNOSTIC_COMPLETE: NOT A TIMING PASS; DO NOT PROGRAM")
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"LAB062_DIAGNOSTIC_ERROR: {exc}", file=sys.stderr)
        sys.exit(2)
