#!/usr/bin/env python3
"""Optional Playwright smoke test. Self-hosts the offline HTML on localhost."""
from __future__ import annotations
import argparse
import functools
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import threading
from pathlib import Path
from playwright.sync_api import sync_playwright

D = Path(__file__).resolve().parent
class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *args): pass

def main():
    a=argparse.ArgumentParser(description=__doc__)
    a.add_argument('--channel', default='msedge', help='Installed Chromium channel, e.g. msedge, chrome, chromium')
    args=a.parse_args()
    server=ThreadingHTTPServer(('127.0.0.1',0),functools.partial(QuietHandler,directory=str(D)))
    thread=threading.Thread(target=server.serve_forever,daemon=True)
    thread.start()
    try:
        with sync_playwright() as p:
            browser=p.chromium.launch(headless=True,channel=args.channel)
            page=browser.new_page(viewport={'width':1350,'height':900},accept_downloads=True)
            errors=[]
            page.on('pageerror',lambda e:errors.append(str(e)))
            try:
                page.goto(f'http://127.0.0.1:{server.server_port}/PicoRV32_QuizLab_v1.0.html',wait_until='load',timeout=20000)
                assert page.locator('#total').inner_text()=='50'
                assert page.locator('#question').inner_text().strip()
                print('QUIZ_BROWSER_LOAD_PASS')
                page.locator('input[data-i="0"]').first.check()
                page.locator('#check').click()
                assert page.locator('#feedback').inner_text().strip()
                print('QUIZ_BROWSER_TRAINING_PASS')
                page.locator('button[data-page="decoder"]').click()
                for word,typ in [('0x01D2A023','S-type'),('0x048E0C63','B-type'),('0x01C0006F','J-type')]:
                    page.locator(f'button[data-word="{word}"]').click()
                    assert typ in page.locator('#decoded').inner_text(),word
                print('QUIZ_BROWSER_DECODER_PASS')
                page.locator('button[data-page="quiz"]').click()
                page.locator('input[name="mode"][value="exam"]').check()
                page.locator('#examCount').fill('3')
                page.locator('#start').click()
                assert page.locator('#wiki').is_hidden()
                page.once('dialog',lambda d:d.accept())
                page.locator('#finish').click()
                assert 'Последний экзамен' in page.locator('#history').inner_text()
                print('QUIZ_BROWSER_EXAM_PASS')
                with page.expect_download() as d:page.locator('#exportReport').click()
                assert d.value.suggested_filename.endswith('.md')
                print('QUIZ_BROWSER_REPORT_PASS')
                assert not errors,errors
            finally:browser.close()
    finally:
        server.shutdown()
if __name__=='__main__':main()
