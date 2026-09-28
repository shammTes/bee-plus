// Reusable clay widgets: Press (raised → pressed-in with the web's timings), buttons, toggles, bars.
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../state/app_state.dart';
import '../theme/clay.dart';
import '../theme/notes_styles.dart';
import '../theme/styles.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'tx.dart';

final _clayL = Clay(Palette.light), _clayD = Clay(Palette.darkP);

/// Theme access: `final k = Kit.of(context); k.p.ink, k.c.puffy()`, and labels `k.t('home')`.
class Kit {
  Kit._(this.s) : p = s.dark ? Palette.darkP : Palette.light, c = s.dark ? _clayD : _clayL;
  final AppState s;
  final Palette p;
  final Clay c;
  static Kit of(BuildContext ctx) => Kit._(AppScope.of(ctx));
  String t(String k, [Map<String, Object>? v]) => s.t(k, v);
  Widget icon(String name, {double size = 26, Color? color}) => SvgIcon(name, size: size, color: color ?? p.ink, palette: p);
}

/// spring used by `.press` on release (cubic-bezier(.34,1.56,.64,1))
const springCurve = Cubic(.34, 1.56, .64, 1);

/// Anything tappable in clay: animates between [deco] and [pressedDeco] and moves down by [dy] (and scales) while pressed.
/// [selected] shows the pressed look permanently (chosen key, current tab).
class Press extends StatefulWidget {
  const Press({
    super.key,
    required this.child,
    this.onTap,
    this.deco,
    this.pressedDeco,
    this.dy = 0,
    this.scale = 1,
    this.selected = false,
    this.padding = EdgeInsets.zero,
    this.constraints,
    this.spring = false,
    this.semanticsLabel,
    this.enabled = true,
  });
  final Widget child;
  final VoidCallback? onTap;
  final ClayDecoration? deco, pressedDeco;
  final double dy, scale;
  final bool selected, spring, enabled;
  final EdgeInsets padding;
  final BoxConstraints? constraints;
  final String? semanticsLabel;

  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: widget.selected ? 1 : 0);
  Offset? _downAt;

  @override
  void didUpdateWidget(Press old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _c.animateTo(widget.selected ? 1 : 0, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent e) {
    if (!widget.enabled || widget.onTap == null) return;
    _downAt = e.position;
    _c.animateTo(
      1,
      duration: Duration(milliseconds: widget.spring ? 80 : 120),
      curve: Curves.easeOut,
    );
  }

  void _up([Object? _]) {
    if (_downAt == null) return;
    _downAt = null;
    if (widget.selected) return;
    _c.animateTo(
      0,
      duration: Duration(milliseconds: widget.spring ? 350 : 120),
      curve: widget.spring ? springCurve : Curves.easeOut,
    );
  }

  void _move(PointerMoveEvent e) {
    if (_downAt != null && (e.position - _downAt!).distance > 10) _up();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    Widget box = AnimatedBuilder(
      animation: _c,
      child: Padding(padding: w.padding, child: w.child),
      builder: (context, child) {
        final t = _c.value;
        final deco = w.deco == null ? null : (w.pressedDeco == null ? w.deco! : ClayDecoration.lerp(w.deco!, w.pressedDeco!, t.clamp(0.0, 1.0)));
        Widget b = deco == null ? child! : DecoratedBox(decoration: deco, child: child);
        if (w.constraints != null) b = ConstrainedBox(constraints: w.constraints!, child: b);
        final s = lerpDouble(1, w.scale, t)!;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translateByDouble(0, w.dy * t, 0, 1)
            ..scaleByDouble(s, s, 1, 1),
          child: b,
        );
      },
    );
    if (w.onTap == null) return box;
    return Semantics(
      button: true,
      label: w.semanticsLabel,
      enabled: w.enabled,
      child: Listener(
        onPointerDown: _down,
        onPointerUp: _up,
        onPointerCancel: _up,
        onPointerMove: _move,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: w.enabled ? w.onTap : null, child: box),
      ),
    );
  }
}

enum BtnKind { primary, soft, danger, yes, nope, ghost }

/// `.btn` (min 60 tall, pill, 20px/900, icon 26); disabled = pushed in and grey like `.btn[disabled]`
class ClayButton extends StatelessWidget {
  const ClayButton({
    super.key,
    required this.label,
    this.icon,
    this.kind = BtnKind.primary,
    this.onTap,
    this.minHeight = 60,
    this.fontSize = 20,
    this.enabled = true,
    this.trailingIcon = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
  });
  final String label;
  final String? icon;
  final BtnKind kind;
  final VoidCallback? onTap;
  final double minHeight, fontSize;
  final bool enabled, trailingIcon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, c = k.c;
    var (d, pd, fg) = switch (kind) {
      BtnKind.primary => (c.btnPrimary(), c.btnPrimaryPressed(), p.onPrimary),
      BtnKind.soft => (c.btnSoft(), c.btnSoftPressed(), p.ink),
      BtnKind.danger => (c.btnDanger(), c.btnDangerPressed(), p.peach.deep),
      BtnKind.yes => (c.btnTone(p.sage), c.btnTonePressed(p.sage), p.sage.deep),
      BtnKind.nope => (c.btnTone(p.peach), c.btnTonePressed(p.peach), p.peach.deep),
      BtnKind.ghost => (const ClayDecoration(), const ClayDecoration(), p.ink2),
    };
    if (!enabled) {
      d = c.btnDisabled();
      pd = d;
      fg = p.ink2;
    }
    final ic = icon == null ? null : k.icon(icon!, size: 26, color: fg);
    final text = Flexible(
      child: Tx(
        label,
        textAlign: TextAlign.center,
        style: ts(fontSize, FontWeight.w900, fg, height: 1.2).copyWith(
          decoration: kind == BtnKind.ghost ? TextDecoration.underline : null,
          decorationColor: fg,
        ),
      ),
    );
    final child = Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 10, children: [if (ic != null && !trailingIcon) ic, text, if (ic != null && trailingIcon) ic]);
    if (!enabled) {
      return Transform.translate(
        offset: const Offset(0, 5),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight, minWidth: double.infinity),
          child: DecoratedBox(
            decoration: d,
            child: Padding(padding: padding, child: Center(heightFactor: 1, child: child)),
          ),
        ),
      );
    }
    return Press(
      onTap: onTap ?? () {},
      deco: d,
      pressedDeco: pd,
      dy: kind == BtnKind.ghost ? 0 : 5,
      constraints: BoxConstraints(minHeight: minHeight, minWidth: double.infinity),
      padding: padding,
      child: Center(heightFactor: 1, child: child),
    );
  }
}

/// `.cbtn` round 52px button (back)
class RoundButton extends StatelessWidget {
  const RoundButton({super.key, required this.icon, required this.onTap, this.label});
  final String icon;
  final VoidCallback onTap;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Press(
      onTap: onTap,
      semanticsLabel: label,
      deco: k.c.cbtn(),
      pressedDeco: k.c.cbtnPressed(),
      dy: 4,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Center(child: k.icon(icon, size: 26, color: k.p.ink)),
      ),
    );
  }
}

/// `.lang` English | ትግርኛ toggle (debossed track, raised keys, chosen key pressed in)
class LangToggle extends StatelessWidget {
  const LangToggle({super.key});
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p;
    Widget key(String l, String name) {
      final on = k.s.lang == l;
      return Press(
        onTap: () => k.s.setLang(l),
        selected: on,
        deco: k.c.key(),
        pressedDeco: k.c.keyOn(),
        dy: 4,
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: SizedBox(
          height: 48,
          child: Center(widthFactor: 1, child: Tx(name, style: ts(16, FontWeight.w900, on ? p.sage.deep : p.ink2, normal: true))),
        ),
      );
    }

    return DecoratedBox(
      decoration: k.c.track(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 5, 5, 9),
        child: Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [key('en', 'English'), key('ti', 'ትግርኛ')]),
      ),
    );
  }
}

/// `.minibar` progress (12px)
class MiniBar extends StatelessWidget {
  const MiniBar(this.pct, {super.key});
  final int pct;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Container(
      height: 12,
      margin: const EdgeInsets.only(top: 6),
      decoration: k.c.minibar(),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: (pct / 100).clamp(0, 1),
          heightFactor: 1,
          child: DecoratedBox(decoration: k.c.minibarFill()),
        ),
      ),
    );
  }
}

/// `.tag` (butter pill)
class TagPill extends StatelessWidget {
  const TagPill(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return DecoratedBox(
      decoration: k.c.tag(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Tx(text, style: ts(14, FontWeight.w900, k.p.butter.deep, spacing: .28, normal: true)),
      ),
    );
  }
}

/// `.sw` switch (64×36, knob 28)
class ClaySwitch extends StatelessWidget {
  const ClaySwitch(this.on, {super.key});
  final bool on;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 64,
      height: 36,
      decoration: k.c.swTrack(on),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 300),
        curve: springCurve,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: DecoratedBox(decoration: k.c.swKnob(), child: const SizedBox(width: 28, height: 28)),
        ),
      ),
    );
  }
}
