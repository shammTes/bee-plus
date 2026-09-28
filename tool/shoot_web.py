#!/usr/bin/env python3
"""Web preview screenshots (390x844 @2x, in-app layout) for the side-by-side comparison -> compare/web/*.png
    python3 tool/shoot_web.py [/workspace/Junior-preview-latest.html]"""
import asyncio, os, sys
from playwright.async_api import async_playwright
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1] if len(sys.argv) > 1 else '/workspace/Junior-preview-latest.html'
OUT = os.path.join(HERE, 'compare', 'web')

async def main():
    os.makedirs(OUT, exist_ok=True)
    async with async_playwright() as p:
        b = await p.chromium.launch()
        ctx = await b.new_context(viewport={'width': 390, 'height': 844}, device_scale_factor=2, is_mobile=True, has_touch=True)
        pg = await ctx.new_page()
        await pg.goto('file://' + SRC + '?app=1')
        for lang in ('en', 'ti'):
            for theme in ('light', 'dark'):
                sfx = lang + ('' if theme == 'light' else '_dark')
                await pg.evaluate(f"localStorage.setItem('junior:v1', JSON.stringify({{v:1, lang:'{lang}', theme:'{theme}', best:{{}}, mistakes:{{}}, run:null, notes:{{read:{{}}, games:{{}}, ex:{{}}, last:null}}}}))")
                await pg.reload(); await pg.wait_for_timeout(900)
                await pg.screenshot(path=f'{OUT}/home_{sfx}.png')
                await pg.click("[data-tab='settings']"); await pg.wait_for_timeout(900)
                await pg.screenshot(path=f'{OUT}/settings_{sfx}.png')
                await pg.click("[data-act='closeSheet']"); await pg.wait_for_timeout(500)
                await pg.click("[data-ngrade='8']"); await pg.wait_for_timeout(900)
                await pg.screenshot(path=f'{OUT}/grade8_{sfx}.png')
                await pg.evaluate("APP.tab('exams')"); await pg.wait_for_timeout(900)
                await pg.screenshot(path=f'{OUT}/exams_{sfx}.png')
                print('shot', sfx)
        await b.close()

asyncio.run(main())
