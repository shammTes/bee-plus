// General Exam tab: Continue card for an unfinished run, then every Grade 8 paper grouped by subject and year.
import 'package:flutter/widgets.dart';

import '../data/exam_models.dart';
import '../state/app_state.dart';
import '../theme/clay.dart';
import '../theme/tokens.dart';
import '../widgets/art.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/page.dart';
import 'exam_player.dart';
import 'shell.dart';
import '../widgets/tx.dart';

class ExamsPage extends StatefulWidget {
  const ExamsPage({super.key});
  @override
  State<ExamsPage> createState() => _ExamsPageState();
}

class _ExamsPageState extends State<ExamsPage> {
  late final Future<List<Paper>> _load = AppScope.read(context).repo.papers();

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p;
    return PageShell(
      top: TopBar(children: [TopTitle(k.t('generalExam')), const LangToggle()]),
      body: FutureBuilder<List<Paper>>(
        future: _load,
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Tx('Exams did not load.\n${snap.error}', style: ts(16, FontWeight.w700, p.ink)),
            );
          }
          return ScreenScroll(
            children: [
              Padding(padding: const EdgeInsets.only(top: 4, bottom: 18), child: lead(k.t('examLead'), p.ink2)),
              if (snap.hasData) const _RunContinue(),
              for (final s in ExamSubject.all)
                if ((snap.data ?? const <Paper>[]).any((e) => e.subject?.id == s.id))
                  _SubjectExams(subject: s, papers: (snap.data ?? const <Paper>[]).where((e) => e.subject?.id == s.id).toList()),
            ],
          );
        },
      ),
    );
  }
}

class _SubjectExams extends StatelessWidget {
  const _SubjectExams({required this.subject, required this.papers});
  final ExamSubject subject;
  final List<Paper> papers;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, s = k.s;
    final tone = p.tone(subject.tone);
    final years = papers.map((e) => e.yr).toSet().toList()..sort((a, b) => b.compareTo(a));
    final yearDeco = ClayDecoration(
      radius: BorderRadius.circular(24),
      fills: [
        LinearFill.vertical([mix(p.surface, .5, p.lift), p.surface], const [0, .6]),
      ],
      shadows: [Shadow3(0, 6, 0, 0, p.edgeN), Shadow3(0, 14, 18, -10, p.sh(.35)), Shadow3.inset(4, 5, 8, -3, p.hi)],
    );
    final yearPressed = yearDeco.copyWith(shadows: [Shadow3(0, 1, 0, 0, p.edgeN), Shadow3.inset(3, 4, 8, 0, p.sh(.22))]);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: k.c.puffyTone(tone, radius: 28),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              spacing: 12,
              children: [
                ArtIcon(subject.id, size: 52, palette: p, shadow: p.dark ? const Color.fromRGBO(0, 0, 0, .5) : withA(tone.deep, .35)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tx(k.t(subject.key), style: ts(23, FontWeight.w900, p.ink, height: 1.15)),
                      if (s.lang != 'en') Tx(s.en(subject.key), style: ts(15, FontWeight.w800, p.ink2)),
                      Tx(papers.length == 1 ? k.t('onePaper') : k.t('nPapers', {'n': papers.length}), style: ts(16, FontWeight.w700, p.ink2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, c) {
              final w = (c.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final y in years)
                    SizedBox(
                      width: w,
                      child: Press(
                        onTap: () {
                          final py = papers.where((e) => e.yr == y).toList();
                          if (py.length == 1) return startExam(context, py.first);
                          Shell.of(context).push(YearPage(subject: subject, year: y, papers: py));
                        },
                        deco: yearDeco,
                        pressedDeco: yearPressed,
                        dy: 5,
                        constraints: const BoxConstraints(minHeight: 70),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Tx('$y', style: ts(24, FontWeight.w900, p.ink, normal: true)),
                            Builder(
                              builder: (_) {
                                final py = papers.where((e) => e.yr == y).toList();
                                final one = py.length == 1 ? py.first : null;
                                final best = py.map((e) => ((s.best[e.id] as Map?)?['stars'] as num?)?.toInt() ?? 0).fold(0, (a, b) => a > b ? a : b);
                                if (best > 0) return Stars(best, palette: p);
                                final sub = one != null
                                    ? (one.version != null ? k.t('paper', {'v': one.version!}) : k.t('paperOnly'))
                                    : k.t('nPapers', {'n': py.length});
                                return Tx(sub, style: ts(14, FontWeight.w800, p.ink2, normal: true));
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Continue card of an unfinished exam run (`R.exams` cont)
class _RunContinue extends StatelessWidget {
  const _RunContinue();
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, s = k.s, r = s.run;
    if (r == null || r['done'] == true || (r['qids'] as List).isEmpty) return const SizedBox.shrink();
    final subj = ExamSubject.byId(r['subj'] as String? ?? '') ?? ExamSubject.all.first;
    return ContCard(
      art: subj.id,
      tone: p.lilac,
      title: k.t('continue'),
      sub: '${k.t(subj.key)} · ${k.t('qOf', {'i': (r['i'] as int) + 1, 'n': (r['qids'] as List).length})}',
      onTap: () => Shell.of(context).resetTo(runTab(s), const [PracticePage()]),
    );
  }
}
