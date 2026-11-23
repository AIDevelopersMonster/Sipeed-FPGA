"""Read-only allowlisted GitHub catalog for PiKoSoL TP20.

Network is used only when explicitly requested. No COM/FPGA operations.
Downloaded BINs go to a new cache file only after SHA256 and PKD1 checks.
"""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
from urllib.request import urlopen

OWNER = "AIDevelopersMonster"
REPO = "Sipeed-FPGA"
PROJECT = "Tang-Primer-20K/Examples/PR20-03-PiKoSoL-KonSol"
MANIFEST = PROJECT + "/FileManager/verified-apps-v2.json"
MAX_MANIFEST = 32768
MAX_BIN = 12288
CATALOG_REF = "main"  # main branch; exact BIN hash and size checked before publishing to cache
SHA_RE = re.compile(r"^[a-f0-9]{64}$")
REQUIRES_RE = re.compile(r"^[A-Z0-9_]{3,48}$")
PART_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,80}$")
NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,100}\.bin$", re.I)
# Keep FPGA configuration requirements explicit: the published startup
# programs stock THLN33. GPIO V3714 BINs are not interchangeable.
GPIO_FOLDERS = (
    PROJECT + "/GPIO-PMOD-V3714/bin/",
    PROJECT + "/RGB-WS2812-PMOD0-SOFTWARE/bin/",
)
BASE_FOLDER = PROJECT + "/FileManager/generated/"


def required_gateware(path, name):
    """Return known FPGA requirement, or None for a new module bin folder.

    Future releases can add PROJECT/<module>/bin/*.bin without a new PC client.
    A new module MUST specify its gateware in the manifest. Exact size, SHA256
    and PKD1 checks are still mandatory. No automatic FPGA programming.
    """
    if not isinstance(path, str) or len(path) > 350:
        raise ValueError("Unexpected catalog path")
    if not path.startswith(PROJECT + "/"):
        raise ValueError("Outside PiKoSoL TP20")
    relative = path[len(PROJECT) + 1:]
    parts = relative.split("/")
    if any(not PART_RE.fullmatch(part) or part in (".", "..") for part in parts):
        raise ValueError("Unsafe catalog path")
    if parts[-1] != name:
        raise ValueError("Name/path mismatch")
    if path == PROJECT + "/firmware/demo.bin":
        return "BASE_TP20"
    if path.startswith(BASE_FOLDER) and path[len(BASE_FOLDER):] == name:
        return "GPIO_V3714" if name.endswith("__GPIO_V3714_ONLY.bin") else "BASE_TP20"
    for prefix in GPIO_FOLDERS:
        if path.startswith(prefix) and path[len(prefix):] == name:
            return "GPIO_V3714"
    if 3 <= len(parts) <= 6 and parts[-2] == "bin":
        return None  # future safe project-local module, explicit 'requires'
    raise ValueError("Unexpected catalog path")


def _download(url, limit):
    # Hard byte cap, including for servers that lie about Content-Length.
    with urlopen(url, timeout=8) as response:
        data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError("GitHub response exceeds size limit")
    return data


def raw_url(path, ref="main"):
    if not re.fullmatch(r"[A-Za-z0-9._/-]+", ref) or ".." in ref:
        raise ValueError("Invalid GitHub ref")
    if not path.startswith(PROJECT + "/") or ".." in path.split("/"):
        raise ValueError("Outside PiKoSoL TP20")
    return f"https://raw.githubusercontent.com/{OWNER}/{REPO}/{ref}/{path}"


def _validate_entry(item, names):
    if not isinstance(item, dict):
        raise ValueError("Invalid catalog entry")
    name, path, digest, size = (item.get(k) for k in ("name", "path", "sha256", "bytes"))
    if not isinstance(name, str) or not NAME_RE.fullmatch(name) or name.lower() == "monitor.bin":
        raise ValueError("Unsafe BIN name")
    known = required_gateware(path, name)
    requirement = item.get("requires", known)
    if not isinstance(requirement, str) or not REQUIRES_RE.fullmatch(requirement):
        raise ValueError("Missing/invalid 'requires' field for this module")
    if known is not None and requirement != known:
        raise ValueError("Conflicting FPGA requirement")
    if not isinstance(size, int) or isinstance(size, bool) or not 20 <= size <= MAX_BIN:
        raise ValueError("Invalid BIN length")
    if not isinstance(digest, str) or not SHA_RE.fullmatch(digest):
        raise ValueError("Invalid SHA256")
    if type(item.get("board_pass")) is not bool:
        raise ValueError("Missing board_pass status")
    if item.get("status") not in ("BOARD_PASS", "OPERATOR_REPORTED", "UNKNOWN"):
        raise ValueError("Unknown verification status")
    if item["board_pass"] != (item["status"] == "BOARD_PASS"):
        raise ValueError("Conflicting verification status")
    if name.casefold() in names:
        raise ValueError("Duplicate BIN name")
    return dict(name=name, path=path, sha256=digest, bytes=size,
                status=item["status"], board_pass=item["board_pass"], requires=requirement)


def parse_manifest(data, *, tolerant=False):
    """Strict by default for tests; tolerate unknown/broken rows when listing.

    One new/corrupt future catalog item must not take down every known item.
    Unsupported top-level schema remains a hard failure.
    """
    obj = json.loads(data)
    if not isinstance(obj, dict) or obj.get("schema") != 1 or not isinstance(obj.get("apps"), list):
        raise ValueError("Unknown catalog schema")
    entries, names = [], set()
    for item in obj["apps"]:
        try:
            clean = _validate_entry(item, names)
        except (ValueError, TypeError):
            if tolerant:
                continue
            raise
        names.add(clean["name"].casefold())
        entries.append(clean)
    if not entries:
        raise ValueError("No compatible BIN entries in GitHub catalog")
    return entries


def list_verified(ref=CATALOG_REF, fetch=_download):
    return parse_manifest(fetch(raw_url(MANIFEST, ref), MAX_MANIFEST), tolerant=True)


def download_verified(entry, cache, demo, *, ref=CATALOG_REF, fetch=_download, inspect=None):
    """No overwrite: equal cached file reused, conflicts rejected.

    inspect is the existing PKD1 validator (inspect_binary(path, demo)).
    """
    name = entry["name"]
    if name == "monitor.bin" or not NAME_RE.fullmatch(name):
        raise ValueError("Unsafe BIN name")
    path = entry["path"]
    if path.rsplit("/", 1)[-1] != name:
        raise ValueError("Name/path mismatch")
    known = required_gateware(path, name)
    requirement = entry.get("requires", known)
    if not isinstance(requirement, str) or not REQUIRES_RE.fullmatch(requirement):
        raise ValueError("Invalid FPGA requirement")
    if known is not None and requirement != known:
        raise ValueError("Conflicting FPGA requirement")
    data = fetch(raw_url(path, ref), MAX_BIN)
    digest = hashlib.sha256(data).hexdigest()
    if len(data) != entry["bytes"] or digest != entry["sha256"]:
        raise ValueError("Downloaded BIN hash/size does not match catalog")
    cache = Path(cache)
    cache.mkdir(parents=True, exist_ok=True)
    destination = cache / name
    if destination.exists():
        if destination.is_symlink() or not destination.is_file():
            raise ValueError("Unsafe destination")
        existing = destination.read_bytes()
        if existing != data:
            raise FileExistsError("Cached BIN differs; no overwrite permitted: " + str(destination))
        if inspect is not None:
            inspect(destination, demo)
        return destination
    fd, temp_path = tempfile.mkstemp(prefix=".pikosol-", suffix=".tmp", dir=str(cache))
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        candidate = Path(temp_path)
        # Existing ABI check before moving the candidate to the visible cache.
        # The validator needs a .bin suffix, so use a dedicated temporary BIN.
        validated = candidate.with_suffix(".bin")
        candidate.rename(validated)
        temp_path = str(validated)
        if inspect is not None:
            inspect(validated, demo)
        # Atomic exclusive creation: never replace another download/user file.
        with destination.open("xb") as out:
            out.write(data)
        return destination
    finally:
        if os.path.exists(temp_path):
            os.unlink(temp_path)
