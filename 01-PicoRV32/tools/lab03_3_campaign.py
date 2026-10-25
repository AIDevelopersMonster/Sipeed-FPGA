#!/usr/bin/env python3
"""LAB-03.3: repeatable Tang Nano 9K UART trace capture and evidence audit.

Runs the already-tested local LAB-03.2 PowerShell probe. Does not program the FPGA.
Only validates the probe's announced UART/trace integrity and LED MMIO result;
it does NOT claim cycle-level or instruction-by-instruction equivalence.

Requirements: Python 3.9+, PowerShell 7, existing probe_lab03_2_serial.ps1.
"""

from __future__ import annotations

import argparse
import ast
import csv
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

VERSION = "LAB03.3-campaign-v0.1"
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
TRACE = re.compile(
    r"LAB03_2_TRACE_DECODE_PASS:\s*"
    r"command=(?P<command>\d+)\s*,\s*"
    r"events=(?P<events>\d+)\s*,\s*"
    r"fetches=(?P<fetches>\d+)\s*,\s*"
    r"LED_WRITE=(?P<led_write>0x[\da-fA-F]+)\s*,\s*"
    r"flags=(?P<flags>\{[^\r\n]*\})"
)
DUMP = re.compile(r"(?m)^\s*UART dump saved:\s*(?P<path>[^\r\n]+?)\s*$")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def expected_led_write(command: int) -> int:
    if not 0 <= command <= 6:
        raise ValueError(f"Unsupported LED command {command}; expected 0..6")
    return 0 if command == 0 else 1 << (command - 1)


def parse_probe_output(output: str) -> dict:
    """Parse only the existing probe's explicit PASS lines; never infer a PASS."""
    cleaned = ANSI.sub("", output)
    matches = list(TRACE.finditer(cleaned))
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one TRACE_DECODE_PASS, found {len(matches)}")
    if len(re.findall(r"LAB03_2_BOARD_UART_DATA_PASS", cleaned)) != 1:
        raise ValueError("Expected exactly one BOARD_UART_DATA_PASS")
    m = matches[0]
    try:
        flags = ast.literal_eval(m.group("flags"))
    except (SyntaxError, ValueError) as exc:
        raise ValueError(f"Invalid probe flags: {exc}") from exc
    if not isinstance(flags, dict) or not flags:
        raise ValueError("Probe flags are absent or malformed")
    if not all(isinstance(key, str) and isinstance(value, bool) for key, value in flags.items()):
        raise ValueError("Probe flags must be a dictionary of booleans")
    paths = DUMP.findall(cleaned)
    if len(paths) != 1:
        raise ValueError(f"Expected exactly one raw UART dump path, found {len(paths)}")
    return {
        "command": int(m.group("command")),
        "events": int(m.group("events")),
        "fetches": int(m.group("fetches")),
        "led_write": int(m.group("led_write"), 16),
        "flags": flags,
        "dump_path": paths[0].strip().strip('"'),
    }


def validate_parsed(parsed: dict, sent_command: int) -> list[str]:
    errors: list[str] = []
    if parsed["command"] != sent_command:
        errors.append(f"Echoed command {parsed['command']} != sent {sent_command}")
    if parsed["led_write"] != expected_led_write(sent_command):
        errors.append(
            f"LED_WRITE=0x{parsed['led_write']:08X}, "
            f"expected=0x{expected_led_write(sent_command):08X}"
        )
    if parsed["events"] < 1 or parsed["fetches"] < 1:
        errors.append("Empty event or FETCH set")
    if parsed["fetches"] > parsed["events"]:
        errors.append("FETCH count exceeds event count")
    if parsed["flags"].get("done") is not True:
        errors.append("DONE flag is not True")
    for name in ("truncated", "overlap", "wrapped", "capturing"):
        if parsed["flags"].get(name) is not False:
            errors.append(f"Flag {name} is not False")
    return errors


def command_output(cmd: list[str], cwd: Path | None = None) -> str | None:
    try:
        r = subprocess.run(cmd, cwd=cwd, text=True, encoding="utf-8", errors="replace",
                           capture_output=True, check=False, timeout=15)
        return r.stdout.strip() if r.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def git_metadata(repo: Path) -> dict:
    head = command_output(["git", "-C", str(repo), "rev-parse", "HEAD"])
    branch = command_output(["git", "-C", str(repo), "branch", "--show-current"])
    state = command_output(["git", "-C", str(repo), "status", "--porcelain"])
    return {
        "commit": head,
        "branch": branch,
        "working_tree_dirty": (bool(state) if state is not None else None),
    }


def read_results(session: Path) -> list[dict]:
    result_path = session / "runs.json"
    if not result_path.is_file():
        raise FileNotFoundError(f"Not found: {result_path}")
    rows = json.loads(result_path.read_text(encoding="utf-8"))
    if not isinstance(rows, list):
        raise ValueError("runs.json must be a list")
    return rows


def audit_rows(session: Path, rows: list[dict]) -> list[str]:
    errors: list[str] = []
    if not rows:
        errors.append("No captured runs to audit")
    for row in rows:
        number = row.get("index")
        if row.get("status") != "PASS":
            errors.append(f"Run {number}: status is not PASS ({row.get('status')})")
            continue
        relative = row.get("raw_file")
        expected_hash = row.get("sha256")
        if not relative or not expected_hash:
            errors.append(f"Run {number}: no archived raw file or hash")
            continue
        raw = (session / relative).resolve()
        if not raw.is_relative_to(session.resolve()):
            errors.append(f"Run {number}: invalid path escapes session")
            continue
        if not raw.is_file():
            errors.append(f"Run {number}: missing {relative}")
            continue
        if sha256_file(raw).lower() != str(expected_hash).lower():
            errors.append(f"Run {number}: raw UART SHA256 mismatch")
        try:
            values = {"command": int(row["command"]),
                      "events": int(row["events"]),
                      "fetches": int(row["fetches"]),
                      "led_write": int(row["led_write"], 16),
                      "flags": row["flags"]}
            errors.extend(f"Run {number}: {error}" for error in
                          validate_parsed(values, int(row["requested_command"])))
        except (KeyError, ValueError, TypeError) as exc:
            errors.append(f"Run {number}: malformed metadata ({exc})")
    return errors


def summary_markdown(rows: list[dict], errors: list[str], manifest: dict) -> str:
    grouped: dict[int, list[dict]] = defaultdict(list)
    for row in rows:
        if row.get("status") == "PASS":
            grouped[int(row["requested_command"])].append(row)
    lines = [
        "# LAB-03.3 campaign report",
        "",
        f"- Created (UTC): {utc_now()}",
        f"- Board: {manifest.get('board', 'unknown')}",
        f"- Git commit: `{manifest.get('git', {}).get('commit') or 'unavailable'}`",
        f"- Bitstream SHA256 (declared, not independently read back from FPGA): `{manifest.get('bitstream', {}).get('sha256') or 'unavailable'}`",
        f"- Runs: {len(rows)}; verified PASS: {sum(r.get('status') == 'PASS' for r in rows)}",
        f"- Overall capture/MMIO: **{'FAIL' if errors else 'PASS'}**",
        "",
        "| Command | Captures | FETCH counts | Event counts | Constant FETCH count? |",
        "|---|---:|---|---|---|",
    ]
    for cmd, subset in sorted(grouped.items()):
        fetches = sorted({int(row["fetches"]) for row in subset})
        events = sorted({int(row["events"]) for row in subset})
        lines.append(f"| {cmd} | {len(subset)} | {', '.join(map(str, fetches))} | "
                     f"{', '.join(map(str, events))} | {'yes' if len(fetches) == 1 else 'NO'} |")
    if errors:
        lines += ["", "## Failures"] + [f"- {error}" for error in errors]
    lines += [
        "", "## Scope of this report", "",
        "PASS certifies captured UART transport, declared probe decoding, archive hashes, "
        "snapshot status flags and final LED_WRITE values for the requested commands.",
        "It does **not** certify an instruction-by-instruction match, retired-instruction counts, "
        "cycle-level equivalence, absence of unseen events, or LED optical state.",
        "Different FETCH counts are *reported*, not automatically treated as a defect: "
        "the capture window and event semantics must first be established.",
        "", "Raw data in `raw/`; each run's console output in `console/`. "
        "Use the matching Git commit and bitstream hash when comparing with RTL.", "",
    ]
    return "\n".join(lines)


def write_results(session: Path, rows: list[dict], manifest: dict) -> list[str]:
    session.mkdir(parents=True, exist_ok=True)
    (session / "runs.json").write_text(json.dumps(rows, indent=2, ensure_ascii=False) + "\n",
                                       encoding="utf-8")
    fields = ["index", "requested_command", "command", "events", "fetches", "led_write",
              "expected_led_write", "status", "sha256", "raw_file", "console_file", "utc"]
    with (session / "runs.csv").open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    errors = audit_rows(session, rows)
    (session / "report.md").write_text(summary_markdown(rows, errors, manifest), encoding="utf-8")
    return errors


def do_run(args: argparse.Namespace) -> int:
    repo = Path(__file__).resolve().parents[2]
    lab = repo / "01-PicoRV32"
    probe = Path(args.probe).expanduser().resolve() if args.probe else lab / "tools" / "probe_lab03_2_serial.ps1"
    bitstream = Path(args.bitstream).expanduser().resolve()
    if not probe.is_file():
        raise FileNotFoundError(f"Local LAB-03.2 probe not found: {probe}")
    if not bitstream.is_file():
        raise FileNotFoundError(f"Bitstream not found: {bitstream}")
    if args.rounds < 1 or args.rounds > 20:
        raise ValueError("rounds must be 1..20")
    if args.timeout_sec < 5 or args.timeout_sec > 600:
        raise ValueError("timeout-sec must be 5..600")
    if args.gap_ms < 0 or args.gap_ms > 60_000:
        raise ValueError("gap-ms must be 0..60000")
    commands = [int(x.strip()) for x in args.sequence.split(",")]
    if not commands or len(commands) > 30:
        raise ValueError("sequence must contain 1..30 commands")
    for cmd in commands:
        expected_led_write(cmd)
    base = Path(args.output_dir).expanduser().resolve() if args.output_dir else lab / "build" / "lab03_3"
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    session = base / ("campaign_" + stamp)
    session.mkdir(parents=True, exist_ok=False)
    (session / "raw").mkdir()
    (session / "console").mkdir()
    manifest = {
        "version": VERSION,
        "started_utc": utc_now(),
        "board": "Sipeed Tang Nano 9K / GW1NR-9C",
        "transport": {"port": args.port, "baud": 115200, "frame": "8N1"},
        "probe": str(probe), "probe_sha256": sha256_file(probe),
        "campaign_script_sha256": sha256_file(Path(__file__).resolve()),
        "bitstream": {"file": str(bitstream), "sha256": sha256_file(bitstream),
                      "note": "Hash identifies supplied .fs; SRAM readback not performed."},
        "programming_evidence": {"operator_reported_user_code": args.user_code,
                                 "note": "Not checked against active FPGA configuration."},
        "git": git_metadata(repo),
        "command_sequence": commands,
        "rounds": args.rounds,
        "gap_ms": args.gap_ms,
        "session": str(session),
    }
    (session / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    rows: list[dict] = []
    print(f"LAB03_3_SESSION: {session}", flush=True)
    print("No FPGA programming/reset is performed. Close all Chrome Web Serial tabs.", flush=True)
    failed = False
    for index, cmd in enumerate(commands * args.rounds, start=1):
        print(f"[{index}/{len(commands) * args.rounds}] LED command {cmd} ...", flush=True)
        row = {"index": index, "requested_command": cmd, "command": None,
               "events": None, "fetches": None, "led_write": None,
               "expected_led_write": f"0x{expected_led_write(cmd):08X}",
               "status": "FAIL", "sha256": None, "raw_file": None,
               "console_file": f"console/run_{index:03d}_led_{cmd}.txt", "utc": utc_now(),
               "flags": {}, "error": None}
        output = ""
        try:
            process = subprocess.run(
                [args.pwsh, "-NoLogo", "-NoProfile", "-NonInteractive", "-File", str(probe),
                 "-PortName", args.port, "-CaptureNew", "-Led", str(cmd)],
                cwd=repo, text=True, encoding="utf-8", errors="replace",
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
                timeout=args.timeout_sec,
            )
            output = process.stdout
            if process.returncode != 0:
                raise RuntimeError(f"Probe exit code={process.returncode}")
            parsed = parse_probe_output(output)
            row["command"] = parsed["command"]
            row["events"] = parsed["events"]
            row["fetches"] = parsed["fetches"]
            row["led_write"] = f"0x{parsed['led_write']:08X}"
            row["flags"] = parsed["flags"]
            problems = validate_parsed(parsed, cmd)
            if problems:
                raise ValueError("; ".join(problems))
            dump = Path(parsed["dump_path"])
            if not dump.is_absolute():
                dump = repo / dump
            if not dump.is_file():
                raise FileNotFoundError(f"Reported raw UART dump is missing: {dump}")
            raw_relative = Path("raw") / f"run_{index:03d}_led_{cmd}.txt"
            raw_dest = session / raw_relative
            shutil.copyfile(dump, raw_dest)
            if raw_dest.stat().st_size == 0:
                raise ValueError("The archived UART dump is empty")
            row["raw_file"] = raw_relative.as_posix()
            row["sha256"] = sha256_file(raw_dest)
            row["status"] = "PASS"
            print(f"  PASS events={row['events']} fetches={row['fetches']} "
                  f"LED_WRITE={row['led_write']}", flush=True)
        except subprocess.TimeoutExpired as exc:
            output = (exc.stdout or b"")
            if isinstance(output, bytes):
                output = output.decode("utf-8", "replace")
            row["error"] = f"Probe timeout after {args.timeout_sec}s"
            failed = True
        except (OSError, RuntimeError, ValueError, FileNotFoundError) as exc:
            row["error"] = str(exc)
            failed = True
        finally:
            (session / row["console_file"]).write_text(output, encoding="utf-8")
            if row["error"]:
                print(f"  FAIL: {row['error']}", file=sys.stderr, flush=True)
            rows.append(row)
            write_results(session, rows, manifest)
        if failed:
            print("Stopped at first failure; evidence is preserved.", file=sys.stderr)
            break
        if args.gap_ms and index < len(commands) * args.rounds:
            time.sleep(args.gap_ms / 1000)
    errors = write_results(session, rows, manifest)
    print(f"LAB03_3_{'CAMPAIGN_FAIL' if (failed or errors) else 'CAPTURE_MMIO_PASS'}: "
          f"{len(rows)} runs; report={session / 'report.md'}")
    return 1 if (failed or errors) else 0


def do_audit(args: argparse.Namespace) -> int:
    session = Path(args.session).expanduser().resolve()
    manifest = json.loads((session / "manifest.json").read_text(encoding="utf-8"))
    rows = read_results(session)
    errors = write_results(session, rows, manifest)
    print((session / "report.md").read_text(encoding="utf-8"))
    return 1 if errors else 0


def make_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    run = sub.add_parser("run", help="Capture repeated hardware snapshots via LAB-03.2 probe")
    run.add_argument("--port", default="COM10", help="Previously identified board UART port")
    run.add_argument("--probe", help="Path to local probe_lab03_2_serial.ps1")
    run.add_argument("--bitstream", required=True, help="Existing .fs, fingerprinted but NOT flashed")
    run.add_argument("--user-code", default=None,
                     help="Optional operator-reported Gowin User Code (not independently verified)")
    run.add_argument("--rounds", type=int, default=3)
    run.add_argument("--sequence", default="4,0,4,0")
    run.add_argument("--gap-ms", type=int, default=300)
    run.add_argument("--timeout-sec", type=int, default=45)
    run.add_argument("--pwsh", default="pwsh", help="PowerShell 7 executable")
    run.add_argument("--output-dir", help="Default: 01-PicoRV32/build/lab03_3")
    audit = sub.add_parser("audit", help="Re-verify archived hashes and metadata offline")
    audit.add_argument("session", help="Path to campaign_NNNN directory")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = make_parser().parse_args(argv)
    try:
        return do_run(args) if args.action == "run" else do_audit(args)
    except (OSError, ValueError, FileNotFoundError, json.JSONDecodeError) as exc:
        print(f"LAB03_3_SETUP_FAIL: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
