#!/usr/bin/env python3
"""Import only SHA256-verified public Zenodo PDF assets for UDP FPGA article.

This file never generates/replaces article content. It downloads the author's
published Zenodo record (or a zip contained therein) and selects the exact
two locally verified version 0.2 PDFs. On mismatch, FAIL CLOSED.
"""
import hashlib
import io
import json
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen
import zipfile

RECORD_ID = "24482348"
RECORD_API = f"https://zenodo.org/api/records/{RECORD_ID}"
DEST = Path("docs/education/udp-fpga")
EXPECTED = {
    "UDP_Protocol_FPGA_RU_Zenodo_v0.2.pdf":
        "ce15173b1397d0954db74f76546be89cb39c8dc675f429c64b8d06653f7d7f95",
    "UDP_Protocol_FPGA_EN_Zenodo_v0.2.pdf":
        "4d736e76d1797537e6f7301a8d88b0bb0421639840394463b0da4d0d9ae308cd",
}
MAX_BYTES = 20 * 1024 * 1024


def fetch(url):
    req = Request(url, headers={"User-Agent": "Sipeed-FPGA-Zenodo-PDF-Archive/1.0",
                                "Accept": "application/json,application/pdf,application/zip,*/*"})
    with urlopen(req, timeout=35) as response:
        data = response.read(MAX_BYTES + 1)
    if len(data) > MAX_BYTES:
        raise ValueError("Remote asset too large")
    return data


def sha(data):
    return hashlib.sha256(data).hexdigest()


def try_asset(data, label, found):
    for name, digest in EXPECTED.items():
        if sha(data) == digest:
            if not data.startswith(b"%PDF-"):
                raise ValueError(f"{label} has matching hash but no PDF signature")
            if name in found and found[name] != data:
                raise ValueError("Conflicting PDF bytes")
            found[name] = data
            print(f"VERIFIED {name}: {len(data)} bytes, {digest}")
            return
    if data.startswith(b"PK\\x03\\x04") or zipfile.is_zipfile(io.BytesIO(data)):
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            for info in z.infolist():
                if info.is_dir() or info.file_size > MAX_BYTES:
                    continue
                if not (info.filename.lower().endswith(".pdf")):
                    continue
                try_asset(z.read(info), f"{label}!{info.filename}", found)
    else:
        print(f"SKIP {label}: SHA256 {sha(data)} not matching pinned PDFs")


def main():
    print(f"Fetching official Zenodo record: {RECORD_API}")
    data = json.loads(fetch(RECORD_API))
    files = data.get("files")
    if isinstance(files, dict):
        files = list(files.values())
    if not isinstance(files, list) or not files:
        raise RuntimeError("Zenodo response lists no files; cannot archive PDF")
    found = {}
    failures = []
    for f in files:
        key = f.get("key") or f.get("filename") or ""
        links = f.get("links") or {}
        url_candidates = []
        for k in ("content", "self", "download"):
            if links.get(k):
                url_candidates.append(links[k])
        if key:
            url_candidates.extend([
                f"https://zenodo.org/api/records/{RECORD_ID}/files/{quote(key, safe='')}/content",
                f"https://zenodo.org/records/{RECORD_ID}/files/{quote(key, safe='')}?download=1",
            ])
        for url in dict.fromkeys(url_candidates):
            try:
                blob = fetch(url)
                try_asset(blob, key or url, found)
                break
            except (HTTPError, URLError, TimeoutError, ValueError) as ex:
                failures.append(f"{key}: {ex}")
                continue
    missing = set(EXPECTED) - set(found)
    if missing:
        print("\n".join(failures))
        raise RuntimeError(f"Official record does not contain matching PDF(s): {sorted(missing)}")
    DEST.mkdir(parents=True, exist_ok=True)
    for name, blob in found.items():
        target = DEST / name
        if target.exists():
            old = target.read_bytes()
            if old != blob:
                raise RuntimeError(f"Refusing overwrite of different existing PDF: {target}")
            print(f"EXISTS {target}")
            continue
        target.write_bytes(blob)
        assert sha(target.read_bytes()) == EXPECTED[name]
        print(f"ARCHIVED {target}")
    print("OK: exactly verified PDFs staged; no FPGA source or bitstream touched")


if __name__ == "__main__":
    main()
