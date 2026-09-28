// Grade page: every subject of the grade as a raised bar; tap it to open or close its unit list (the first one is open).
import 'package:flutter/widgets.dart';

import '../data/notes_models.dart';
import '../data/subjects.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/art.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/page.dart';
import 'shell.dart';
import 'unit_page.dart';
import '../widgets/tx.dart';

class GradePage extends StatefulWidget {
  const GradePage({super.key, required this.grade});
  final int grade;
  @override
  State<GradePage> createState() => _GradePageState();
}

class _GradePageState extends State<GradePage> {
  late final Future<List<NotesBook>> _load;
  List<String>? open;

  @override
  void initState() {
    super.initState();
    _load = AppScope.read(context).repo.booksOfGrade(widget.grade);
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p;
    final books = k.s.repo.manifest!.grade(widget.grade)..sort((a, b) => kNotesOrder.indexOf(a.subject).compareTo(kNotesOrder.indexOf(b.subject)));
    open ??= books.isEmpty ? [] : [books.first.id];
    return PageShell(
      top: BackTop(k.t('gradeN', {'n': widget.grade}), onBack: () => Shell.of(context).pop()),
      body: FutureBuilder<List<NotesBook>>(
        future: _load,
        initialData: k.s.repo.booksOfGradeIfLoaded(widget.grade),
        builder: (context, snap) {
          if (snap.hasError) debugPrint('grade ${widget.grade}: ${snap.error}');
          final loaded = {for (final b in snap.data ?? const <NotesBook>[]) b.info.id: b};
          return ScreenScroll(
            children: [
              Padding(padding: const EdgeInsets.only(top: 4, bottom: 16), child: lead(k.t('gradeLead'), p.ink2)),
              for (final b in books)
                _SubjectSection(
                  book: b,
                  notes: loaded[b.id],
                  loading: snap.data == null && !snap.hasError,
                  open: open!.contains(b.id),
                  onToggle: () => setState(() => open!.contains(b.id) ? open!.remove(b.id) : open!.add(b.id)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SubjectSection extends StatelessWidget {
  const _SubjectSection({required this.book, required this.notes, required this.loading, required this.open, required this.onToggle});
  final ManifestBook book;
  final NotesBook? notes;
  final bool loading, open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, s = k.s;
    final sub = notesSubject(book.subject), tone = p.tone(sub.tone);
    final ready = notes == null ? 0 : book.units.where((x) => x.notesId != null && notes!.unit(x.notesId!) != null).length;
    final showReady = !loading && ready < book.units.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Press(
            onTap: onToggle,
            deco: k.c.puffyTone(tone, radius: 28),
            pressedDeco: k.c.puffyTonePressed(tone, radius: 28),
            dy: 3,
            scale: .985,
            spring: true,
            constraints: const BoxConstraints(minHeight: 84),
            padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
            child: Row(
              spacing: 14,
              children: [
                ArtIcon(sub.art, size: 52, palette: p, shadow: p.dark ? const Color.fromRGBO(0, 0, 0, .5) : withA(tone.deep, .35)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tx(k.t(sub.key), style: ts(22, FontWeight.w900, p.ink, height: 1.15)),
                      if (s.lang != 'en') Tx(s.en(sub.key), style: ts(15, FontWeight.w800, p.ink2, normal: true)),
                      Tx(
                        k.t('nUnits', {'n': book.units.length}) + (showReady ? ' · ${k.t('nReady', {'n': ready})}' : ''),
                        style: ts(16, FontWeight.w700, p.ink2, normal: true),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: open ? .5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: k.icon('chev', size: 28, color: p.ink2),
                ),
              ],
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: CustomPaint(
                painter: _DottedLeft(withA(tone.mid, .7 * tone.mid.a)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4 + 14, 16, 0, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final x in book.units)
                        _UnitRow(book: book, mu: x, unit: x.notesId == null ? null : notes?.unit(x.notesId!), tone: tone, loading: loading),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `border-left: 4px dotted` (round dots, as Chrome draws them)
class _DottedLeft extends CustomPainter {
  _DottedLeft(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const d = 4.0;
    final n = (size.height / (2 * d)).floor();
    final gap = n > 1 ? (size.height - d) / (n - 1) : 0.0;
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(Offset(d / 2, d / 2 + i * gap), d / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedLeft old) => old.color != color;
}

class _UnitRow extends StatelessWidget {
  const _UnitRow({required this.book, required this.mu, required this.unit, required this.tone, required this.loading});
  final ManifestBook book;
  final ManifestUnit mu;
  final Unit? unit;
  final Tone tone;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, s = k.s;
    final u = unit;
    Widget numBox(Tone? t) => DecoratedBox(
      decoration: k.c.num(t),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Center(child: Tx('${mu.n}', style: ts(20, FontWeight.w900, t?.deep ?? p.ink, height: 1))),
      ),
    );
    if (u == null) {
      // "Soon" (or still loading)
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Opacity(
          opacity: loading ? .85 : .6,
          child: DecoratedBox(
            decoration: loading ? k.c.puffyTone(tone, radius: 28) : k.c.sunkenRow(radius: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  spacing: 14,
                  children: [
                    numBox(loading ? tone : null),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Tx(mu.title, style: ts(19, FontWeight.w900, p.ink, normal: true)),
                          Tx(
                            loading ? k.t('unitN', {'n': mu.n}) : '${k.t('unitN', {'n': mu.n})} · ${k.t('soon')}',
                            style: ts(16, FontWeight.w700, p.ink2, normal: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final pct = s.unitPct(u);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Press(
        onTap: () => Shell.of(context).push(UnitPage(bookId: book.id, unitId: u.id)),
        deco: k.c.puffyTone(tone, radius: 28),
        pressedDeco: k.c.puffyTonePressed(tone, radius: 28),
        dy: 3,
        scale: .985,
        spring: true,
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          spacing: 14,
          children: [
            numBox(tone),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(u.title, style: ts(19, FontWeight.w900, p.ink, normal: true)),
                  Tx('${k.t('unitN', {'n': mu.n})} · ${s.nQ(u.exercise.questions.length)}', style: ts(16, FontWeight.w700, p.ink2, normal: true)),
                  MiniBar(pct),
                ],
              ),
            ),
            if (pct >= 100)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: p.sage.mid, shape: BoxShape.circle),
                child: Center(child: k.icon('check', size: 22, color: white)),
              )
            else
              k.icon('go', size: 28, color: p.ink2),
          ],
        ),
      ),
    );
  }
}
