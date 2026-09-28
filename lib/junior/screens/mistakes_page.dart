// My mistakes tab (`R.mistakes`): exam mistakes per subject, notes-exercise mistakes per unit (marked with their source),
// Practise; plus the one-question-at-a-time notes retry (`R.nex`) and its result (`R.nresult`).
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/exam_models.dart';
import '../data/notes_models.dart';
import '../data/subjects.dart';
import '../notes/exercise.dart';
import '../notes/session.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/art.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/page.dart';
import '../widgets/tx.dart';
import 'exam_player.dart';
import 'shell.dart';

/// one notes-exercise mistake (`nmItems()` entry)
class NmItem {
  final String bid;
  final NotesBook book;
  final Unit u;
  final ExQuestion q;
  final int t;
  const NmItem(this.bid, this.book, this.u, this.q, this.t);
}

/// book ids referenced by S.notes.mist
Set<String> nmBooks(AppState s) => {for (final m in s.notesMist.values) '${(m as Map)['b']}'};

/// notes mistakes whose book is loaded, oldest first (web `nmItems`)
List<NmItem> nmItems(AppState s) {
  final out = <NmItem>[];
  for (final m in s.notesMist.values) {
    final mm = m as Map;
    final bid = '${mm['b']}', b = s.repo.bookIfLoaded(bid);
    final u = b?.unit('${mm['u']}');
    final q = u?.exercise.questions.where((x) => x.id == mm['q']).firstOrNull;
    if (q != null && exGraded(q)) out.add(NmItem(bid, b!, u!, q, (mm['t'] as num?)?.toInt() ?? 0));
  }
  out.sort((a, b) => a.t.compareTo(b.t));
  return out;
}

/// "Notes: Science 8, Unit 1"
String nsrc(AppState s, NotesBook b, Unit u) => s.t('notesSrc', {'s': s.t(notesSubject(b.info.subject).key), 'g': b.info.grade, 'n': u.number});

/// papers + every book with a notes mistake (null = all loaded already)
Future<void>? mistakesLoad(AppState s) {
  final need = [for (final id in nmBooks(s)) if (s.repo.hasBook(id) && s.repo.bookIfLoaded(id) == null) id];
  if (s.repo.papersIfLoaded != null && need.isEmpty) return null;
  return Future.wait<Object>([s.repo.papers(), for (final id in need) s.repo.book(id)]);
}

class MistakesPage extends StatefulWidget {
  const MistakesPage({super.key});
  @override
  State<MistakesPage> createState() => _MistakesPageState();
}

class _MistakesPageState extends State<MistakesPage> {
  Future<void>? _load;
  String _loadFor = '';

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, s = k.s;
    final sig = nmBooks(s).join(',');
    if (sig != _loadFor || _load == null) {
      _loadFor = sig;
      final f = mistakesLoad(s);
      if (f != null) {
        _load = f;
        unawaited(f.then((_) { if (mounted) setState(() {}); }, onError: (_) {}));
      } else {
        _load = Future.value();
      }
    }
    final loading = s.repo.papersIfLoaded == null;
    final qid = loading ? const <String, (ExamQuestion, Paper)>{} : s.repo.qid;
    final ids = [for (final id in s.mistakes.keys) if (qid[id] != null) id];
    final nm = nmItems(s);
    final total = ids.length + nm.length;
    final kids = <Widget>[];
    if (total == 0 && !(loading && s.mistakeCount > 0)) {
      kids.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
          child: Column(
            children: [
              ArtIcon('happy', size: 120, palette: p, shadow: p.dark ? const Color.fromRGBO(0, 0, 0, .5) : withA(const Color(0xFF8C6A4C), .35)),
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Tx(k.t('noMistakes'), textAlign: TextAlign.center, style: ts(26, FontWeight.w900, p.ink)),
              ),
              Tx(k.t('noMistakesSub'), textAlign: TextAlign.center, style: ts(19, FontWeight.w700, p.ink2)),
            ],
          ),
        ),
      );
    } else if (total > 0) {
      kids.add(Padding(padding: const EdgeInsets.only(top: 6, bottom: 18), child: lead(total == 1 ? k.t('oneToPractise') : k.t('nToPractise', {'n': total}), p.ink2)));
      for (final sj in ExamSubject.all) {
        final n = ids.where((id) => qid[id]!.$2.subject?.id == sj.id).length;
        if (n == 0) continue;
        kids.add(
          MistakeRow(
            art: sj.id,
            tone: sj.tone,
            title: k.t(sj.key),
            sub: s.nQ(n),
            onTap: () => startMistakes(context, sj.id),
          ),
        );
      }
      final grp = <String, (NmItem, int)>{};
      for (final m in nm) {
        final key = '${m.bid}|${m.u.id}';
        final g = grp[key];
        grp[key] = (g?.$1 ?? m, (g?.$2 ?? 0) + 1);
      }
      if (grp.isNotEmpty && ids.isNotEmpty) {
        kids.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 12), // margin 24 collapses with the row's 14
            child: Row(spacing: 10, children: [k.icon('note', size: 30, color: p.ink), Flexible(child: Tx(k.t('notes'), style: ts(22, FontWeight.w900, p.ink)))]),
          ),
        );
      }
      for (final (m, n) in grp.values) {
        final sub = notesSubject(m.book.info.subject);
        kids.add(
          MistakeRow(
            art: sub.art,
            tone: sub.tone,
            src: nsrc(s, m.book, m.u),
            title: m.u.title,
            sub: s.nQ(n),
            onTap: () => startNMist(context, m.bid, m.u.id),
          ),
        );
      }
      kids.add(
        Padding(
          padding: const EdgeInsets.only(top: 8), // .stack margin-top 22 collapses with the row's 14
          child: ClayButton(
            label: k.t('practise'),
            icon: 'play',
            onTap: () => ids.isNotEmpty ? startMistakes(context, null) : startNMist(context, null, null),
          ),
        ),
      );
    }
    return PageShell(
      top: TopBar(children: [TopTitle(k.t('mistakes')), const LangToggle()]),
      body: ScreenScroll(children: kids),
    );
  }
}

/// `.row`: tinted clay row with art, title (+ source line, + small count) and a go arrow
class MistakeRow extends StatelessWidget {
  const MistakeRow({super.key, required this.art, required this.tone, required this.title, required this.sub, this.src, required this.onTap});
  final String art, tone, title, sub;
  final String? src;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, t = p.tone(tone);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Press(
        onTap: onTap,
        deco: k.c.puffyTone(t, radius: 28),
        pressedDeco: k.c.puffyTonePressed(t, radius: 28),
        dy: 3,
        scale: .985,
        spring: true,
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          spacing: 14,
          children: [
            ArtIcon(art, size: 52, palette: p, shadow: p.dark ? const Color.fromRGBO(0, 0, 0, .5) : withA(t.deep, .35)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (src != null) Tx(src!, style: ts(16, FontWeight.w900, t.deep, spacing: .16, normal: true)),
                  Tx(title, style: ts(20, FontWeight.w900, p.ink, normal: true)),
                  Tx(sub, style: ts(16, FontWeight.w700, p.ink2, normal: true)),
                ],
              ),
            ),
            k.icon('go', size: 28, color: p.ink2),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- notes retry run (web `X` with mode 'mist')
class NexRun {
  NexRun(this.items, this.bid, this.uid);
  final List<NmItem> items;
  final String? bid, uid;
  int i = 0;
  bool checked = false, sim = false;
  final Map<String, Object> ans = {};
  final Map<String, bool> res = {};
  static NexRun? cur;
  static String keyOf(NmItem it) => '${it.bid}|${it.q.id}';
}

/// retry notes mistakes (all, one book, or one unit) one question at a time
void startNMist(BuildContext context, String? bid, String? uid) {
  final s = AppScope.read(context), sh = Shell.of(context);
  final items = [for (final m in nmItems(s)) if ((bid == null || m.bid == bid) && (uid == null || m.u.id == uid)) m];
  if (items.isEmpty) return sh.openTab(AppTab.mistakes);
  NexRun.cur = NexRun(items, bid, uid);
  sh.resetTo(AppTab.mistakes, const [NexPage()]);
}

class NexPage extends StatefulWidget with NoNavPage {
  const NexPage({super.key});
  @override
  State<NexPage> createState() => _NexPageState();
}

class _NexPageState extends State<NexPage> {
  final _scroll = ScrollController();
  final _fbKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _check(NexRun x) {
    final it = x.items[x.i], q = it.q, key = NexRun.keyOf(it);
    if (exGraded(q)) {
      if (x.ans[key] == null) return;
      x.res[key] = exOK(q, x.ans[key]);
      AppScope.read(context).nmMark(it.bid, it.u.id, q.id, x.res[key]!);
    }
    setState(() {
      x.checked = true;
      x.sim = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _fbKey.currentContext;
      if (c != null && c.mounted) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }

  void _next(NexRun x) {
    if (x.i + 1 < x.items.length) {
      setState(() {
        x.i++;
        x.checked = false;
        x.sim = false;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
      return;
    }
    final g = x.items.where((it) => exGraded(it.q)).toList();
    final right = g.where((it) => x.res[NexRun.keyOf(it)] == true).length;
    Shell.of(context).replace(NResultPage(bid: x.bid, uid: x.uid, stars: starsFor(right, g.length), right: right, total: g.length));
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, s = k.s, x = NexRun.cur;
    void stop() => Shell.of(context).openTab(AppTab.mistakes);
    if (x == null || x.items.isEmpty) return PageShell(top: TopBar(children: [RoundButton(icon: 'x', onTap: stop)]), body: const SizedBox.shrink());
    final it = x.items[x.i], q = it.q, n = x.items.length, ck = x.checked, key = NexRun.keyOf(it), chosen = x.ans[key];
    final Widget dock = ck
        ? ClayButton(label: x.i + 1 < n ? k.t('next') : k.t('seeResult'), icon: 'next', trailingIcon: true, minHeight: 64, fontSize: 22, onTap: () => _next(x))
        : exGraded(q)
        ? ClayButton(label: k.t('check'), icon: 'check', minHeight: 64, fontSize: 22, enabled: chosen != null, onTap: () => _check(x))
        : ClayButton(label: k.t('showAnswer'), minHeight: 64, fontSize: 22, onTap: () => _check(x));
    return DockPage(
      controller: _scroll,
      top: RunTop(frac: (x.i + (ck ? 1 : 0)) / n, count: '${x.i + 1}/$n', onStop: stop),
      dock: dock,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: p.butter.tile, borderRadius: BorderRadius.circular(99)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [k.icon('note', size: 20, color: p.ink), Flexible(child: Tx(nsrc(s, it.book, it.u), style: ts(16, FontWeight.w900, p.ink)))],
            ),
          ),
        ),
        ExBlock(
          q: q,
          label: k.t('question', {'i': x.i + 1}),
          chosen: chosen,
          checked: ck,
          ok: x.res[key],
          sim: x.sim,
          inline: false,
          feedbackKey: _fbKey,
          onPick: (v) => setState(() => x.ans[key] = v),
          onSim: () => setState(() => x.sim = true),
        ),
      ],
    );
  }
}

class NResultPage extends StatelessWidget with NoNavPage {
  const NResultPage({super.key, this.bid, this.uid, required this.stars, required this.right, required this.total});
  final String? bid, uid;
  final int stars, right, total;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, wrong = total - right;
    final msg = stars == 3 ? k.t('great') : (stars == 2 ? k.t('good') : k.t('keep'));
    return ResultView(
      stars: stars,
      msg: msg,
      score: k.t('nRight', {'n': right, 't': total}),
      extra: wrong == 0 ? k.t('allFixed') : null,
      buttons: [
        if (wrong > 0) ClayButton(label: k.t('tryAgain'), icon: 'retry', onTap: () => startNMist(context, bid, uid)),
        ClayButton(
          label: k.t('toMistakes'),
          icon: 'retry',
          kind: wrong > 0 ? BtnKind.soft : BtnKind.primary,
          onTap: () => Shell.of(context).openTab(AppTab.mistakes),
        ),
      ],
      palette: p,
    );
  }
}
