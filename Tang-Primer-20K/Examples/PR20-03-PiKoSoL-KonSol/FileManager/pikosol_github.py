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
MANIFEST = PROJECT + "/FileManager/verified-apps.json"
MAX_MANIFEST = 32768
MAX_BIN = 12288
SHA_RE = re.compile(r"^[a-f0-9]{64}$")
NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,100}\\.bin$", re.I)


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


def parse_manifest(data):
    obj = json.loads(data)
    if obj.get("schema") != 1 or not isinstance(obj.get("apps"), list):
        raise ValueError("Unknown catalog schema")
    entries = []
    names = set()
    for item in obj["apps"]:
        if not isinstance(item, dict):
            raise ValueError("Invalid catalog entry")
        name, path, digest, size = (item.get(k) for k in ("name", "path", "sha256", "bytes"))
        if not isinstance(name, str) or not NAME_RE.fullmatch(name) or name.lower() == "monitor.bin":
            raise ValueError("Unsafe BIN name")
        if not isinstance(path, str) or not path.startswith(PROJECT + "/FileManager/generated/") and path != PROJECT + "/firmware/demo.bin":
            raise ValueError("Unexpected catalog path")
        if path.rsplit("/", 1)[-1] != name:
            raise ValueError("Name/path mismatch")
        if not isinstance(size, int) or isinstance(size, bool) or not 20 <= size <= MAX_BIN:
            raise ValueError("Invalid BIN length")
        if not isinstance(digest, str) or not SHA_RE.fullmatch(digest):
            raise ValueError("Invalid SHA256")
        if item.get("board_pass") is not True:
            raise ValueError("Only BOARD PASS entries allowed")
        if name.casefold() in names:
            raise ValueError("Duplicate BIN name")
        names.add(name.casefold())
        entries.append(dict(name=name, path=path, sha256=digest, bytes=size))
    return entries


def list_verified(ref="main", fetch=_download):
    return parse_manifest(fetch(raw_url(MANIFEST, ref), MAX_MANIFEST))


def download_verified(entry, cache, demo, *, ref="main", fetch=_download, inspect=None):
    """No overwrite: equal cached file reused, conflicts rejected.

    inspect is the existing PKD1 validator (inspect_binary(path, demo)).
    """
    name = entry["name"]
    if name == "monitor.bin" or not NAME_RE.fullmatch(name):
        raise ValueError("Unsafe BIN name")
    path = entry["path"]
    if path.rsplit("/", 1)[-1] != name:
        raise ValueError("Name/path mismatch")
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
