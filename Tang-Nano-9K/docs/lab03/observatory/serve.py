#!/usr/bin/env python3
"""LAB-03 Bus Trace Observatory v1.1.0, loopback-only static server.

Fails closed on missing/corrupt CSS, JS and evidence before presenting the UI.
No third-party dependencies, COM access, FPGA programming or network downloads.
"""
from __future__ import annotations

import argparse
from functools import partial
import hashlib
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import mimetypes
from pathlib import Path
import webbrowser

ROOT = Path(__file__).resolve().parent
MANIFEST = ROOT / 'asset-manifest.json'
TEXT_EXT = {'.css', '.mjs', '.json', '.hex', '.md'}
mimetypes.add_type('text/javascript', '.mjs')
mimetypes.add_type('text/css', '.css')
mimetypes.add_type('text/markdown', '.md')


def audit_assets(folder: Path = ROOT) -> list[str]:
    path = folder / 'asset-manifest.json'
    if not path.is_file():
        raise RuntimeError(f'LAB03_OBSERVATORY_ASSET_FAIL: manifest not found: {path}')
    data = json.loads(path.read_text(encoding='utf-8'))
    if data.get('schema') != 'LAB03_OBSERVATORY_ASSETS_v1.1.0':
        raise RuntimeError('LAB03_OBSERVATORY_ASSET_FAIL: wrong asset manifest version')
    files = data.get('files')
    if not isinstance(files, dict) or len(files) != 12:
        raise RuntimeError('LAB03_OBSERVATORY_ASSET_FAIL: incomplete manifest')
    statuses: list[str] = []
    for rel, rec in files.items():
        asset = folder / rel
        if not asset.is_file():
            raise RuntimeError(f'LAB03_OBSERVATORY_ASSET_MISSING: {asset}')
        actual = asset.read_bytes()
        expected = rec['sha256'].lower()
        actual_hash = hashlib.sha256(actual).hexdigest()
        if actual_hash == expected:
            statuses.append(f'EXACT {rel}')
            continue
        if asset.suffix.lower() in TEXT_EXT and b'\r\n' in actual:
            if hashlib.sha256(actual.replace(b'\r\n', b'\n')).hexdigest() == expected:
                statuses.append(f'CRLF_OK {rel}')
                continue
        raise RuntimeError(f'LAB03_OBSERVATORY_ASSET_HASH_FAIL: {rel} SHA256={actual_hash}')
    if not (folder / 'index.html').is_file():
        raise RuntimeError('LAB03_OBSERVATORY_ASSET_MISSING: index.html')
    markup = (folder / 'index.html').read_text(encoding='utf-8')
    stylesheet = (folder / 'src/styles.css').read_text(encoding='utf-8')
    if '<style id="lab03-bundled-css">'+stylesheet+'</style>' not in markup:
        raise RuntimeError('LAB03_OBSERVATORY_ASSET_FAIL: bundled CSS fallback is stale')
    if 'src/app.mjs?v=1.1.0' not in markup:
        raise RuntimeError('LAB03_OBSERVATORY_ASSET_FAIL: app module link missing')
    return statuses


class ObservatoryHandler(SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header('Cache-Control', 'no-store, max-age=0')
        self.send_header('X-Content-Type-Options', 'nosniff')
        super().end_headers()

    def do_GET(self) -> None:
        if self.path in ('/__health', '/__health/'):
            data = json.dumps({'status': 'ok', 'version': '1.1.0',
                               'assets': 12, 'mode': 'archive+optional-web-serial'}).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        else:
            super().do_GET()


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--port', type=int, default=8765)
    p.add_argument('--no-browser', action='store_true')
    p.add_argument('--check-only', action='store_true')
    args = p.parse_args()
    try:
        statuses = audit_assets()
    except (RuntimeError, ValueError, KeyError, OSError, UnicodeError) as exc:
        p.exit(1, f'{exc}\n')
    print(f'LAB03_OBSERVATORY_ASSET_PASS: {len(statuses)} assets; HTML with embedded CSS verified', flush=True)
    for status in statuses:
        print('  '+status, flush=True)
    if args.check_only:
        return
    if not 1024 <= args.port <= 65535:
        p.error('Port must be 1024..65535')
    handler = partial(ObservatoryHandler, directory=str(ROOT))
    try:
        server = ThreadingHTTPServer(('127.0.0.1', args.port), handler)
    except OSError as exc:
        p.exit(1, f'LAB03_OBSERVATORY_PORT_FAIL: {exc}. '\
               'Close the previous server first or use -Port 8766.\n')
    with server:
        url = f'http://127.0.0.1:{args.port}/'
        print(f'LAB03_OBSERVATORY_READY: {url}', flush=True)
        print('Остановить: Ctrl+C. COM-порт открывается только по нажатию кнопки в браузере.', flush=True)
        if not args.no_browser:
            webbrowser.open(url)
        try:
            server.serve_forever(poll_interval=0.25)
        except KeyboardInterrupt:
            print('\nLAB03_OBSERVATORY_SERVER_STOPPED', flush=True)


if __name__ == '__main__':
    main()
