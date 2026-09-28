#!/usr/bin/env python3
"""Milestone 2 + 3 web preview screenshots (390x844 @2x, in-app layout) -> compare/web/*.png
Scenes (each _en / _ti): unit_top, unit_games, unit_game (match game started, seeded shuffle), unit_questions (question 1
answered wrong and checked), exam (practice with an option picked), result, mistakes, nex (notes-mistake retry).
The same scenes are rendered by test/screenshots_test.dart (group 'm2m3').
    python3 tool/shoot_web_m2.py [/workspace/Junior-preview-latest.html]"""
import asyncio, json, os, sys
from playwright.async_api import async_playwright
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1] if len(sys.argv) > 1 else '/workspace/Junior-preview-latest.html'
OUT = os.path.join(HERE, 'compare', 'web')
BID, UID = 'science_8', 'sci8-u1'
EXAM = 'science-2019-g8'
QIDS = [f'{EXAM}-p1-q{i:02d}' for i in range(1, 51)]
MULBERRY = "function(s){let a=s>>>0;return function(){a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}"

def state(lang, **kw):
    s = {'v': 1, 'lang': lang, 'theme': 'light', 'best': {}, 'mistakes': {}, 'run': None, 'notes': {'read': {}, 'games': {}, 'ex': {}, 'last': None}}
    s.update(kw)
    return s

SEED_RUN = lambda: {'qids': QIDS, 'i': 3, 'ans': {QIDS[3]: 'B'}, 'res': {}, 'checked': False, 'done': False, 'mode': 'paper', 'examId': EXAM, 'subj': 'science'}
DONE_RUN = lambda: {'qids': QIDS, 'i': 49, 'ans': {}, 'res': {}, 'checked': True, 'done': True, 'mode': 'paper', 'examId': EXAM, 'subj': 'science', 'right': 38, 'total': 50, 'stars': 2}
MIST = {QIDS[0]: EXAM, QIDS[1]: EXAM, 'social-studies-2016-g8-p1-q01': 'social-studies-2016-g8'}
NMIST = {'science_8|sci8-u1-q1': {'b': 'science_8', 'u': 'sci8-u1', 'q': 'sci8-u1-q1', 't': 1}, 'science_8|sci8-u1-q2': {'b': 'science_8', 'u': 'sci8-u1', 'q': 'sci8-u1-q2', 't': 2}}

async def main():
    os.makedirs(OUT, exist_ok=True)
    async with async_playwright() as p:
        b = await p.chromium.launch()
        ctx = await b.new_context(viewport={'width': 390, 'height': 844}, device_scale_factor=2, is_mobile=True, has_touch=True)
        pg = await ctx.new_page()
        await pg.goto('file://' + SRC + '?app=1')

        async def boot(s):
            await pg.evaluate(f"localStorage.setItem('junior:v1', {json.dumps(json.dumps(s))})")
            await pg.reload(); await pg.wait_for_timeout(700)

        async def shot(name):
            await pg.wait_for_timeout(900)
            await pg.screenshot(path=f'{OUT}/{name}.png'); print('shot', name)

        for lang in ('en', 'ti'):
            await boot(state(lang))
            await pg.evaluate(f"APP.notes.openUnit('{BID}', '{UID}')"); await shot(f'unit_top_{lang}')
            await boot(state(lang))
            await pg.evaluate(f"APP.notes.openUnit('{BID}', '{UID}', 'sec-games')"); await pg.wait_for_timeout(900)
            await pg.evaluate("document.getElementById('sec-games').scrollIntoView({block: 'start'})"); await shot(f'unit_games_{lang}')
            await boot(state(lang))
            await pg.evaluate(f"APP.notes.openUnit('{BID}', '{UID}')"); await pg.wait_for_timeout(400)
            await pg.evaluate(f"Math.random = ({MULBERRY})(7); APP.notes.startGame('{BID}', '{UID}', '{UID}-g2')"); await pg.wait_for_timeout(900)
            # re-scroll once the page is fully laid out (the first scroll runs before late layout above it)
            await pg.evaluate(f"document.querySelector('[data-gw=\"{UID}-g2\"]').closest('.gcard').scrollIntoView({{block: 'start'}})"); await shot(f'unit_game_{lang}')
            await boot(state(lang))
            await pg.evaluate(f"APP.notes.openUnit('{BID}', '{UID}', 'sec-questions')"); await pg.wait_for_timeout(500)
            await pg.evaluate("""() => { const c = document.querySelector('.qcard'); c.querySelector('[data-xo="0"]').click(); }""")
            await pg.wait_for_timeout(200)
            await pg.evaluate("""() => { document.querySelector('.qcard [data-act="qCheck"]').click(); }""")
            await pg.wait_for_timeout(900)
            await pg.evaluate("document.getElementById('sec-questions').scrollIntoView({block: 'start'})"); await shot(f'unit_questions_{lang}')
            await boot(state(lang, run=SEED_RUN()))
            await pg.evaluate("APP.go('practice')"); await shot(f'exam_{lang}')
            await boot(state(lang, run=DONE_RUN(), best={EXAM: {'stars': 2, 'right': 38, 'total': 50}}))
            await pg.evaluate("APP.go('result')"); await shot(f'result_{lang}')
            await boot(state(lang, mistakes=MIST, notes={'read': {}, 'games': {}, 'ex': {}, 'last': None, 'mist': NMIST}))
            await pg.evaluate("APP.tab('mistakes')"); await shot(f'mistakes_{lang}')
            await pg.evaluate(f"APP.notes.startNMist('{BID}', '{UID}')"); await shot(f'nex_{lang}')
        await b.close()

asyncio.run(main())
