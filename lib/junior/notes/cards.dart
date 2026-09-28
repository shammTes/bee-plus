// Notes cards (all 14 types), rendered one under the other on the unit page (`cardHTML` in the web app).
import 'package:flutter/widgets.dart';

import '../data/notes_models.dart';
import '../theme/notes_styles.dart';
import '../theme/tokens.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/tx.dart';
import 'diagram.dart';
import 'rich.dart';
import 'session.dart';
import 'ui.dart';

/// what a card needs to know about its unit
class UnitCtx {
  UnitCtx(this.u, this.bid, this.svgPath, {this.lang = 'en'});
  final Unit u;
  final String bid, lang;
  final String Function(String svg) svgPath;
  String? pathOf(String? name) {
    final d = name == null ? null : u.diagrams[name];
    return d == null ? null : svgPath(d.svg);
  }

  /// every SVG file the unit uses (preloaded before the page is shown)
  Iterable<String> get svgPaths => {for (final d in u.diagrams.values) svgPath(d.svg)};
}

TextStyle pStyle(Palette p) => ts(20, FontWeight.w500, p.ink, height: 1.5);

/// one card + its key-word chips (`.ncw`)
class NoteCardView extends StatefulWidget {
  const NoteCardView({super.key, required this.ctx, required this.card, required this.ckey, this.onGloss, this.compact = false});
  final UnitCtx ctx;
  final NoteCard card;
  final String ckey;
  final bool compact;
  final void Function(int i)? onGloss;
  @override
  State<NoteCardView> createState() => _NoteCardViewState();
}

class _NoteCardViewState extends State<NoteCardView> {
  late CardW w = widget.compact ? CardW() : NotesSession.card(widget.ctx.u.id, widget.ckey);
  Unit get u => widget.ctx.u;

  void _set(VoidCallback f) => setState(f);

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, c = widget.card;
    final card = _card(context, k, p, c);
    if (widget.compact) return card;
    final gl = glossFor(u, [
      ...c.body,
      if (c is GrammarCard) ...c.rule,
      if (c is WorkedCard) c.problem,
      if (c is StepsCard) ...c.steps.map((s) => s.text),
      if (c is WorkedCard) ...c.steps.map((s) => s.text),
      if (c is GraphCard) ...c.steps.map((s) => s.text),
      if (c is StatesCard) ...c.states.map((s) => s.text),
    ]);
    if (gl.isEmpty) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [for (final i in gl) Chip(label: u.glossary[i].term, onTap: () => widget.onGloss?.call(i))],
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, Kit k, Palette p, NoteCard c) {
    final rc = richColors(p), ps = pStyle(p);
    Widget paras(List<String> l, {bool hx = false}) => l.isEmpty ? const SizedBox.shrink() : RichParas(l, style: ps, colors: rc, hx: hx);
    final pg = PgRef(c.page);
    NCard base(List<Widget> kids, {Tone? tone, Color? cc, Color? d}) => NCard(
      tone: tone,
      c: cc,
      d: d,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids),
    );
    switch (c) {
      case RememberCard():
        return base(tone: p.butter, [KindLabel('star', k.t('rememberThis')), CardTitle(c.title), paras(c.body), pg]);
      case MnemonicCard():
        return base(tone: p.lilac, [
          KindLabel('tip', k.t('memoryTrick')),
          CardTitle(c.title),
          if (c.letters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 14),
              child: FlexWrap(gap: 10, basis: 90, minW: 84, children: [for (final x in c.letters) _letter(k, p, x)]),
            ),
          paras(c.body),
          pg,
        ]);
      case TableCard():
        return base([CardTitle(c.title), NTable(head: c.head, rows: c.rows), pg]);
      case CheckCard():
        return _check(k, p, c);
      case DiagramCard():
        return _diagram(k, p, c, paras, pg);
      case StepsCard():
        return _steps(k, p, c, pg);
      case StatesCard():
        return _states(k, p, c, paras, pg);
      case GrammarCard():
        return base(tone: p.blue, [
          KindLabel('pen', k.t('grammarRule')),
          CardTitle(c.title),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DecoratedBox(
              decoration: k.c.sunk(p.surface, a: .12),
              child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: paras(c.rule)),
            ),
          ),
          if (c.pattern != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DecoratedBox(
                decoration: k.c.flat(p.butter.tile, radius: 16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: RichPara(c.pattern!, style: ts(20, FontWeight.w900, p.ink, height: 1.35), colors: rc, hx: true, textAlign: TextAlign.center),
                ),
              ),
            ),
          for (final x in c.examples) _example(k, p, x),
          paras(c.body),
          pg,
        ]);
      case VocabCard():
        return _vocab(k, p, c, paras, pg);
      case ReadingCard():
        return _reading(k, p, c, paras, pg);
      case ModelCard():
        return _model(k, p, c, paras, pg);
      case WorkedCard():
        return _worked(k, p, c, paras, pg);
      case GraphCard():
        return _graph(k, p, c, paras, pg);
      case TextCard():
        return base([CardTitle(c.title), paras(c.body), pg]);
    }
  }

  Widget _letter(Kit k, Palette p, MnemonicLetter x) => DecoratedBox(
    decoration: k.c.letter(),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        children: [
          Tx(x.l, textAlign: TextAlign.center, style: ts1000(34, p.lilac.deep, height: 1)),
          Tx(x.w, textAlign: TextAlign.center, style: ts(18, FontWeight.w900, p.ink)),
          Tx(x.m, textAlign: TextAlign.center, style: ts(16, FontWeight.w700, p.ink2, height: 1.25)),
        ],
      ),
    ),
  );

  // ---- quick check
  Widget _check(Kit k, Palette p, CheckCard c) {
    final a = w.ans, rc = richColors(p);
    return NCard(
      tone: p.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KindLabel('why', k.t('quickCheck')),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RichPara(c.q, style: ts(23, FontWeight.w900, p.ink, height: 1.2), colors: rc),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 18,
            children: [
              for (final l in c.options.keys)
                OptButton(
                  state: a == null
                      ? OptState.normal
                      : l == c.answer
                      ? (l == a ? OptState.correctChosen : OptState.correct)
                      : l == a
                      ? OptState.wrongChosen
                      : OptState.dim,
                  letter: l,
                  mark: a != null && l == c.answer ? 'check' : (a != null && l == a ? 'x' : null),
                  onTap: a == null ? () => _set(() => w.ans = l) : null,
                  child: RichPara(c.options[l]!, style: optStyle(p), colors: rc),
                ),
            ],
          ),
          if (a != null)
            ExplainBox(
              icon: 'why',
              title: a == c.answer ? k.t('right') : k.t('why'),
              c: a == c.answer ? p.sage.tile : null,
              d: a == c.answer ? p.sage.deep : null,
              top: 16,
              children: [explainP(context, c.why)],
            ),
          PgRef(c.page),
        ],
      ),
    );
  }

  // ---- diagram (explore / labels / plain)
  Widget _diagram(Kit k, Palette p, DiagramCard c, Widget Function(List<String>, {bool hx}) paras, Widget pg) {
    final d = u.diagrams[c.diagram], path = widget.ctx.pathOf(c.diagram);
    final kids = <Widget>[CardTitle(c.title), paras(c.body)];
    if (d != null && path != null) {
      final pinsOn = c.mode != 'plain';
      kids.add(
        DiagramFig(
          path: path,
          diagram: d,
          showKey: c.show,
          pins: pinsOn,
          look: (i, pn) => pn.id == w.pin ? PinLook.onSeen : (w.seen.contains(pn.id) ? PinLook.seen : PinLook.normal),
          onPin: (i, pn) => _set(() {
            w.pin = pn.id;
            w.seen.add(pn.id);
          }),
        ),
      );
      if (pinsOn && d.pins.isNotEmpty) {
        final cur = w.pin == null ? -1 : d.pins.indexWhere((x) => x.id == w.pin);
        kids.add(_pinLabel(k, p, cur < 0 ? null : cur + 1, cur < 0 ? k.t('tapDots') : d.pins[cur].text));
        final legend = w.legend ?? c.mode == 'labels';
        kids.add(
          ClayButton(
            label: legend ? k.t('hideNames') : k.t('showNames'),
            icon: 'eye',
            kind: BtnKind.soft,
            minHeight: 56,
            fontSize: 19,
            onTap: () => _set(() => w.legend = !legend),
          ),
        );
        if (legend) {
          kids.add(
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: LayoutBuilder(
                builder: (context, box) {
                  final cw = (box.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      for (final (i, pn) in d.pins.indexed)
                        SizedBox(
                          width: cw,
                          child: Row(
                            spacing: 8,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: p.sage.deep, shape: BoxShape.circle),
                                child: Tx('${i + 1}', style: ts(14, FontWeight.w900, white, height: 1)),
                              ),
                              Expanded(
                                child: Tx(pn.text, style: ts(18, FontWeight.w800, p.ink)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          );
        }
      }
    }
    kids.add(pg);
    return NCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids));
  }

  Widget _pinLabel(Kit k, Palette p, int? n, String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: n == null ? p.surface2 : p.butter.tile, borderRadius: BorderRadius.circular(18)),
      child: Row(
        spacing: 10,
        children: [
          if (n != null)
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
              child: Tx('$n', style: ts(16, FontWeight.w900, white, height: 1)),
            ),
          Expanded(
            child: Tx(text, style: ts(20, n == null ? FontWeight.w800 : FontWeight.w900, n == null ? p.ink2 : p.ink)),
          ),
        ],
      ),
    ),
  );

  // ---- step-through
  Widget _stepBar(Kit k, Palette p, int i, int n, void Function(int) go) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: Row(
      spacing: 12,
      children: [
        _cb(k, 'back', i > 0 ? () => go(i - 1) : null),
        Expanded(
          child: Tx(k.t('stepOf', {'i': i + 1, 'n': n}), textAlign: TextAlign.center, style: ts(18, FontWeight.w900, p.ink2)),
        ),
        _cb(k, 'go', i + 1 < n ? () => go(i + 1) : null),
      ],
    ),
  );

  Widget _cb(Kit k, String icon, VoidCallback? tap) => tap == null
      ? Opacity(
          opacity: .4,
          child: DecoratedBox(
            decoration: k.c.cbtn(),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Center(child: k.icon(icon, size: 26, color: k.p.ink)),
            ),
          ),
        )
      : RoundButton(icon: icon, onTap: tap);

  Widget _stepText(Kit k, Palette p, List<Widget> kids) => DecoratedBox(
    decoration: k.c.sunk(p.surface2),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 92, minWidth: double.infinity),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: kids),
      ),
    ),
  );

  TextStyle _stStyle(Palette p) => ts(20, FontWeight.w700, p.ink, height: 1.45);

  Widget _steps(Kit k, Palette p, StepsCard c, Widget pg) {
    final d = u.diagrams[c.diagram], path = widget.ctx.pathOf(c.diagram);
    final i = w.step.clamp(0, c.steps.length - 1), st = c.steps[i];
    return NCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardTitle(c.title),
          if (d != null && path != null)
            DiagramFig(
              path: path,
              diagram: d,
              showKey: st.show,
              look: (_, pn) => st.pins.contains(pn.id) ? PinLook.onSeen : PinLook.normal,
              dim: (_, pn) => st.pins.isNotEmpty && !st.pins.contains(pn.id),
              onPin: (_, _) {},
            ),
          _stepBar(k, p, i, c.steps.length, (j) => _set(() => w.step = j)),
          _stepText(k, p, [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: RichPara(st.text, style: _stStyle(p), colors: richColors(p)),
            ),
            if (st.pins.isNotEmpty && d != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Tx(
                  st.pins.map((id) => d.pins.where((x) => x.id == id).firstOrNull?.text ?? id).join(' · '),
                  style: ts(17, FontWeight.w700, p.ink2, height: 1.45),
                ),
              ),
          ]),
          pg,
        ],
      ),
    );
  }

  // ---- states (slider)
  Widget _states(Kit k, Palette p, StatesCard c, Widget Function(List<String>, {bool hx}) paras, Widget pg) {
    final d = u.diagrams[c.diagram], path = widget.ctx.pathOf(c.diagram);
    final i = w.state.clamp(0, c.states.length - 1), st = c.states[i];
    return NCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardTitle(c.title),
          paras(c.body),
          if (d != null && path != null) DiagramFig(path: path, diagram: d, showKey: st.key, pins: false),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: ClaySlider(value: i, max: c.states.length - 1, onChanged: (v) => _set(() => w.state = v)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (j, s) in c.states.indexed) Chip(label: s.label, blue: true, on: j == i, onTap: () => _set(() => w.state = j)),
              ],
            ),
          ),
          _stepText(k, p, [RichParas([st.text], style: _stStyle(p), colors: richColors(p), gap: 4)]),
          pg,
        ],
      ),
    );
  }

  // ---- grammar example
  Widget _example(Kit k, Palette p, GrammarExample x) {
    final t = x.ok ? p.sage : p.peach, rc = richColors(p);
    final st = ts(20, FontWeight.w700, p.ink, height: 1.4);
    final small = ts(18, FontWeight.w800, p.ink2, height: 1.35);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: t.tile, borderRadius: BorderRadius.circular(18)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(top: 1),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.deep, shape: BoxShape.circle),
              child: k.icon(x.ok ? 'check' : 'x', size: 22, color: white),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichPara(
                    x.text,
                    style: x.ok
                        ? st
                        : st.copyWith(decoration: TextDecoration.lineThrough, decorationThickness: 2, decorationColor: const Color.fromRGBO(168, 65, 42, .6)),
                    colors: rc,
                    hx: true,
                    strikeHx: !x.ok,
                  ),
                  if (x.fix != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          Padding(padding: const EdgeInsets.only(top: 2), child: k.icon('next', size: 20, color: p.ink2)),
                          Expanded(child: RichPara(x.fix!, style: small, colors: rc, hx: true)),
                        ],
                      ),
                    ),
                  if (x.note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: RichPara(x.note!, style: small, colors: rc),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- vocab
  Widget _vocab(Kit k, Palette p, VocabCard c, Widget Function(List<String>, {bool hx}) paras, Widget pg) {
    var ex = c.example;
    if (!ex.contains('[[') && c.word.isNotEmpty) {
      final i = ex.toLowerCase().indexOf(c.word.toLowerCase());
      if (i >= 0) ex = '${ex.substring(0, i)}[[${ex.substring(i, i + c.word.length)}]]${ex.substring(i + c.word.length)}';
    }
    final rc = richColors(p);
    return NCard(
      tone: p.mint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KindLabel('book', k.t('newWord')),
          if (c.title.isNotEmpty) CardTitle(c.title),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Tx(c.word, style: ts1000(36, p.mint.deep, height: 1.15)),
          ),
          if (c.pos != null || c.say != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: c.pos ?? ''),
                    if (c.say != null) TextSpan(text: ' /${c.say}/', style: ts(17, FontWeight.w800, p.ink2)),
                  ],
                ),
                style: ts(16, FontWeight.w900, p.ink2, spacing: .48),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RichPara(c.meaning, style: ts(22, FontWeight.w800, p.ink, height: 1.5), colors: rc),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DecoratedBox(
              decoration: k.c.sunk(p.surface, a: .12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Tx(k.t('example').toUpperCase(), style: ts(15, FontWeight.w900, p.ink2, spacing: .45)),
                    RichPara(ex, style: ts(20, FontWeight.w500, p.ink, height: 1.45), colors: rc, hx: true),
                  ],
                ),
              ),
            ),
          ),
          paras(c.body),
          pg,
        ],
      ),
    );
  }

  // ---- reading
  Widget _reading(Kit k, Palette p, ReadingCard c, Widget Function(List<String>, {bool hx}) paras, Widget pg) {
    final rc = richColors(p);
    return NCard(
      tone: p.butter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KindLabel('book', k.t('reading')),
          CardTitle(c.title),
          if (c.source.isNotEmpty)
            Transform.translate(
              offset: const Offset(0, -4),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Tx(k.t('retoldFrom', {'s': c.source}), style: ts(16, FontWeight.w800, p.ink2, style: FontStyle.italic)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DecoratedBox(
              decoration: k.c.sunk(p.surface, a: .12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: RichParas(c.paras, style: pStyle(p), colors: rc),
              ),
            ),
          ),
          if (c.questions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Tx(k.t('questions'), style: ts(19, FontWeight.w900, p.ink)),
            ),
            for (final (i, q) in c.questions.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(18)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RichPara('**${i + 1}.** ${q.q}', style: ts(19, FontWeight.w800, p.ink, height: 1.4), colors: RichColors(transparent, rc.sage3, rc.peach3)),
                      ),
                      if (w.rq.contains(i))
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8,
                          children: [
                            Padding(padding: const EdgeInsets.only(top: 2), child: k.icon('check', size: 24, color: p.sage.deep)),
                            Expanded(
                              child: RichPara(
                                q.page == null ? q.a : '${q.a} ',
                                style: ts(19, FontWeight.w700, p.ink, height: 1.4),
                                colors: rc,
                              ),
                            ),
                          ],
                        )
                      else
                        ClayButton(
                          label: k.t('showAnswer'),
                          icon: 'eye',
                          kind: BtnKind.soft,
                          minHeight: 52,
                          fontSize: 18,
                          onTap: () => _set(() => w.rq.add(i)),
                        ),
                      if (w.rq.contains(i) && q.page != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 32),
                          child: Tx('· ${k.t('textbookPage', {'n': q.page!})}', style: ts(15, FontWeight.w700, p.ink2)),
                        ),
                    ],
                  ),
                ),
              ),
          ],
          pg,
        ],
      ),
    );
  }

  // ---- model answer
  Widget _model(Kit k, Palette p, ModelCard c, Widget Function(List<String>, {bool hx}) paras, Widget pg) {
    final sp = c.kind == 'speaking', rc = richColors(p);
    final whos = <String>[];
    for (final l in c.lines) {
      if (!whos.contains(l.who)) whos.add(l.who);
    }
    return NCard(
      tone: p.lilac,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KindLabel(sp ? 'talk' : 'pen', k.t(sp ? 'modelSpeaking' : 'modelWriting')),
          CardTitle(c.title),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Tx(k.t('yourTask').toUpperCase(), style: ts(15, FontWeight.w900, p.ink2, spacing: .6)),
                  ),
                  RichParas(c.task, style: pStyle(p), colors: rc),
                ],
              ),
            ),
          ),
          if (c.lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                spacing: 8,
                children: [
                  for (final l in c.lines)
                    Align(
                      alignment: whos.indexOf(l.who) % 2 == 1 ? Alignment.centerRight : Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: .86,
                        alignment: whos.indexOf(l.who) % 2 == 1 ? Alignment.centerRight : Alignment.centerLeft,
                        child: Align(
                          alignment: whos.indexOf(l.who) % 2 == 1 ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                            decoration: BoxDecoration(
                              color: whos.indexOf(l.who) % 2 == 1 ? p.mint.tile : p.surface,
                              borderRadius: whos.indexOf(l.who) % 2 == 1
                                  ? const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(6))
                                  : const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(6), bottomRight: Radius.circular(18)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Tx(l.who, style: ts(14, FontWeight.w900, p.ink2, height: 1.4)),
                                RichPara(l.text, style: ts(19, FontWeight.w700, p.ink, height: 1.4), colors: rc, hx: true),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDF7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border(left: BorderSide(color: p.lilac.deep, width: 6)),
                  boxShadow: [BoxShadow(offset: const Offset(1, 2), blurRadius: 6, color: p.sh(.18))],
                ),
                child: RichParas(c.model, style: ts(19, FontWeight.w700, const Color(0xFF2B2622), height: 1.5), colors: rc, hx: true),
              ),
            ),
          if (c.phrases.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Tx(k.t('usefulPhrases'), style: ts(19, FontWeight.w900, p.ink)),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final x in c.phrases)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: p.butter.tile, borderRadius: BorderRadius.circular(14)),
                      child: RichPara(x, style: ts(18, FontWeight.w800, p.ink), colors: rc, hx: true),
                    ),
                ],
              ),
            ),
          ],
          paras(c.body),
          pg,
        ],
      ),
    );
  }

  // ---- worked example
  Widget _worked(Kit k, Palette p, WorkedCard c, Widget Function(List<String>, {bool hx}) paras, Widget pg) {
    final n = c.steps.length, tryMode = c.mode == 'try', shown = tryMode ? w.shown.clamp(0, n) : n, rc = richColors(p);
    final path = widget.ctx.pathOf(c.diagram), d = c.diagram == null ? null : u.diagrams[c.diagram];
    final key = tryMode && shown > 0 ? c.steps[shown - 1].show : null;
    final wst = ts(20, FontWeight.w500, p.ink, height: 1.45);
    return NCard(
      c: p.surface,
      d: p.mint.deep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KindLabel(tryMode ? 'tip' : 'pen', tryMode ? k.t('tryIt') : k.t('workedEx')),
          CardTitle(c.title),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: p.mint.tile, borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RichParas([c.problem], style: ts(20, FontWeight.w800, p.ink, height: 1.45), colors: rc, gap: 4),
                ],
              ),
            ),
          ),
          if (d != null && path != null) DiagramFig(path: path, diagram: d, showKey: key, pins: false),
          if (c.graph != null) GraphFig(spec: c.graph!, showKey: key),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, s) in c.steps.indexed)
                  if (i < shown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 12,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            margin: const EdgeInsets.only(top: 1),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: p.mint.deep, shape: BoxShape.circle),
                            child: Text('${i + 1}', style: ts1000(17, white, height: 1)),
                          ),
                          Expanded(child: _stepBody(s, wst, rc)),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          if (tryMode && shown < n) ...[
            if (shown == 0) Padding(padding: const EdgeInsets.only(bottom: 10), child: hintText(context, k.t('thinkStep'), top: 0)),
            ClayButton(
              label: k.t('showStep', {'n': shown + 1}),
              icon: 'eye',
              kind: BtnKind.soft,
              minHeight: 56,
              fontSize: 19,
              onTap: () => _set(() => w.shown = shown + 1),
            ),
          ],
          if (shown >= n && c.answer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: p.sage.tile, borderRadius: BorderRadius.circular(18)),
                child: Row(
                  spacing: 10,
                  children: [
                    k.icon('check', size: 28, color: p.sage.deep),
                    Expanded(
                      child: RichPara('${k.t('answer')}: ${c.answer}', style: ts(21, FontWeight.w900, p.ink), colors: rc),
                    ),
                  ],
                ),
              ),
            ),
          paras(c.body),
          pg,
        ],
      ),
    );
  }

  Widget _stepBody(StepItem s, TextStyle st, RichColors rc) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (s.text.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 2), child: RichPara(s.text, style: st, colors: rc)),
      if (s.math != null) RichPara('\$\$${s.math}\$\$', style: st, colors: rc),
    ],
  );

  // ---- graph
  Widget _graph(Kit k, Palette p, GraphCard c, Widget Function(List<String>, {bool hx}) paras, Widget pg) {
    final has = c.steps.isNotEmpty, i = has ? w.step.clamp(0, c.steps.length - 1) : 0;
    final st = has ? c.steps[i] : null;
    return NCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardTitle(c.title),
          paras(c.body),
          GraphFig(spec: c.graph, showKey: st?.show),
          if (st != null) ...[
            _stepBar(k, p, i, c.steps.length, (j) => _set(() => w.step = j)),
            _stepText(k, p, [_stepBody(st, _stStyle(p), richColors(p))]),
          ],
          pg,
        ],
      ),
    );
  }
}

/// glossary entries whose term / forms are **bold** on the card (max 6)
List<int> glossFor(Unit u, List<String> texts) {
  final words = <String>{};
  for (final m in RegExp(r'\*\*(.+?)\*\*').allMatches(texts.join(' '))) {
    words.add(m[1]!.toLowerCase());
  }
  if (words.isEmpty) return const [];
  final out = <int>[];
  for (final (i, g) in u.glossary.indexed) {
    if ([g.term, ...g.forms].any((n) => words.contains(n.toLowerCase()))) out.add(i);
  }
  return out.take(6).toList();
}

/// `.chip` (butter) / `.chip.blue` (state chips); [on] = pressed in
class Chip extends StatelessWidget {
  const Chip({super.key, required this.label, this.onTap, this.blue = false, this.on = false});
  final String label;
  final VoidCallback? onTap;
  final bool blue, on;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p;
    return Press(
      onTap: onTap ?? () {},
      selected: on,
      deco: k.c.chip(blue: blue),
      pressedDeco: k.c.chipOn(blue: blue),
      dy: 4,
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Tx(label, textAlign: TextAlign.center, style: ts(18, FontWeight.w900, p.ink, normal: true)),
    );
  }
}

/// flex-wrap row of items with `flex: 1 1 basis; min-width: minW` (mnemonic letters)
class FlexWrap extends StatelessWidget {
  const FlexWrap({super.key, required this.children, required this.gap, required this.basis, required this.minW});
  final List<Widget> children;
  final double gap, basis, minW;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wmax = box.maxWidth;
      final lines = <List<Widget>>[];
      var cur = <Widget>[];
      var used = 0.0;
      for (final c in children) {
        final need = (cur.isEmpty ? 0 : gap) + basis;
        if (cur.isNotEmpty && used + need > wmax + .01) {
          lines.add(cur);
          cur = [];
          used = 0;
        }
        used += (cur.isEmpty ? 0 : gap) + basis;
        cur.add(c);
      }
      if (cur.isNotEmpty) lines.add(cur);
      return Column(
        spacing: gap,
        children: [
          for (final l in lines)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: gap,
                children: [for (final c in l) Expanded(child: c)],
              ),
            ),
        ],
      );
    },
  );
}

/// `.ntable`: header row + rows of rounded cells, CSS auto table layout, scrolls sideways when too wide
class NTable extends StatelessWidget {
  const NTable({super.key, required this.head, required this.rows});
  final List<String> head;
  final List<List<String>> rows;

  static String _plain(String s) => s.replaceAll('**', '').replaceAll(RegExp(r'\$([^$]*)\$'), r'$1');

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, rc = richColors(p);
    final n = [head.length, for (final r in rows) r.length].reduce((a, b) => a > b ? a : b);
    TextStyle cell(int j) => ts(18, j == 0 ? FontWeight.w900 : FontWeight.w700, p.ink, height: 1.3);
    final th = ts(16, FontWeight.w900, p.ink2, height: 1.45);
    return LayoutBuilder(
      builder: (context, box) {
        final minC = List.filled(n, 16.0), maxC = List.filled(n, 16.0);
        void measure(String s, int j, TextStyle st) {
          final plain = _plain(s);
          final tp = TextPainter(text: TextSpan(text: plain, style: st), textDirection: TextDirection.ltr)..layout();
          maxC[j] = maxC[j] > tp.width + 16 ? maxC[j] : tp.width + 16;
          for (final wd in plain.split(RegExp(r'\s+'))) {
            final tw = TextPainter(text: TextSpan(text: wd, style: st), textDirection: TextDirection.ltr)..layout();
            if (tw.width + 16 > minC[j]) minC[j] = tw.width + 16;
          }
        }

        for (final (j, h) in head.indexed) {
          measure(h, j, th);
        }
        for (final r in rows) {
          for (final (j, c) in r.indexed) {
            measure(c, j, cell(j));
          }
        }
        final wAvail = box.maxWidth;
        final sMin = minC.fold<double>(0, (a, b) => a + b), sMax = maxC.fold<double>(0, (a, b) => a + b);
        List<double> widths;
        if (sMax <= wAvail) {
          widths = [for (final m in maxC) m + (wAvail - sMax) * m / sMax];
        } else if (sMin >= wAvail) {
          widths = minC;
        } else {
          final span = sMax - sMin;
          widths = [for (var j = 0; j < n; j++) minC[j] + (wAvail - sMin) * (maxC[j] - minC[j]) / (span == 0 ? 1 : span)];
        }
        Widget rowW(List<String> r, {bool header = false}) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < n; j++)
              SizedBox(
                width: widths[j],
                child: header
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Tx(j < r.length ? r[j] : '', style: th),
                      )
                    : null,
              ),
          ],
        );
        final table = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            rowW(head, header: true),
            for (final r in rows) ...[
              const SizedBox(height: 8),
              // one Table per row (no IntrinsicHeight: KaTeX boxes have no dry baseline)
              Table(
                columnWidths: {for (var j = 0; j < n; j++) j: FixedColumnWidth(widths[j])},
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(14)),
                    children: [
                      for (var j = 0; j < n; j++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          child: RichPara(j < r.length ? r[j] : '', style: cell(j), colors: rc),
                        ),
                    ],
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
          ],
        );
        final total = widths.fold<double>(0, (a, b) => a + b);
        if (total <= wAvail + .5) return table;
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: table);
      },
    );
  }
}

/// `.slider`: 18px sunk track, 44px primary thumb, snaps to whole steps
class ClaySlider extends StatelessWidget {
  const ClaySlider({super.key, required this.value, required this.max, required this.onChanged});
  final int value, max;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p;
    return LayoutBuilder(
      builder: (context, box) {
        final wd = box.maxWidth;
        double xOf(int v) => max == 0 ? 0 : v / max * (wd - 44);
        void at(double dx) {
          final v = max == 0 ? 0 : ((dx - 22) / (wd - 44) * max).round().clamp(0, max);
          if (v != value) onChanged(v);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => at(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => at(d.localPosition.dx),
          child: SizedBox(
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 15,
                  height: 18,
                  child: DecoratedBox(decoration: k.c.sunk(p.surface2, radius: 12, dx: 2, dy: 3, blur: 6, a: .28)),
                ),
                Positioned(
                  left: xOf(value),
                  top: 2,
                  width: 44,
                  height: 44,
                  child: DecoratedBox(decoration: k.c.primaryDisc()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
