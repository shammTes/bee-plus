// Inline games (match, sort, flash, tf, fill, label, builder, form, wordmatch), each played inside its own card on the
// unit page – the web app's game engine (`gameInner` / `gameBody` / `gameDock` / `gameAnswer`).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../data/notes_models.dart';
import '../state/app_state.dart';
import '../theme/notes_styles.dart';
import '../theme/tokens.dart';
import '../widgets/art.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/tx.dart';
import 'cards.dart';
import 'diagram.dart';
import 'rich.dart';
import 'session.dart';
import 'ui.dart';

const gameIcons = {
  'match': 'link',
  'sort': 'boxes',
  'flash': 'cards',
  'tf': 'bolt',
  'fill': 'pen',
  'label': 'pinI',
  'builder': 'boxes',
  'form': 'pen',
  'wordmatch': 'link',
};

String helpOf(AppState s, Game g) =>
    {
      'sort': s.t('sortHelp'),
      'flash': s.t('flashHelp'),
      'tf': s.t('tfHelp'),
      'fill': s.t('fillHelp'),
      'builder': s.t('builderHelp'),
      'form': s.t('formHelp'),
      'match': s.t('matchHelp'),
      'wordmatch': s.t('wordmatchHelp'),
      'label': s.t('labelGameHelp'),
    }[g.type] ??
    '';

// ---------------------------------------------------------------- engine
class GameEngine {
  GameEngine(this.s, this.app, {this.onEnd});
  final GameS s;
  final AppState app;
  final VoidCallback? onEnd;
  Game get g => s.g;

  static GameS start(Game g, Unit u) {
    NotesSession.gs[g.id]?.dispose();
    final s = GameS(g, u);
    NotesSession.gs[g.id] = s;
    return s;
  }

  int stars() => g is MatchGame || g is WordMatchGame ? (s.miss <= 1 ? 3 : (s.miss <= 3 ? 2 : 1)) : math.max(1, starsFor(s.right, s.total));

  void end() {
    s.stopTimer();
    final st = stars();
    app.gameDone(g.id, st);
    s.over = (stars: st, right: g is MatchGame || g is WordMatchGame ? s.total : s.right, total: s.total);
    s.changed();
    onEnd?.call();
  }

  /// tf: the 12 s timer of the current statement (restarted when the card is shown again)
  void startTimer() {
    final tg = g;
    if (tg is! TfGame || s.fb != null || s.over != null || s.i >= s.total) return;
    s.stopTimer();
    final t0 = DateTime.now(), dur = (tg.seconds <= 0 ? 12 : tg.seconds) * 1000;
    s.timeLeft = 1;
    s.timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final left = 1 - DateTime.now().difference(t0).inMilliseconds / dur;
      s.timeLeft = math.max(0, left);
      if (left <= 0) {
        s.stopTimer();
        answer(null);
      } else {
        s.changed();
      }
    });
  }

  /// x: tf bool | null (time up) | sort group id | fill / form choice | label pin index
  void answer(Object? x) {
    if (s.fb != null) return;
    switch (g) {
      case TfGame(:final items):
        s.stopTimer();
        final it = items[s.order[s.i]], ok = x == it.answer;
        if (ok) s.right++;
        s.fb = GameFb(ok: ok, late: x == null);
      case SortGame(:final items):
        final it = items[s.order[s.i]], ok = x == it.$2;
        if (ok) s.right++;
        s.fb = GameFb(ok: ok, bin: x as String);
      case FillGame(:final items):
        final it = items[s.order[s.i]];
        if (x == it.answer) {
          if (s.tried == null) s.right++;
          s.fb = GameFb(ok: true);
        } else {
          s.tried = [...?s.tried, x!];
        }
      case FormGame(:final items):
        final it = items[s.order[s.i]], ok = x == it.answer;
        if (ok) s.right++;
        s.fb = GameFb(ok: ok, pick: x as String);
      case LabelGame():
        final k = s.order[s.i];
        if (x == k) {
          if (s.tried == null) s.right++;
          s.fb = GameFb(ok: true);
        } else {
          s.tried = [...?s.tried, x!];
        }
      default:
        break;
    }
    s.changed();
  }

  void next() {
    s
      ..i += 1
      ..fb = null
      ..tried = null
      ..pool = null
      ..flip = false
      ..bank = null
      ..line = []
      ..tries = 0;
    if (s.i >= s.total) return end();
    s.changed();
    startTimer();
  }

  void matchTap(String side, int i) {
    final sel = s.sel;
    if (sel == null || sel.side == side) {
      s.sel = (side: side, i: i);
      s.bad = null;
      s.changed();
      return;
    }
    final a = side == 'a' ? i : sel.i, b = side == 'b' ? i : sel.i;
    if (a == b) {
      s.done.add(a);
      s.sel = null;
      s.bad = null;
      s.changed();
      if (s.done.length == s.total) {
        Timer(const Duration(milliseconds: 450), () {
          if (NotesSession.gs[g.id] == s && s.over == null) end();
        });
      }
    } else {
      s.miss++;
      s.bad = (a: a, b: b);
      s.sel = null;
      s.changed();
      Timer(const Duration(milliseconds: 500), () {
        if (s.bad != null && NotesSession.gs[g.id] == s) {
          s.bad = null;
          s.changed();
        }
      });
    }
  }

  // builder
  List<String> tokens(BuilderItem it) => [...it.words, ...it.extra];
  bool get builderFin => s.fb != null && (s.fb!.ok || s.fb!.show);
  void ensureBank() {
    final bg = g;
    if (bg is! BuilderGame || s.bank != null) return;
    final it = bg.items[s.order[s.i]], tok = tokens(it);
    var b = List.generate(tok.length, (i) => i);
    for (var k = 0; k < 6; k++) {
      b = shuffled(b);
      if (b.map((j) => tok[j]).join(' ') != it.words.join(' ')) break;
    }
    s.bank = b;
    s.line = [];
  }

  void bankTap(int k) {
    if (builderFin || s.line.contains(k)) return;
    s.line = [...s.line, k];
    s.fb = null;
    s.changed();
  }

  void lineTap(int j) {
    if (builderFin) return;
    s.line = [...s.line]..removeAt(j);
    s.fb = null;
    s.changed();
  }

  void clear() {
    s.line = [];
    s.fb = null;
    s.changed();
  }

  void check() {
    final it = (g as BuilderGame).items[s.order[s.i]], tok = tokens(it);
    final said = s.line.map((k) => tok[k]).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final ok = said == it.words.join(' ');
    if (ok) {
      if (s.tries == 0) s.right++;
      s.fb = GameFb(ok: true);
    } else {
      s.tries++;
      s.fb = s.tries >= 2 ? GameFb(ok: false, show: true) : GameFb(ok: false);
    }
    s.changed();
  }
}

// ---------------------------------------------------------------- card
class GameCard extends StatefulWidget {
  const GameCard({super.key, required this.ctx, required this.game, this.onEnd});
  final UnitCtx ctx;
  final Game game;
  final VoidCallback? onEnd;
  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  GameS? _s;

  void _attach() {
    final s = NotesSession.gs[widget.game.id];
    if (s == _s) return;
    _s?.removeListener(_changed);
    _s = s;
    _s?.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _attach();
    final s = _s;
    if (s != null && s.over == null && s.timer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _engine(s).startTimer();
      });
    }
  }

  @override
  void dispose() {
    _s?.removeListener(_changed);
    super.dispose();
  }

  GameEngine _engine(GameS s) => GameEngine(s, AppScope.read(context), onEnd: widget.onEnd);

  void _play() {
    final s = GameEngine.start(widget.game, widget.ctx.u);
    setState(_attach);
    _engine(s).startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, g = widget.game, s = _s;
    final best = k.s.gameBest(g.id);
    final head = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        spacing: 14,
        children: [
          DecoratedBox(
            decoration: k.c.numEdge(p.dark ? p.lilac.edge(true) : mix(p.lilac.mid, .6, p.lilac.deep)),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Center(child: k.icon(gameIcons[g.type] ?? 'play', size: 28, color: p.lilac.deep)),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardTitle(g.title, size: 21, bottom: 0),
                if (best != null) Stars(best, palette: p),
              ],
            ),
          ),
        ],
      ),
    );
    final List<Widget> kids;
    if (s == null) {
      kids = [
        head,
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Tx(helpOf(k.s, g), style: ts(18, FontWeight.w700, p.ink2)),
        ),
        ClayButton(label: k.t('play'), icon: 'play', onTap: _play),
      ];
    } else if (s.over != null) {
      kids = [
        head,
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            children: [
              BigStars(s.over!.stars, size: 62, lift: 12),
              Tx(k.t('nRight', {'n': s.over!.right, 't': s.over!.total}), textAlign: TextAlign.center, style: ts(24, FontWeight.w900, p.ink2)),
            ],
          ),
        ),
        ClayButton(label: k.t('playAgain'), icon: 'retry', kind: BtnKind.soft, onTap: _play),
      ];
    } else {
      final e = _engine(s);
      final dock = _dock(k, p, e);
      kids = [
        head,
        _body(context, k, p, e),
        if (dock != null) Padding(padding: const EdgeInsets.only(top: 18), child: dock),
      ];
    }
    return NCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids),
    );
  }

  Widget _gtop(Palette p, String help, String count) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      spacing: 10,
      children: [
        Expanded(child: Tx(help, style: ts(19, FontWeight.w800, p.ink2))),
        Tx(count, style: ts(19, FontWeight.w900, p.ink)),
      ],
    ),
  );

  Widget _flash(Palette p, bool ok, String text, {double top = 14}) => Padding(
    padding: EdgeInsets.only(top: top),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: ok ? p.sage.tile : p.peach.tile, borderRadius: BorderRadius.circular(18)),
      child: RichPara(text, style: ts(19, FontWeight.w800, ok ? p.sage.deep : p.peach.deep), colors: richColors(p)),
    ),
  );

  /// `.card` inside the game (margin 16 0, padding 20)
  Widget _inCard(Widget child, {EdgeInsets padding = const EdgeInsets.all(20), double? minH}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4), // 16px margins collapse with the 12/14px neighbours
    child: NCard(
      padding: padding,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minH ?? 0),
        child: child,
      ),
    ),
  );

  Widget _body(BuildContext context, Kit k, Palette p, GameEngine e) {
    final s = e.s, g = e.g, rc = richColors(p);
    final prog = '${math.min(s.i + (s.fb != null ? 1 : 0), s.total)}/${s.total}';
    final help = helpOf(k.s, g);
    switch (g) {
      case MatchGame():
      case WordMatchGame():
        return _match(k, p, e);
      case SortGame(:final groups, :final items):
        final it = s.i < s.total ? items[s.order[s.i]] : null;
        final tones = [p.sage, p.peach, p.blue];
        final seenItems = s.order.take(s.i + (s.fb != null ? 1 : 0)).map((j) => items[j]).toList();
        final item = it == null
            ? null
            : DecoratedBox(
                decoration: k.c.item(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 96, minWidth: double.infinity),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Center(
                      child: RichPara(it.$1, style: ts(24, FontWeight.w900, p.ink, normal: true), colors: rc, textAlign: TextAlign.center),
                    ),
                  ),
                ),
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _gtop(p, help, prog),
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    for (final (j, gr) in groups.indexed)
                      Expanded(
                        child: DragTarget<String>(
                          onAcceptWithDetails: (_) => e.answer(gr.$1),
                          builder: (context, cand, _) => Press(
                            onTap: () => e.answer(gr.$1),
                            selected: cand.isNotEmpty,
                            deco: k.c.bin(tones[j % 3]),
                            pressedDeco: k.c.bin(tones[j % 3], down: true),
                            dy: 5,
                            constraints: const BoxConstraints(minHeight: 96),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              spacing: 4,
                              children: [
                                Tx(gr.$2, textAlign: TextAlign.center, style: ts(18, FontWeight.w900, tones[j % 3].deep, height: 1.2)),
                                Tx('${seenItems.where((y) => y.$2 == gr.$1).length}', style: ts(15, FontWeight.w800, p.ink2, height: 1.2)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (item != null)
              s.fb != null
                  ? item
                  : Draggable<String>(
                      data: it!.$2,
                      feedback: SizedBox(
                        width: 300,
                        child: Transform.rotate(angle: -3 * math.pi / 180, child: Opacity(opacity: .95, child: item)),
                      ),
                      childWhenDragging: Opacity(opacity: .4, child: item),
                      child: item,
                    ),
            if (s.fb != null && it != null)
              _flash(p, s.fb!.ok, s.fb!.ok ? '${k.t('right')} ' : '${k.t('wrong')} → ${groups.firstWhere((x) => x.$1 == it.$2, orElse: () => (it.$2, it.$2)).$2}'),
          ],
        );
      case FlashGame(:final cards):
        final c = cards[s.order[s.i]];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _gtop(p, help, prog),
            FlipCard(
              on: s.flip,
              onTap: () {
                s.flip = !s.flip;
                s.changed();
              },
              front: DecoratedBox(
                decoration: k.c.face(p.lilac),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 10,
                    children: [
                      Text(c.$1, textAlign: TextAlign.center, style: ts1000(32, p.ink, height: 1.2)),
                      Tx(k.t('flashHelp'), textAlign: TextAlign.center, style: ts(16, FontWeight.w800, p.ink2, normal: true)),
                    ],
                  ),
                ),
              ),
              back: DecoratedBox(
                decoration: k.c.face(p.sage),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Center(
                    child: RichPara(c.$2, style: ts(23, FontWeight.w800, p.ink, height: 1.35), colors: rc, textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
          ],
        );
      case TfGame(:final items):
        final it = items[s.order[s.i]];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _gtop(p, help, prog),
            Container(
              height: 18,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: k.c.timerTrack(),
              clipBehavior: Clip.antiAlias,
              child: Align(
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: s.fb != null ? 0 : s.timeLeft),
                  duration: const Duration(milliseconds: 250),
                  builder: (_, v, _) => FractionallySizedBox(
                    widthFactor: v,
                    heightFactor: 1,
                    child: DecoratedBox(decoration: k.c.timerFill()),
                  ),
                ),
              ),
            ),
            _inCard(
              Center(
                child: RichPara(it.text, style: ts(25, FontWeight.w900, p.ink, height: 1.35), colors: rc, textAlign: TextAlign.center),
              ),
              padding: const EdgeInsets.all(22),
              minH: 170 - 44,
            ),
            if (s.fb != null)
              _flash(
                p,
                s.fb!.ok,
                '${s.fb!.late ? k.t('timeUp') : (s.fb!.ok ? k.t('right') : k.t('wrong'))} ${it.answer ? k.t('true') : k.t('false')}.${it.why != null ? ' ${it.why}' : ''}',
                top: 2,
              ),
          ],
        );
      case FillGame(:final items):
      case FormGame(:final items):
        final it = items[s.order[s.i]], form = g is FormGame;
        final parts = it.text.split('___');
        final full = form ? s.fb != null : (s.fb?.ok ?? false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _gtop(p, help, prog),
            _inCard(
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _fillQ(p, parts, full, it.answer, form),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 18,
              children: [
                for (final ch in it.choices)
                  OptButton(
                    state: form
                        ? (s.fb == null ? OptState.normal : (ch == it.answer ? OptState.correct : (ch == s.fb!.pick ? OptState.wrongChosen : OptState.dim)))
                        : (s.fb != null && ch == it.answer ? OptState.correct : ((s.tried ?? const []).contains(ch) ? OptState.dim : OptState.normal)),
                    onTap: s.fb != null ? null : () => e.answer(ch),
                    child: Tx(ch, style: optStyle(p)),
                  ),
              ],
            ),
            if (form && s.fb != null) _flash(p, s.fb!.ok, '${s.fb!.ok ? k.t('right') : k.t('wrong')}${it.why != null ? ' ${it.why}' : ''}'),
          ],
        );
      case LabelGame(:final diagram):
        final d = e.s.u.diagrams[diagram], path = widget.ctx.pathOf(diagram);
        if (d == null || path == null) return const SizedBox.shrink();
        final kk = s.order[s.i];
        final pool = s.pool ??= () {
          final others = shuffled(List.generate(d.pins.length, (i) => i).where((i) => i != kk).toList()).take(3).toList();
          return shuffled([kk, ...others]);
        }();
        final prev = s.order.take(s.i).toSet();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _gtop(p, k.t('labelHelp', {'n': kk + 1}), '${s.i}/${s.total}'),
            DiagramFig(
              path: path,
              diagram: d,
              look: (i, _) => i == kk ? (s.fb != null ? PinLook.seen : PinLook.ask) : (prev.contains(i) ? PinLook.seen : PinLook.hidden),
              onPin: (_, _) {},
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                for (final j in pool)
                  OptButton(
                    state: s.fb != null && j == kk ? OptState.correct : ((s.tried ?? const []).contains(j) ? OptState.wrongChosen : OptState.normal),
                    minHeight: 60,
                    onTap: s.fb != null ? null : () => e.answer(j),
                    child: Tx(d.pins[j].text, style: optStyle(p)),
                  ),
              ],
            ),
          ],
        );
      case BuilderGame(:final items):
        e.ensureBank();
        final it = items[s.order[s.i]], tok = e.tokens(it), fin = e.builderFin;
        final fb = s.fb;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _gtop(p, help, prog),
            if (it.hint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RichPara(it.hint!, style: ts(19, FontWeight.w700, p.ink2), colors: rc),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Container(
                constraints: const BoxConstraints(minHeight: 88),
                padding: const EdgeInsets.all(12),
                decoration: k.c.sunk(fb == null ? p.surface2 : (fb.ok ? p.sage.tile : p.peach.tile), radius: 24, dx: 2, dy: 3, blur: 7, a: .22),
                child: s.line.isEmpty
                    ? SizedBox(
                        height: 64,
                        child: Center(child: Tx(k.t('builderHelp'), textAlign: TextAlign.center, style: ts(18, FontWeight.w800, p.ink2))),
                      )
                    : Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [for (final (j, kx) in s.line.indexed) _wtile(k, p, tok[kx], inLine: true, onTap: fin ? null : () => e.lineTap(j))],
                      ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final kx in s.bank!)
                  Visibility(
                    visible: !s.line.contains(kx),
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: _wtile(k, p, tok[kx], onTap: fin || s.line.contains(kx) ? null : () => e.bankTap(kx)),
                  ),
              ],
            ),
            if (fb != null)
              _flash(
                p,
                fb.ok,
                '${fb.ok ? k.t('right') : (fb.show ? '${k.t('rightAnswer')}:' : k.t('tryAgain'))} ${fin ? it.words.join(' ') : ''}${fin && it.why != null ? '\n${it.why}' : ''}',
              ),
          ],
        );
    }
  }

  Widget _fillQ(Palette p, List<String> parts, bool full, String answer, bool form) {
    final st = ts(23, FontWeight.w800, p.ink, height: 1.5), rc = richColors(p);
    return Text.rich(
      TextSpan(
        children: [
          ...RichSpans.of(parts[0], st, rc),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Blank(full: full, child: full ? (form ? RichPara('[[$answer]]', style: st.copyWith(color: p.sage.deep), colors: rc, hx: true) : Tx(answer, style: st.copyWith(color: p.sage.deep))) : Tx('\u00a0', style: st)),
          ),
          if (parts.length > 1) ...RichSpans.of(parts[1], st, rc),
        ],
      ),
      style: st,
      strutStyle: strutOf(st),
    );
  }

  Widget _wtile(Kit k, Palette p, String text, {bool inLine = false, VoidCallback? onTap}) {
    final b = inLine ? p.butter.tile : p.surface, e = inLine ? p.butter.mid : p.edgeN;
    final child = Tx(text, textAlign: TextAlign.center, style: ts(22, FontWeight.w900, p.ink, normal: true));
    return Press(
      onTap: onTap,
      enabled: onTap != null,
      deco: k.c.wtile(b, e),
      pressedDeco: k.c.wtile(b, e, down: true),
      dy: 4,
      constraints: const BoxConstraints(minHeight: 56, minWidth: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );
  }

  Widget _match(Kit k, Palette p, GameEngine e) {
    final s = e.s, rc = richColors(p), wm = e.g is WordMatchGame;
    Widget tile(int i, String side, {EdgeInsets? pad, double? minH, double fs = 18, FontWeight fw = FontWeight.w900, TextAlign align = TextAlign.center, bool wide = true}) {
      final done = s.done.contains(i), sel = s.sel != null && s.sel!.side == side && s.sel!.i == i;
      final bad = s.bad != null && (side == 'a' ? s.bad!.a : s.bad!.b) == i;
      final t = done ? p.sage : (sel ? p.blue : (bad ? p.peach : null));
      final bcol = t?.tile ?? p.surface, ecol = t?.mid ?? p.edgeN;
      final down = done || sel;
      final text = side == 'a' ? s.pairs![i].$1 : s.pairs![i].$2;
      Widget w = Press(
        onTap: done ? null : () => e.matchTap(side, i),
        enabled: !done,
        selected: down,
        deco: down ? k.c.tile(bcol, ecol, down: true, ring: true) : k.c.tile(bcol, ecol),
        pressedDeco: k.c.tile(bcol, ecol, down: true, ring: down),
        dy: 5,
        constraints: BoxConstraints(minHeight: minH ?? 72, minWidth: wide ? double.infinity : 0),
        padding: pad ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Align(
          alignment: align == TextAlign.left ? Alignment.centerLeft : Alignment.center,
          widthFactor: wide ? null : 1,
          heightFactor: 1,
          child: RichPara(text, style: ts(fs, fw, p.ink, height: 1.25), colors: rc, textAlign: align),
        ),
      );
      if (bad) w = Shake(child: w);
      return done ? Opacity(opacity: .75, child: w) : w;
    }

    final top = _gtop(p, k.t(wm ? 'wordmatchHelp' : 'matchHelp'), '${s.done.length}/${s.total}');
    if (wm) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          top,
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [for (final i in s.left) tile(i, 'a', pad: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), minH: 60, fs: 21, wide: false)],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              for (final i in s.rightO) tile(i, 'b', pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), minH: 64, fs: 18, fw: FontWeight.w800, align: TextAlign.left),
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        top,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 14,
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 14, children: [for (final i in s.left) tile(i, 'a')]),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 14,
                children: [for (final i in s.rightO) tile(i, 'b', fs: 17, fw: FontWeight.w800)],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget? _dock(Kit k, Palette p, GameEngine e) {
    final s = e.s, g = e.g;
    final nextBtn = ClayButton(label: s.i + 1 < s.total ? k.t('next') : k.t('seeResult'), icon: 'next', trailingIcon: true, onTap: e.next);
    switch (g) {
      case FlashGame():
        if (!s.flip) {
          return ClayButton(
            label: k.t('turnCard'),
            icon: 'retry',
            onTap: () {
              s.flip = true;
              s.changed();
            },
          );
        }
        return LayoutBuilder(
          builder: (context, box) => Row(
            spacing: 14,
            children: [
              SizedBox(
                width: (box.maxWidth) * .38,
                child: ClayButton(
                  label: k.t('notYet'),
                  kind: BtnKind.soft,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                  onTap: e.next,
                ),
              ),
              Expanded(
                child: ClayButton(
                  label: k.t('knewIt'),
                  icon: 'check',
                  onTap: () {
                    s.right++;
                    e.next();
                  },
                ),
              ),
            ],
          ),
        );
      case TfGame():
        if (s.fb != null) return nextBtn;
        return Row(
          spacing: 14,
          children: [
            Expanded(
              child: ClayButton(label: k.t('true'), icon: 'check', kind: BtnKind.yes, minHeight: 84, fontSize: 24, onTap: () => e.answer(true)),
            ),
            Expanded(
              child: ClayButton(label: k.t('false'), icon: 'x', kind: BtnKind.nope, minHeight: 84, fontSize: 24, onTap: () => e.answer(false)),
            ),
          ],
        );
      case BuilderGame(:final items):
        if (!e.builderFin) {
          final it = items[s.order[s.i]], n = s.line.length;
          return LayoutBuilder(
            builder: (context, box) => Row(
              spacing: 14,
              children: [
                SizedBox(
                  width: box.maxWidth * .38,
                  child: ClayButton(label: k.t('clear'), icon: 'redo', kind: BtnKind.soft, enabled: n > 0, onTap: e.clear),
                ),
                Expanded(
                  child: ClayButton(label: k.t('check'), icon: 'check', enabled: n == it.words.length, onTap: e.check),
                ),
              ],
            ),
          );
        }
        return nextBtn;
      case SortGame():
      case FillGame():
      case LabelGame():
      case FormGame():
        return s.fb != null ? nextBtn : null;
      default:
        return null;
    }
  }
}

/// `.blank`: dashed underline gap (solid green when filled)
class Blank extends StatelessWidget {
  const Blank({super.key, required this.full, required this.child});
  final bool full;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final p = Kit.of(context).p;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 110),
        child: CustomPaint(
          foregroundPainter: _Underline(full ? p.sage.mid : p.ink2, dashed: !full),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Center(widthFactor: 1, heightFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}

class _Underline extends CustomPainter {
  _Underline(this.c, {required this.dashed});
  final Color c;
  final bool dashed;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = c;
    final y = size.height - 4;
    if (!dashed) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 4), paint);
      return;
    }
    // Chrome: dashes 3× the border width, gaps adjusted so both ends are dashes
    const d = 12.0;
    final n = math.max(1, ((size.width + d) / (2 * d)).round());
    final gap = n > 1 ? (size.width - n * d) / (n - 1) : 0.0;
    for (var i = 0; i < n; i++) {
      canvas.drawRect(Rect.fromLTWH(i * (d + gap), y, n == 1 ? size.width : d, 4), paint);
    }
  }

  @override
  bool shouldRepaint(_Underline o) => o.c != c || o.dashed != dashed;
}

/// 3D flip card (`.flip`), min height 260, .6s spring
class FlipCard extends StatelessWidget {
  const FlipCard({super.key, required this.on, required this.front, required this.back, required this.onTap});
  final bool on;
  final Widget front, back;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: on ? 1 : 0),
      duration: const Duration(milliseconds: 600),
      curve: springCurve,
      builder: (context, v, _) {
        final a = v * math.pi;
        final showBack = a > math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 1 / 1000)
            ..rotateY(a),
          // min-height 260; grows with a long face instead of overflowing (both faces measured, the shown one fills)
          child: SizedBox(
            width: double.infinity,
            child: Stack(
              children: [
                Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 260, minWidth: double.infinity),
                    child: Stack(children: [front, back]),
                  ),
                ),
                Positioned.fill(
                  child: showBack ? Transform(alignment: Alignment.center, transform: Matrix4.rotationY(math.pi), child: back) : front,
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// `@keyframes shake` (.4s)
class Shake extends StatelessWidget {
  const Shake({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 400),
    builder: (_, v, ch) => Transform.translate(offset: Offset(math.sin(v * math.pi * 4) * 6 * (1 - v), 0), child: ch),
    child: child,
  );
}
