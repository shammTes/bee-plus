// Building blocks shared by the unit page, games, exercise questions and the exam player.
import 'package:flutter/widgets.dart';

import '../theme/clay.dart';
import '../theme/notes_styles.dart';
import '../theme/tokens.dart';
import '../widgets/art.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/tx.dart';
import 'rich.dart';

/// standard notes text styles
class NS {
  static TextStyle p(Palette p, {double size = 20, FontWeight w = FontWeight.w700, double h = 1.5, Color? c}) => ts(size, w, c ?? p.ink, height: h);
}

RichColors richColors(Palette p) => RichColors.of(p);

/// `.card` (puffy, radius 28). [ncard] = `.ncard` padding 22 20.
class NCard extends StatelessWidget {
  const NCard({super.key, required this.child, this.tone, this.c, this.d, this.padding = const EdgeInsets.fromLTRB(20, 22, 20, 22), this.margin = EdgeInsets.zero});
  final Widget child;
  final Tone? tone;
  final Color? c, d;
  final EdgeInsets padding, margin;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: k.c.puffy(c: c ?? tone?.tile, d: d ?? tone?.deep, radius: 28),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// `.kind` label: icon + UPPERCASE 16/900 in the card's deep colour
class KindLabel extends StatelessWidget {
  const KindLabel(this.icon, this.text, {super.key, this.color});
  final String icon, text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), c = color ?? k.p.ink2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          k.icon(icon, size: 26, color: c),
          Flexible(
            child: Tx(text.toUpperCase(), style: ts(16, FontWeight.w900, c, spacing: .32)),
          ),
        ],
      ),
    );
  }
}

/// `.ncard h2` (26/900, lh 1.2, margin 0 0 12) – may hold $maths$
class CardTitle extends StatelessWidget {
  const CardTitle(this.text, {super.key, this.size = 26, this.bottom = 12});
  final String text;
  final double size, bottom;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final st = ts(size, FontWeight.w900, k.p.ink, height: 1.2);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: text.contains(r'$') ? RichPara(text, style: st, colors: richColors(k.p)) : Tx(text, style: st),
    );
  }
}

/// `.pg` textbook page pill
class PgRef extends StatelessWidget {
  const PgRef(this.page, {super.key});
  final Object? page;
  @override
  Widget build(BuildContext context) {
    if (page == null || page == 0) return const SizedBox.shrink();
    final k = Kit.of(context), p = k.p;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: DecoratedBox(
          decoration: k.c.sunk(p.surface2, radius: 99, dx: 1, dy: 2, blur: 4, a: .15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                k.icon('book', size: 20, color: p.ink2),
                Tx(k.t('textbookPage', {'n': page!}), style: ts(16, FontWeight.w800, p.ink2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.opt` answer option: letter disc (or icon) · text · check/x mark
class OptButton extends StatelessWidget {
  const OptButton({super.key, required this.state, this.letter, this.letterIcon, required this.child, this.onTap, this.minHeight = 68, this.mark, this.below});
  final OptState state;
  final String? letter, letterIcon, mark;
  final Widget child;
  final Widget? below;
  final VoidCallback? onTap;
  final double minHeight;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, c = k.c;
    final down = state == OptState.sel || state == OptState.correctChosen || state == OptState.wrongChosen;
    final lit = state == OptState.sel || state == OptState.correct || state == OptState.correctChosen || state == OptState.wrongChosen;
    final lc = lit ? (p.dark ? const Color(0xFF1D1612) : white) : p.ink;
    final hasL = letter != null || letterIcon != null;
    final row = Row(
      spacing: 14,
      children: [
        if (hasL)
          DecoratedBox(
            decoration: c.optLetter(state),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Center(
                child: letterIcon != null ? k.icon(letterIcon!, size: 26, color: lc) : Tx(letter!, style: ts(20, FontWeight.w900, lc, normal: true)),
              ),
            ),
          ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [child, ?below]),
        ),
        if (mark != null || hasL)
          SizedBox(
            width: 30,
            height: 30,
            child: mark == null
                ? null
                : k.icon(mark!, size: 30, color: state == OptState.wrongChosen ? p.peach.deep : p.sage.deep),
          ),
      ],
    );
    final body = Padding(padding: const EdgeInsets.fromLTRB(12, 10, 16, 10), child: row);
    Widget w;
    if (onTap == null) {
      w = Transform.translate(
        offset: Offset(0, down ? 5 : 0),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight, minWidth: double.infinity),
          child: DecoratedBox(
            decoration: c.opt(state),
            child: Center(widthFactor: 1, heightFactor: 1, child: body),
          ),
        ),
      );
    } else {
      w = Press(
        onTap: onTap,
        selected: down,
        deco: c.opt(state),
        pressedDeco: down ? c.opt(state) : c.optPressed(state),
        dy: 5,
        constraints: BoxConstraints(minHeight: minHeight, minWidth: double.infinity),
        child: Center(widthFactor: 1, heightFactor: 1, child: body),
      );
    }
    return state == OptState.dim ? Opacity(opacity: .6, child: w) : w;
  }
}

/// opt text style (20/700, lh 1.3)
TextStyle optStyle(Palette p, {double size = 20}) => ts(size, FontWeight.w700, p.ink, height: 1.3);

/// `.explain` box (Why? / Tip / Right answer / similar)
class ExplainBox extends StatelessWidget {
  const ExplainBox({super.key, required this.icon, required this.title, required this.children, this.c, this.d, this.solid, this.top = 14});
  final String icon, title;
  final List<Widget> children;
  final Color? c, d, solid;
  final double top;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p;
    var deco = k.c.puffy(c: c ?? p.surface, d: d, radius: 28);
    if (solid != null) deco = deco.copyWith(fills: [SolidFill(solid!)]);
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: DecoratedBox(
        decoration: deco,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  spacing: 10,
                  children: [
                    k.icon(icon, size: 30, color: p.ink),
                    Expanded(
                      child: Tx(title, style: ts(20, FontWeight.w900, p.ink)),
                    ),
                  ],
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// `.explain p` (19, lh 1.5, margin 0 0 6)
Widget explainP(BuildContext context, String s, {bool notes = true, FontWeight w = FontWeight.w700, Color? color}) {
  final p = Kit.of(context).p;
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: RichPara(s, style: ts(19, w, color ?? p.ink, height: 1.5), colors: richColors(p), notes: notes),
  );
}

/// `.verdict` ok / bad
class Verdict extends StatelessWidget {
  const Verdict({super.key, required this.ok, required this.title, required this.lines});
  final bool ok;
  final String title;
  final List<Widget> lines;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p;
    final t = ok ? p.sage : p.peach;
    return DecoratedBox(
      decoration: k.c.puffy(c: t.tile, d: t.deep, radius: 28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          spacing: 14,
          children: [
            DecoratedBox(
              decoration: k.c.icoDisc(t.deep),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Center(child: k.icon(ok ? 'check' : 'x', size: 32, color: t.deep)),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(title, style: ts(26, FontWeight.w900, t.deep, height: 1.1)),
                  ...lines,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle verdictLine(Palette p) => ts(18, FontWeight.w800, p.ink);

/// `.pbar` progress bar (22 tall, 4 padding, puffy fill)
class PBar extends StatelessWidget {
  const PBar(this.frac, {super.key});
  final double frac;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Container(
      height: 22,
      padding: const EdgeInsets.all(4),
      decoration: k.c.pbar(),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: frac.clamp(0, 1)),
          duration: const Duration(milliseconds: 600),
          curve: const Cubic(.2, .8, .2, 1),
          builder: (_, v, _) => FractionallySizedBox(
            widthFactor: v,
            heightFactor: 1,
            child: v <= 0 ? null : DecoratedBox(decoration: k.c.pbarFill()),
          ),
        ),
      ),
    );
  }
}

/// big result stars (84, middle one raised) – `.bigstars`
class BigStars extends StatelessWidget {
  const BigStars(this.n, {super.key, this.size = 84, this.lift = 18});
  final int n;
  final double size, lift;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    // web: the middle star has margin-top:-lift (its translateY is cancelled by the pop animation); the row stays one star tall
    Widget star(int i) {
      final w = Stars(i < n ? 1 : 0, size: size, palette: k.p, only: 1);
      return i == 1 ? Transform.translate(offset: Offset(0, -lift), child: w) : w;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: SizedBox(
        height: size,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [star(0), star(1), star(2)],
        ),
      ),
    );
  }
}

/// `.hint` (17/700 ink-2, centred, margin-top 16)
Widget hintText(BuildContext context, String s, {double top = 16}) {
  final p = Kit.of(context).p;
  return Padding(
    padding: EdgeInsets.only(top: top),
    child: Tx(s, textAlign: TextAlign.center, style: ts(17, FontWeight.w700, p.ink2)),
  );
}
