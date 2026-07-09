#!/usr/bin/env python3
"""Capture une page HTML locale en PNG pleine page.
Usage: python shot.py <fichier.html> <sortie.png> [largeur]
"""
import sys
from pathlib import Path
from playwright.sync_api import sync_playwright

html = Path(sys.argv[1]).resolve()
out = sys.argv[2]
width = int(sys.argv[3]) if len(sys.argv) > 3 else 1380

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": width, "height": 1000})
    page.goto(html.as_uri())
    page.wait_for_timeout(1800)  # laisser charger les webfonts
    page.screenshot(path=out, full_page=True)
    browser.close()
print(f"ok -> {out}")
