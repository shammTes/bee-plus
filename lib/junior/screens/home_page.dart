// Home: greeting, Continue (last unit), "Pick a grade" with Grade 6 / 7 / 8 clay cards.
import 'package:flutter/widgets.dart';

import '../data/notes_models.dart';
import '../data/subjects.dart';
import '../theme/tokens.dart';
import '../widgets/art.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/page.dart';
import 'grade_page.dart';
import 'shell.dart';
import 'unit_page.dart';
import '../widgets/tx.dart';

const _defDeep = Color(0xFF8C6A4C);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, s = k.s;
    final m = s.repo.manifest!;
    return PageShell(
      top: TopBar(children: [TopTitle(k.t('app'), logo: true), const LangToggle()]),
      body: ScreenScroll(
        children: [
          // .hello
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 18),
            child: Row(
              spacing: 14,
              children: [
                ArtIcon('sun', size: 74, palette: p, shadow: p.dark ? const Color.fromRGBO(0, 0, 0, .5) : mix(_defDeep, .35, transparent)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      h2(k.t('hello'), p.ink),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Tx(k.t('helloSub'), style: ts(19, FontWeight.w700, p.ink2)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _ContinueCard(),
          // h3 margin-top 6 collapses into the 18 / 20 px margin above it (CSS margin collapsing)
          Padding(padding: const EdgeInsets.only(bottom: 14), child: h3(k.t('pickGrade'), p.ink)),
          for (final (i, g) in [6, 7, 8].indexed) ...[if (i > 0) const SizedBox(height: 20), GradeCard(grade: g, books: m.grade(g))],
        ],
      ),
    );
  }
}

class GradeCard extends StatelessWidget {
  const GradeCard({super.key, required this.grade, required this.books});
  final int grade;
  final List<ManifestBook> books;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p;
    final tone = p.tone(gradeTone(grade));
    final units = books.fold(0, (a, b) => a + b.units.length);
    // a unit is ready when the manifest names its notes unit and the book file is bundled
    final ready = books.fold(0, (a, b) => a + (k.s.repo.hasBook(b.id) ? b.units.where((u) => u.notesId != null).length : 0));
    return Press(
      onTap: () => Shell.of(context).push(GradePage(grade: grade)),
      deco: k.c.puffyTone(tone, radius: 32),
      pressedDeco: k.c.puffyTonePressed(tone, radius: 32),
      dy: 3,
      scale: .985,
      spring: true,
      constraints: const BoxConstraints(minHeight: 120, minWidth: double.infinity),
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      child: Row(
        spacing: 18,
        children: [
          DecoratedBox(
            decoration: k.c.gnum(tone),
            child: SizedBox(
              width: 82,
              height: 82,
              child: Center(child: Tx('$grade', style: ts1000(46, tone.deep))),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tx(k.t('gradeN', {'n': grade}), style: ts(28, FontWeight.w900, p.ink, height: 1.15)),
                Tx('${k.t('nSubjects', {'n': books.length})} · ${k.t('nUnits', {'n': units})}', style: ts(17, FontWeight.w700, p.ink2, normal: true)),
                if (ready < units) Padding(padding: const EdgeInsets.only(top: 4), child: TagPill(ready > 0 ? k.t('nReady', {'n': ready}) : k.t('soon'))),
              ],
            ),
          ),
          k.icon('go', size: 30, color: p.ink2),
        ],
      ),
    );
  }
}

/// `.cont` card: continue the last opened unit
class _ContinueCard extends StatelessWidget {
  const _ContinueCard();
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, s = k.s;
    final last = s.lastUnit;
    if (last == null) return const SizedBox.shrink();
    final mb = s.repo.manifest!.byId(last.book);
    final mu = mb?.units.where((u) => u.notesId == last.unit).firstOrNull;
    if (mb == null || mu == null) return const SizedBox.shrink();
    final sub = notesSubject(mb.subject), tone = p.tone(sub.tone);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Press(
        onTap: () => Shell.of(context).resetTo(AppTab.home, [GradePage(grade: mb.grade), UnitPage(bookId: mb.id, unitId: last.unit, focus: s.lastCard)]),
        deco: k.c.puffyTone(tone, radius: 32),
        pressedDeco: k.c.puffyTonePressed(tone, radius: 32),
        dy: 3,
        scale: .985,
        spring: true,
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        child: Row(
          spacing: 14,
          children: [
            ArtIcon(sub.art, size: 52, palette: p, shadow: p.dark ? const Color.fromRGBO(0, 0, 0, .5) : withA(tone.deep, .35)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(k.t('continue'), style: ts(22, FontWeight.w900, p.ink, normal: true)),
                  Tx('${k.t(sub.key)} ${mb.grade} · ${k.t('unitN', {'n': mu.n})}', style: ts(17, FontWeight.w700, p.ink2, normal: true)),
                  Tx(mu.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(17, FontWeight.w800, p.ink, normal: true)),
                ],
              ),
            ),
            DecoratedBox(
              decoration: k.c.play(),
              child: SizedBox(
                width: 60,
                height: 60,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: k.icon('play', size: 28, color: p.onPrimary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
