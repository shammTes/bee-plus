// Exercise questions of a unit (`exBlock` / `qInner` / `qSummary`): inline cards on the unit page and the one-at-a-time
// My mistakes retry player share the same block.
import 'package:flutter/widgets.dart';

import '../data/notes_models.dart';
import '../state/app_state.dart';
import '../theme/notes_styles.dart';
import '../theme/tokens.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/tx.dart';
import 'rich.dart';
import 'session.dart';
import 'ui.dart';

bool exGraded(ExQuestion q) => q.type != 'short';

/// options: (letter, text, value) – value is the letter (mcq), true / false (tf) or the choice text (fill)
List<(String, String, Object)> exOpts(AppState s, ExQuestion q) => switch (q.type) {
  'mcq' => [for (final l in q.options.keys) (l, q.options[l]!, l)],
  'tf' => [('T', s.t('true'), true), ('F', s.t('false'), false)],
  'fill' => [for (final (i, c) in q.choices.indexed) ('ABCDE'[i % 5], c, c)],
  _ => const [],
};

bool exOK(ExQuestion q, Object? v) {
  if (v == null) return false;
  if (q.type == 'fill') {
    final acc = [q.answer, ...q.accept].map((x) => x.trim().toLowerCase());
    return acc.contains('$v'.trim().toLowerCase());
  }
  if (q.type == 'tf') return '$v' == q.answer;
  return v == q.answer;
}

/// label, stem, options, and after Check: verdict, Why?, Tip and a similar question
class ExBlock extends StatelessWidget {
  const ExBlock({
    super.key,
    required this.q,
    required this.label,
    this.chosen,
    this.checked = false,
    this.ok,
    this.sim = false,
    this.onPick,
    this.onSim,
    this.inline = true,
    this.feedbackKey,
  });
  final ExQuestion q;
  final String label;
  final Object? chosen;
  final bool checked, sim, inline;
  final bool? ok;
  final ValueChanged<Object>? onPick;
  final VoidCallback? onSim;
  final Key? feedbackKey;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, rc = richColors(p);
    final kids = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Tx(q.page > 0 ? '$label · ${k.t('textbookPage', {'n': q.page})}' : label, style: ts(17, FontWeight.w900, p.ink2)),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: RichPara(q.q, style: ts(inline ? 21 : 22, FontWeight.w800, p.ink, height: 1.4), colors: rc),
      ),
    ];
    final hintTop = inline ? 14.0 : 16.0;
    if (exGraded(q)) {
      kids.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 18,
          children: [
            for (final (l, txt, val) in exOpts(k.s, q))
              () {
                final isC = exOK(q, val), me = chosen != null && '$chosen' == '$val';
                var st = OptState.normal;
                String? mk;
                if (checked) {
                  if (isC) {
                    st = me ? OptState.correctChosen : OptState.correct;
                    mk = 'check';
                  } else if (me) {
                    st = OptState.wrongChosen;
                    mk = 'x';
                  } else {
                    st = OptState.dim;
                  }
                } else if (me) {
                  st = OptState.sel;
                }
                return OptButton(
                  state: st,
                  letter: q.type == 'tf' ? null : l,
                  letterIcon: q.type == 'tf' ? (val == true ? 'check' : 'x') : null,
                  mark: mk,
                  onTap: checked ? null : () => onPick?.call(val),
                  child: RichPara(txt, style: optStyle(p), colors: rc),
                );
              }(),
          ],
        ),
      );
      if (!checked) kids.add(hintText(context, k.t('pickOne'), top: hintTop));
    } else if (!checked) {
      kids.add(hintText(context, k.t('thinkFirst'), top: hintTop));
    }
    if (checked) {
      final fb = <Widget>[];
      if (exGraded(q)) {
        final right = q.type == 'tf'
            ? (q.answer == 'true' ? k.t('true') : k.t('false'))
            : q.type == 'mcq'
            ? '${q.answer} – ${q.options[q.answer] ?? ''}'
            : q.answer;
        fb.add(
          ok == true
              ? Verdict(ok: true, title: k.t('right'), lines: [Tx(k.t('rightSub'), style: verdictLine(p))])
              : Verdict(ok: false, title: k.t('wrong'), lines: [RichPara('${k.t('rightAnswer')}: $right', style: verdictLine(p), colors: rc)]),
        );
      } else {
        fb.add(
          ExplainBox(
            icon: 'check',
            title: k.t('rightAnswer'),
            c: p.sage.tile,
            d: p.sage.deep,
            top: 0,
            children: [
              explainP(context, q.answer),
              explainP(context, k.t('compare'), w: FontWeight.w800, color: p.ink2),
            ],
          ),
        );
      }
      fb.add(ExplainBox(icon: 'why', title: k.t('why'), children: [for (final s in q.why) explainP(context, s)]));
      if (q.tip.isNotEmpty) {
        fb.add(ExplainBox(icon: 'tip', title: k.t('tip'), c: p.butter.tile, d: p.butter.deep, children: [explainP(context, q.tip)]));
      }
      for (final s in q.similar) {
        fb.add(
          ExplainBox(
            icon: 'retry',
            title: k.t('similar'),
            solid: p.lilac.tile,
            children: [
              explainP(context, s.$1),
              if (sim)
                explainP(context, '**${k.t('rightAnswer')}:** ${s.$2}')
              else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClayButton(label: k.t('showAnswer'), icon: 'eye', kind: BtnKind.soft, minHeight: 56, onTap: onSim),
                ),
            ],
          ),
        );
      }
      kids.add(
        Padding(
          key: feedbackKey,
          padding: const EdgeInsets.only(top: 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: fb),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids);
  }
}

/// one inline question card (`.qcard`)
class QCard extends StatefulWidget {
  const QCard({super.key, required this.u, required this.bid, required this.q, required this.index, required this.onChecked});
  final Unit u;
  final String bid;
  final ExQuestion q;
  final int index;
  final VoidCallback onChecked;
  @override
  State<QCard> createState() => _QCardState();
}

class _QCardState extends State<QCard> {
  final _fbKey = GlobalKey();
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), q = widget.q, e = NotesSession.ex(widget.u.id);
    final ck = e.ck.contains(q.id), chosen = e.ans[q.id];
    return NCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExBlock(
            q: q,
            label: k.t('question', {'i': widget.index + 1}),
            chosen: chosen,
            checked: ck,
            ok: e.res[q.id],
            sim: e.sim.contains(q.id),
            feedbackKey: _fbKey,
            onPick: (v) => setState(() => e.ans[q.id] = v),
            onSim: () => setState(() => e.sim.add(q.id)),
          ),
          if (!ck)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: ClayButton(
                label: exGraded(q) ? k.t('check') : k.t('showAnswer'),
                icon: exGraded(q) ? 'check' : 'eye',
                enabled: !exGraded(q) || chosen != null,
                onTap: () {
                  final s = AppScope.read(context);
                  if (exGraded(q)) {
                    if (e.ans[q.id] == null) return;
                    e.res[q.id] = exOK(q, e.ans[q.id]);
                    s.nmMark(widget.bid, widget.u.id, q.id, e.res[q.id]!);
                  }
                  setState(() => e.ck.add(q.id));
                  widget.onChecked();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final c = _fbKey.currentContext;
                    if (c != null && c.mounted) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// `.qsum`: progress until every graded question is checked, then stars + Try again
class QSummary extends StatelessWidget {
  const QSummary({super.key, required this.u, required this.onReset});
  final Unit u;
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, e = NotesSession.ex(u.id);
    final g = u.exercise.questions.where(exGraded).toList();
    if (g.isEmpty) return const SizedBox.shrink();
    final done = g.where((q) => e.ck.contains(q.id)).length, right = g.where((q) => e.res[q.id] == true).length;
    final List<Widget> kids;
    if (done < g.length) {
      kids = [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Tx(k.t('answerAll'), textAlign: TextAlign.center, style: ts(19, FontWeight.w700, p.ink2)),
        ),
        Row(
          spacing: 12,
          children: [
            Expanded(child: PBar(done / g.length)),
            SizedBox(
              width: 52,
              child: Tx('$done/${g.length}', textAlign: TextAlign.right, style: ts(18, FontWeight.w900, p.ink)),
            ),
          ],
        ),
      ];
    } else {
      final st = starsFor(right, g.length);
      if (!e.saved) {
        e.saved = true;
        final s = AppScope.read(context);
        WidgetsBinding.instance.addPostFrameCallback((_) => s.exDone(u.id, st, right, g.length));
      }
      kids = [
        BigStars(st),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Tx(st == 3 ? k.t('great') : (st == 2 ? k.t('good') : k.t('keep')), textAlign: TextAlign.center, style: ts(26, FontWeight.w900, p.ink, height: 1.2)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Tx(k.t('nRight', {'n': right, 't': g.length}), textAlign: TextAlign.center, style: ts(24, FontWeight.w900, p.ink2)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: ClayButton(label: k.t('tryAgain'), icon: 'retry', kind: BtnKind.soft, onTap: onReset),
        ),
      ];
    }
    return NCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids),
    );
  }
}
