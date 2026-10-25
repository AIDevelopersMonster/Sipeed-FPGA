#!/usr/bin/env python3
"""Check HTTP delivery, Content-Type and bundled CSS for LAB-03 Observatory."""
from __future__ import annotations
from functools import partial
from http.server import ThreadingHTTPServer
from pathlib import Path
import sys
import tempfile
import shutil
import threading
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from serve import ObservatoryHandler, audit_assets  # noqa: E402


def main() -> None:
    statuses = audit_assets(ROOT)
    assert len(statuses) == 12
    server = ThreadingHTTPServer(('127.0.0.1', 0), partial(ObservatoryHandler, directory=str(ROOT)))
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    base = f'http://127.0.0.1:{server.server_address[1]}'
    resources = [('/', 'text/html'), ('/src/styles.css', 'text/css'),
                 ('/src/app.mjs', 'text/javascript'), ('/src/trace-core.mjs', 'text/javascript'),
                 ('/src/instruction-catalog.mjs', 'text/javascript'),
                 ('/data/campaign.json', 'application/json'),
                 ('/methodics/LAB03_METHODICAL_RU.md', 'text/markdown'),
                 ('/methodics/ISA_REAL_DATA_RU.md', 'text/markdown'), ('/__health', 'application/json')]
    try:
        for uri, expected in resources:
            with urlopen(Request(base + uri, method='GET'), timeout=5) as r:
                assert r.status == 200, (uri, r.status)
                assert r.headers.get('Content-Type', '').startswith(expected), (uri, r.headers)
                assert r.headers.get('Cache-Control') == 'no-store, max-age=0'
                data = r.read()
                assert len(data) > 20, uri
                print(f'HTTP_RESOURCE_PASS: {uri} {r.status} {r.headers.get("Content-Type")} bytes={len(data)}')
        print(f'LAB03_OBSERVATORY_HTTP_ASSET_PASS: resources={len(resources)}')
        with tempfile.TemporaryDirectory(prefix='lab03_obs_bad_assets_') as temp:
            damaged = Path(temp) / 'observatory'
            shutil.copytree(ROOT, damaged, ignore=shutil.ignore_patterns('__pycache__'))
            css = damaged / 'src/styles.css'
            original = css.read_bytes()
            css.unlink()
            try:
                audit_assets(damaged)
                raise AssertionError('missing stylesheet incorrectly accepted')
            except RuntimeError as error:
                assert 'ASSET_MISSING' in str(error)
            css.write_bytes(original + b'/*CORRUPTED*/')
            try:
                audit_assets(damaged)
                raise AssertionError('corrupted stylesheet incorrectly accepted')
            except RuntimeError as error:
                assert 'ASSET_HASH_FAIL' in str(error)
            print('LAB03_OBSERVATORY_NEGATIVE_TESTS_PASS: missing/corrupt CSS refused')
    finally:
        server.shutdown()
        server.server_close()
        worker.join(timeout=5)


if __name__ == '__main__':
    main()
