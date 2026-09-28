// Milestone 3: exam player (`R.practice`), result (`R.result`) and the Paper A / B picker (`R.year`).
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/exam_models.dart';
import '../notes/rich.dart';
import '../notes/session.dart';
import '../notes/ui.dart';
import '../state/app_state.dart';
import '../theme/clay.dart';
import '../theme/notes_styles.dart';
import '../theme/tokens.dart';
import '../widgets/art.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/page.dart';
import '../widgets/tx.dart';
import 'shell.dart';

// ---------------------------------------------------------------- run helpers (web startRun / startExam / startMistakes)
bool gradable(ExamQuestion q) => q.isMcq;

AppTab runTab(AppState s) => s.run?['mode'] == 'mistakes' ? AppTab.mistakes : AppTab.exams;

void startExam(BuildContext context, Paper e) {
  final s = AppScope.read(context), sh = Shell.of(context);
  if (e.questions.isEmpty) return sh.toast(s.t('noQuestions'));
  s.startRun([for (final q in e.questions) q.id], mode: 'paper', examId: e.id, subj: e.subject?.id ?? 'english');
  sh.resetTo(AppTab.exams, const [PracticePage()]);
}

void startRun(BuildContext context, List<String> qids, {required String mode, String? examId, required String subj}) {
  final s = AppScope.read(context);
  s.startRun(qids, mode: mode, examId: examId, subj: subj);
  Shell.of(context).resetTo(mode == 'mistakes' ? AppTab.mistakes : AppTab.exams, const [PracticePage()]);
}

/// practise the exam mistakes of one subject (null = all)
void startMistakes(BuildContext context, String? subj) {
  final s = AppScope.read(context), qid = s.repo.qid;
  final ids = [for (final id in s.mistakes.keys) if (qid[id] != null && (subj == null || qid[id]!.$2.subject?.id == subj)) id];
  if (ids.isEmpty) return;
  startRun(context, ids, mode: 'mistakes', subj: subj ?? qid[ids.first]!.$2.subject?.id ?? 'english');
}

/// `.dock`: fixed at the bottom over a fade to the background (padding 22 20 24; buttons 64 tall, 22px)
class Dock extends StatelessWidget {
  const Dock({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final p = Kit.of(context).p;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [withA(p.bg, 0), p.bg], stops: const [0, .34]),
      ),
      child: Padding(padding: EdgeInsets.fromLTRB(20, 22, 20, 24 + MediaQuery.paddingOf(context).bottom), child: child),
    );
  }
}

/// page with a dock over its bottom (practice, notes retry)
class DockPage extends StatelessWidget {
  const DockPage({super.key, required this.top, required this.children, required this.dock, this.controller});
  final Widget top, dock;
  final List<Widget> children;
  final ScrollController? controller;
  @override
  Widget build(BuildContext context) => PageShell(
    top: top,
    body: Stack(
      children: [
        Positioned.fill(
          child: ScrollConfiguration(
            behavior: const NoGlow(),
            child: SingleChildScrollView(
              controller: controller,
              padding: EdgeInsets.fromLTRB(20, 6, 20, 124 + MediaQuery.paddingOf(context).bottom),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: Dock(child: dock)),
      ],
    ),
  );
}

/// practice top bar: stop (x) · progress bar · "i/n"
class RunTop extends StatelessWidget {
  const RunTop({super.key, required this.frac, required this.count, required this.onStop});
  final double frac;
  final String count;
  final VoidCallback onStop;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p;
    return TopBar(
      children: [
        RoundButton(icon: 'x', onTap: onStop, label: k.t('stop')),
        Expanded(child: PBar(frac)),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 52),
          child: Tx(count, textAlign: TextAlign.right, style: ts(18, FontWeight.w900, p.ink)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- practice
class PracticePage extends StatefulWidget with NoNavPage {
  const PracticePage({super.key});
  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final _scroll = ScrollController();
  final _fbKey = GlobalKey();
  bool? _passOpen;
  String _passFor = '';

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _stop() {
    final s = AppScope.read(context);
    Shell.of(context).openTab(runTab(s));
  }

  void _check(ExamQuestion q, Paper e) {
    final s = AppScope.read(context), r = s.run!;
    if (gradable(q)) {
      final l = (r['ans'] as Map)[q.id] as String?;
      if (l == null) return;
      s.runCheck(q.id, q.isCorrect(l), e.id);
    } else {
      s.runCheck(q.id, null, e.id);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _fbKey.currentContext;
      if (c != null && c.mounted) {
        Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      }
    });
  }

  void _next() {
    final s = AppScope.read(context), qid = s.repo.qid;
    final done = s.runNext(starsFor, (id) => qid[id] != null && gradable(qid[id]!.$1));
    if (done) {
      Shell.of(context).resetTo(runTab(s), const [ResultPage()]);
    } else if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, s = k.s, r = s.run;
    final qid = s.repo.qid;
    if (r == null || qid.isEmpty) return PageShell(top: TopBar(children: [RoundButton(icon: 'x', onTap: _stop)]), body: const SizedBox.shrink());
    final qids = (r['qids'] as List).cast<String>(), i = r['i'] as int, n = qids.length;
    final entry = qid[qids[i]];
    if (entry == null) return PageShell(top: TopBar(children: [RoundButton(icon: 'x', onTap: _stop)]), body: const SizedBox.shrink());
    final (q, e) = entry;
    final ck = r['checked'] == true, chosen = (r['ans'] as Map)[q.id] as String?;
    final key = '${q.id}|$ck';
    if (_passFor != key) {
      _passFor = key;
      _passOpen = !ck;
    }
    final kids = <Widget>[];
    final pass = e.passage(q.passageId);
    if (pass != null) {
      kids.add(_PassageBox(passage: pass, open: _passOpen ?? true, onToggle: () => setState(() => _passOpen = !(_passOpen ?? true))));
    }
    kids.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Tx(k.t('question', {'i': i + 1}), style: ts(17, FontWeight.w900, p.ink2)),
      ),
    );
    final stemSt = ts(22, FontWeight.w800, p.ink, height: 1.4);
    kids.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: q.stemTex != null ? RichPara(q.stemTex!, style: stemSt, colors: richColors(p)) : RichPara(q.stem, style: stemSt, colors: richColors(p), notes: false),
      ),
    );
    if (q.image != null) kids.add(ExamFigure(path: s.repo.mediaPath(q.image!), alt: q.imageAlt));
    Widget dock;
    if (gradable(q)) {
      kids.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 18,
          children: [
            for (final l in q.options.keys)
              () {
                var st = OptState.normal;
                String? mk;
                Widget? your;
                if (ck) {
                  if (q.isCorrect(l)) {
                    st = l == chosen ? OptState.correctChosen : OptState.correct;
                    mk = 'check';
                  } else if (l == chosen) {
                    st = OptState.wrongChosen;
                    mk = 'x';
                    your = Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Tx(k.t('yourAnswer'), style: ts(15, FontWeight.w900, p.peach.deep, height: 1.3)),
                    );
                  } else {
                    st = OptState.dim;
                  }
                } else if (l == chosen) {
                  st = OptState.sel;
                }
                return OptButton(
                  state: st,
                  letter: l,
                  mark: mk,
                  below: your,
                  onTap: ck ? null : () => s.runChoose(q.id, l),
                  child: RichPara(q.options[l]!, style: optStyle(p), colors: richColors(p), notes: false),
                );
              }(),
          ],
        ),
      );
      if (!ck) kids.add(hintText(context, k.t('pickOne')));
      dock = ck ? _nextBtn(k, i, n) : ClayButton(label: k.t('check'), icon: 'check', minHeight: 64, fontSize: 22, enabled: chosen != null, onTap: () => _check(q, e));
    } else {
      if (!ck) kids.add(hintText(context, k.t('thinkFirst')));
      dock = ck ? _nextBtn(k, i, n) : ClayButton(label: k.t('showAnswer'), minHeight: 64, fontSize: 22, onTap: () => _check(q, e));
    }
    if (ck) kids.add(Padding(key: _fbKey, padding: const EdgeInsets.only(top: 22), child: ExamFeedback(q: q, chosen: chosen)));
    return DockPage(
      controller: _scroll,
      top: RunTop(frac: (i + (ck ? 1 : 0)) / n, count: '${i + 1}/$n', onStop: _stop),
      dock: dock,
      children: kids,
    );
  }

  Widget _nextBtn(Kit k, int i, int n) =>
      ClayButton(label: i + 1 < n ? k.t('next') : k.t('seeResult'), icon: 'next', trailingIcon: true, minHeight: 64, fontSize: 22, onTap: _next);
}

/// verdict + Why? + Tip after Check (`feedbackHTML`)
class ExamFeedback extends StatelessWidget {
  const ExamFeedback({super.key, required this.q, required this.chosen});
  final ExamQuestion q;
  final String? chosen;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, rc = richColors(p);
    final kids = <Widget>[];
    if (gradable(q)) {
      final ok = chosen != null && q.isCorrect(chosen!);
      kids.add(
        ok
            ? Verdict(ok: true, title: k.t('right'), lines: [Tx(k.t('rightSub'), style: verdictLine(p))])
            : Verdict(
                ok: false,
                title: k.t('wrong'),
                lines: [
                  Tx('${k.t('yourAnswer')}: ${chosen ?? ''}', style: verdictLine(p)),
                  Tx('${k.t('rightAnswer')}: ${q.rightLetters.join(' / ')}', style: verdictLine(p)),
                ],
              ),
      );
    } else {
      kids.add(
        ExplainBox(
          icon: 'check',
          title: k.t('rightAnswer'),
          c: p.sage.tile,
          d: p.sage.deep,
          top: 0,
          children: [
            explainP(context, q.answer, notes: false),
            explainP(context, k.t('compare'), w: FontWeight.w800, color: p.ink2),
          ],
        ),
      );
    }
    if (q.why.isNotEmpty) {
      kids.add(
        ExplainBox(
          icon: 'why',
          title: k.t('why'),
          children: [
            for (final w in q.why)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: RichPara(w, style: ts(19, FontWeight.w500, p.ink, height: 1.5), colors: rc, notes: false),
              ),
          ],
        ),
      );
    }
    if (q.tips.isNotEmpty) {
      kids.add(
        ExplainBox(
          icon: 'tip',
          title: k.t('tip'),
          c: p.butter.tile,
          d: p.butter.deep,
          children: [RichPara(q.tips.first, style: ts(19, FontWeight.w500, p.ink, height: 1.5), colors: rc, notes: false)],
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids);
  }
}

/// `details.passage`: blue collapsible "Read this first"
class _PassageBox extends StatelessWidget {
  const _PassageBox({required this.passage, required this.open, required this.onToggle});
  final Passage passage;
  final bool open;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, rc = richColors(p);
    final st = ts(19, FontWeight.w500, p.ink, height: 1.55);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: DecoratedBox(
        decoration: k.c.puffy(c: p.blue.tile, d: p.blue.deep, radius: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 60),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Row(
                    spacing: 10,
                    children: [
                      k.icon('book', size: 28, color: p.ink),
                      Expanded(child: Tx(k.t('readFirst'), style: ts(19, FontWeight.w900, p.ink))),
                      AnimatedRotation(turns: open ? .5 : 0, duration: const Duration(milliseconds: 300), child: k.icon('chev', size: 24, color: p.ink)),
                    ],
                  ),
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RichPara(passage.title, style: st.copyWith(fontWeight: FontWeight.w700), colors: rc, notes: false),
                    ),
                    for (final x in passage.paragraphs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RichPara(x, style: st, colors: rc, notes: false),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// `.qfig`: tappable figure (opens the zoom viewer) or "Picture: alt" when the file is not in the app
class ExamFigure extends StatelessWidget {
  const ExamFigure({super.key, required this.path, this.alt});
  final String path;
  final String? alt;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p;
    final miss = alt == null || alt!.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(20)),
              child: RichPara('${k.t('picture')}: $alt', style: ts(17, FontWeight.w500, p.ink), colors: richColors(p), notes: false),
            ),
          );
    return FutureBuilder<bool>(
      future: _exists(context, path),
      builder: (context, snap) {
        if (snap.data != true) return snap.connectionState == ConnectionState.done ? miss : const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Press(
            onTap: () => Navigator.of(context).push(PageRouteBuilder<void>(opaque: false, pageBuilder: (_, _, _) => ZoomView(path: path))),
            deco: k.c.puffy(c: white, radius: 20),
            pressedDeco: k.c.puffyPressed(c: white, radius: 20),
            dy: 3,
            padding: const EdgeInsets.all(10),
            child: Column(
              spacing: 6,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset(path, fit: BoxFit.contain)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    k.icon('zoom', size: 20, color: const Color(0xFF6A5B50)),
                    Tx(k.t('tapBig'), style: ts(16, FontWeight.w800, const Color(0xFF6A5B50))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static final _known = <String, bool>{};
  static Future<bool> _exists(BuildContext context, String path) async {
    if (_known.containsKey(path)) return _known[path]!;
    try {
      final m = await AssetManifest.loadFromAssetBundle(DefaultAssetBundle.of(context));
      return _known[path] = m.listAssets().contains(path);
    } catch (_) {
      return _known[path] = false;
    }
  }
}

/// full-screen picture viewer: 100–400 %, bigger / smaller / close
class ZoomView extends StatefulWidget with NoNavPage {
  const ZoomView({super.key, required this.path});
  final String path;
  @override
  State<ZoomView> createState() => _ZoomViewState();
}

class _ZoomViewState extends State<ZoomView> {
  double w = 100;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    Widget b(String icon, VoidCallback tap) => Press(
      onTap: tap,
      deco: k.c.cbtn(),
      pressedDeco: k.c.cbtnPressed(),
      dy: 4,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Center(child: k.icon(icon, size: 28, color: k.p.ink)),
      ),
    );
    return ColoredBox(
      color: const Color.fromRGBO(20, 14, 10, .92),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: (box.maxWidth - 40) * w / 100,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: white, borderRadius: BorderRadius.circular(12)),
                        child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset(widget.path, fit: BoxFit.fitWidth)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 14,
                children: [
                  b('minus', () => setState(() => w = (w - 50).clamp(100, 400))),
                  b('zoom', () => setState(() => w = (w + 50).clamp(100, 400))),
                  b('x', () => Navigator.of(context).pop()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- result
class ResultPage extends StatelessWidget with NoNavPage {
  const ResultPage({super.key});
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, s = k.s, qid = s.repo.qid;
    final r = s.run ?? {'right': 0, 'total': 0, 'stars': 0, 'qids': <String>[], 'res': <String, dynamic>{}};
    final qids = (r['qids'] as List).cast<String>(), res = r['res'] as Map;
    final wrong = [for (final id in qids) if (qid[id] != null && gradable(qid[id]!.$1) && res[id] == false) id];
    final stars = (r['stars'] as num?)?.toInt() ?? 0;
    final msg = stars == 3 ? k.t('great') : (stars == 2 ? k.t('good') : k.t('keep'));
    final mistakesMode = r['mode'] == 'mistakes';
    return ResultView(
      stars: stars,
      msg: msg,
      score: k.t('nRight', {'n': r['right'] ?? 0, 't': r['total'] ?? 0}),
      extra: mistakesMode && wrong.isEmpty ? k.t('allFixed') : null,
      buttons: [
        ClayButton(
          label: k.t('tryAgain'),
          icon: 'retry',
          onTap: () {
            if (r['mode'] == 'paper') {
              final e = s.repo.paper(r['examId'] as String);
              if (e != null) startExam(context, e);
            } else {
              startRun(context, List<String>.of(qids), mode: 'mistakes', subj: r['subj'] as String);
            }
          },
        ),
        if (wrong.isNotEmpty)
          ClayButton(
            label: k.t('reviewMistakes'),
            icon: 'eye',
            kind: BtnKind.soft,
            onTap: () => startRun(context, wrong, mode: 'mistakes', subj: r['subj'] as String),
          ),
        ClayButton(
          label: mistakesMode ? k.t('mistakes') : k.t('generalExam'),
          kind: BtnKind.ghost,
          minHeight: 56,
          onTap: () => Shell.of(context).openTab(runTab(s)),
        ),
      ],
      palette: p,
    );
  }
}

/// `.result`: big stars, message, score, optional line, buttons (exam result and notes-mistakes result)
class ResultView extends StatelessWidget {
  const ResultView({super.key, required this.stars, required this.msg, required this.score, this.extra, required this.buttons, required this.palette});
  final int stars;
  final String msg, score;
  final String? extra;
  final List<Widget> buttons;
  final Palette palette;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p;
    return PageShell(
      top: TopBar(children: [TopTitle(k.t('result'))]),
      body: ScreenScroll(
        bottom: 30,
        children: [
          const SizedBox(height: 20),
          BigStars(stars),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6), // margin 8 collapses with the stars' 6
            child: Tx(msg, textAlign: TextAlign.center, style: ts(30, FontWeight.w900, p.ink, height: 1.15, spacing: -.3)),
          ),
          Padding(
            padding: EdgeInsets.zero, // margin-top 4 collapses into the title's 6
            child: Tx(score, textAlign: TextAlign.center, style: ts(24, FontWeight.w900, p.ink2)),
          ),
          if (extra != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Tx(extra!, textAlign: TextAlign.center, style: ts(19, FontWeight.w700, p.ink2)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 18, children: buttons),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- year page: Paper A / B
class YearPage extends StatelessWidget {
  const YearPage({super.key, required this.subject, required this.year, required this.papers});
  final ExamSubject subject;
  final int year;
  final List<Paper> papers;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, s = k.s, tone = p.tone(subject.tone);
    Widget card(Paper? e, String? ver) {
      final b = e == null ? null : s.best[e.id] as Map?;
      final big = ver != null ? Tx(ver, style: ts(38, FontWeight.w900, tone.deep, normal: true)) : k.icon('book', size: 40, color: tone.deep);
      final disabled = e == null;
      final row = Row(
        spacing: 16,
        children: [
          DecoratedBox(
            decoration: ClayDecoration(
              radius: BorderRadius.circular(24),
              fills: [
                RadialFill.circle(.35, .28, [p.lift, p.surface], const [0, .65]),
              ],
              shadows: [Shadow3(0, 5, 0, 0, tone.edge(p.dark)), Shadow3(0, 10, 14, -8, withA(tone.deep, .5)), Shadow3.inset(0, 2, 2, 0, p.hi), Shadow3.inset(0, -3, 5, 0, p.sh(.1))],
            ),
            child: SizedBox(width: 72, height: 72, child: Center(child: big)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tx(ver != null ? k.t('paper', {'v': ver}) : k.t('paperOnly'), style: ts(24, FontWeight.w900, p.ink)),
                Tx(disabled ? k.t('soon') : s.nQ(e.questions.length), style: ts(17, FontWeight.w700, p.ink2)),
                if (b != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Stars((b['stars'] as num).toInt(), palette: p),
                  ),
              ],
            ),
          ),
          if (!disabled)
            DecoratedBox(
              decoration: k.c.play(),
              child: SizedBox(
                width: 60,
                height: 60,
                child: Center(
                  child: Padding(padding: const EdgeInsets.only(left: 3), child: k.icon('play', size: 28, color: p.onPrimary)),
                ),
              ),
            ),
        ],
      );
      if (disabled) {
        return Opacity(
          opacity: .6,
          child: Container(
            constraints: const BoxConstraints(minHeight: 112),
            padding: const EdgeInsets.all(20),
            decoration: ClayDecoration(
              radius: BorderRadius.circular(32),
              fills: [SolidFill(p.surface2)],
              shadows: [Shadow3.inset(4, 6, 12, 0, p.sh(.18)), Shadow3.inset(-3, -3, 6, 0, p.hi2)],
            ),
            child: row,
          ),
        );
      }
      return Press(
        onTap: () => startExam(context, e),
        deco: k.c.puffyTone(tone, radius: 32),
        pressedDeco: k.c.puffyTonePressed(tone, radius: 32),
        dy: 3,
        scale: .985,
        spring: true,
        constraints: const BoxConstraints(minHeight: 112, minWidth: double.infinity),
        padding: const EdgeInsets.all(20),
        child: row,
      );
    }

    final lettered = papers.any((e) => e.version == 'A' || e.version == 'B');
    final others = papers.where((e) => e.version != 'A' && e.version != 'B');
    return PageShell(
      top: BackTop('${k.t(subject.key)} · $year', onBack: () => Shell.of(context).pop()),
      body: ScreenScroll(
        children: [
          Padding(padding: const EdgeInsets.only(top: 8, bottom: 6), child: h2(k.t('pickPaper'), p.ink)),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 18,
            children: [
              if (lettered) ...[
                for (final v in ['A', 'B']) card(papers.where((e) => e.version == v).firstOrNull, v),
              ],
              for (final e in others) card(e, e.version),
            ],
          ),
        ],
      ),
    );
  }
}

/// `.cont` card (lilac for an unfinished exam run)
class ContCard extends StatelessWidget {
  const ContCard({super.key, required this.art, required this.tone, required this.title, required this.sub, this.third, required this.onTap});
  final String art, title, sub;
  final String? third;
  final Tone tone;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Press(
        onTap: onTap,
        deco: k.c.puffyTone(tone, radius: 32),
        pressedDeco: k.c.puffyTonePressed(tone, radius: 32),
        dy: 3,
        scale: .985,
        spring: true,
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        child: Row(
          spacing: 14,
          children: [
            ArtIcon(art, size: 52, palette: p, shadow: p.dark ? const Color.fromRGBO(0, 0, 0, .5) : withA(tone.deep, .35)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(title, style: ts(22, FontWeight.w900, p.ink, normal: true)),
                  Tx(sub, style: ts(17, FontWeight.w700, p.ink2, normal: true)),
                  if (third != null) Tx(third!, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(17, FontWeight.w800, p.ink, normal: true)),
                ],
              ),
            ),
            DecoratedBox(
              decoration: k.c.play(),
              child: SizedBox(
                width: 60,
                height: 60,
                child: Center(
                  child: Padding(padding: const EdgeInsets.only(left: 3), child: k.icon('play', size: 28, color: p.onPrimary)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
