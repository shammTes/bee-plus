#!/usr/bin/env python3
"""Dump text-line boxes of the web preview screen as JSON: python3 tool/measure_web.py <screen> <lang>  (screen: home|grade8|settings|exams)"""
import asyncio, json, sys
from playwright.async_api import async_playwright
scr, lang = sys.argv[1], sys.argv[2]
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        ctx = await b.new_context(viewport={'width': 390, 'height': 844}, device_scale_factor=2, is_mobile=True, has_touch=True)
        pg = await ctx.new_page()
        await pg.goto('file:///workspace/Junior-preview-latest.html?app=1')
        await pg.evaluate(f"localStorage.setItem('junior:v1', JSON.stringify({{v:1, lang:'{lang}', theme:'light', best:{{}}, mistakes:{{}}, run:null, notes:{{read:{{}}, games:{{}}, ex:{{}}, last:null}}}}))")
        await pg.reload(); await pg.wait_for_timeout(700)
        if scr == 'grade8': await pg.click("[data-ngrade='8']")
        if scr == 'settings': await pg.click("[data-tab='settings']")
        if scr == 'exams': await pg.evaluate("APP.tab('exams')")
        await pg.wait_for_timeout(900)
        r = await pg.evaluate("""(() => { const out = []; const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
          while (w.nextNode()) { const n = w.currentNode, t = n.textContent.trim(); if (!t) continue; const el = n.parentElement; if (el.closest('script,style')) continue;
            const r = document.createRange(); r.selectNodeContents(el); const b = el.getBoundingClientRect(); if (b.bottom < 0 || b.top > 844 || !b.width) continue;
            out.push([t, Math.round(b.left*10)/10, Math.round(b.top*10)/10, Math.round(b.height*10)/10]); } return out; })()""")
        print(json.dumps(r, ensure_ascii=False))
        await b.close()
asyncio.run(main())
