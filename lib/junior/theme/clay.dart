// CSS-accurate clay painting: layered backgrounds (linear / radial gradients) + outer AND inset box-shadows
// with CSS geometry (offset, blur, spread). Flutter's BoxShadow has no inset, so this Decoration paints them itself.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// One CSS box-shadow.
@immutable
class Shadow3 {
  final double dx, dy, blur, spread;
  final Color color;
  final bool inset;
  const Shadow3(this.dx, this.dy, this.blur, this.spread, this.color, {this.inset = false});
  const Shadow3.inset(this.dx, this.dy, this.blur, this.spread, this.color) : inset = true;

  Shadow3 scaleAlpha(double f) => Shadow3(dx, dy, blur, spread, withA(color, color.a * f), inset: inset);
  static Shadow3 lerp(Shadow3 a, Shadow3 b, double t) => Shadow3(
    ui.lerpDouble(a.dx, b.dx, t)!,
    ui.lerpDouble(a.dy, b.dy, t)!,
    ui.lerpDouble(a.blur, b.blur, t)!,
    ui.lerpDouble(a.spread, b.spread, t)!,
    Color.lerp(a.color, b.color, t)!,
    inset: b.inset,
  );

  @override
  bool operator ==(Object o) => o is Shadow3 && o.dx == dx && o.dy == dy && o.blur == blur && o.spread == spread && o.color == color && o.inset == inset;
  @override
  int get hashCode => Object.hash(dx, dy, blur, spread, color, inset);
}

/// One CSS background layer.
@immutable
sealed class Fill {
  const Fill();
  Paint paint(Rect r);
  Fill lerpTo(Fill other, double t) => t < .5 ? this : other;
}

class SolidFill extends Fill {
  final Color color;
  const SolidFill(this.color);
  @override
  Paint paint(Rect r) => Paint()..color = color;
  @override
  Fill lerpTo(Fill other, double t) => other is SolidFill
      ? SolidFill(Color.lerp(color, other.color, t)!)
      : other is LinearFill && !other.horizontal
      ? LinearFill.vertical([for (final _ in other.colors) color], other.stops).lerpTo(other, t)
      : super.lerpTo(other, t);
  @override
  bool operator ==(Object o) => o is SolidFill && o.color == color;
  @override
  int get hashCode => color.hashCode;
}

/// linear-gradient(180deg, …) (top to bottom) or 90deg (left to right)
class LinearFill extends Fill {
  final List<Color> colors;
  final List<double> stops;
  final bool horizontal;
  const LinearFill.vertical(this.colors, this.stops) : horizontal = false;
  const LinearFill.horizontal(this.colors, this.stops) : horizontal = true;
  @override
  Paint paint(Rect r) =>
      Paint()..shader = ui.Gradient.linear(horizontal ? r.centerLeft : r.topCenter, horizontal ? r.centerRight : r.bottomCenter, colors, stops);
  @override
  Fill lerpTo(Fill other, double t) {
    if (other is SolidFill) return lerpTo(LinearFill.vertical([for (final _ in colors) other.color], stops), t);
    if (other is LinearFill && other.colors.length == colors.length && other.horizontal == horizontal) {
      return LinearFill._(
        [for (var i = 0; i < colors.length; i++) Color.lerp(colors[i], other.colors[i], t)!],
        [for (var i = 0; i < stops.length; i++) ui.lerpDouble(stops[i], other.stops[i], t)!],
        horizontal,
      );
    }
    return super.lerpTo(other, t);
  }

  const LinearFill._(this.colors, this.stops, this.horizontal);
  @override
  bool operator ==(Object o) => o is LinearFill && _listEq(o.colors, colors) && _listEq(o.stops, stops) && o.horizontal == horizontal;
  @override
  int get hashCode => Object.hash(Object.hashAll(colors), Object.hashAll(stops), horizontal);
}

/// radial-gradient(circle at X% Y%, …) (farthest-corner) or radial-gradient(RX% RY% at X% Y%, …) (ellipse, sizes relative to the box)
class RadialFill extends Fill {
  final double cx, cy; // fractions of the box
  final double? rx, ry; // ellipse radii as fractions of width / height; null = circle to the farthest corner
  final List<Color> colors;
  final List<double> stops;
  const RadialFill.circle(this.cx, this.cy, this.colors, this.stops) : rx = null, ry = null;
  const RadialFill.ellipse(this.rx, this.ry, this.cx, this.cy, this.colors, this.stops);
  @override
  Paint paint(Rect r) {
    final c = Offset(r.left + cx * r.width, r.top + cy * r.height);
    if (rx == null) {
      final d = [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight].map((p) => (p - c).distance).reduce(math.max);
      return Paint()..shader = ui.Gradient.radial(c, d, colors, stops);
    }
    final ex = rx! * r.width, ey = ry! * r.height;
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(1, ey / ex, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    return Paint()..shader = ui.Gradient.radial(c, ex, colors, stops, TileMode.clamp, m.storage);
  }

  @override
  Fill lerpTo(Fill other, double t) {
    if (other is RadialFill && other.colors.length == colors.length && other.rx == rx) {
      return rx == null
          ? RadialFill.circle(cx, cy, [for (var i = 0; i < colors.length; i++) Color.lerp(colors[i], other.colors[i], t)!], stops)
          : RadialFill.ellipse(rx, ry, cx, cy, [for (var i = 0; i < colors.length; i++) Color.lerp(colors[i], other.colors[i], t)!], stops);
    }
    return super.lerpTo(other, t);
  }

  @override
  bool operator ==(Object o) => o is RadialFill && o.cx == cx && o.cy == cy && o.rx == rx && o.ry == ry && _listEq(o.colors, colors) && _listEq(o.stops, stops);
  @override
  int get hashCode => Object.hash(cx, cy, rx, ry, Object.hashAll(colors), Object.hashAll(stops));
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A box painted like the CSS: `background: layer1, layer2…; box-shadow: s1, s2…; border-radius`.
/// Layers and shadows are given in CSS order (the first is on top).
@immutable
class ClayDecoration extends Decoration {
  final List<Fill> fills;
  final List<Shadow3> shadows;
  final BorderRadius radius;

  /// a solid inner ring (CSS `inset 0 0 0 Npx color`) is just a shadow; kept in [shadows].
  const ClayDecoration({this.fills = const [], this.shadows = const [], this.radius = BorderRadius.zero});

  ClayDecoration copyWith({List<Fill>? fills, List<Shadow3>? shadows, BorderRadius? radius}) =>
      ClayDecoration(fills: fills ?? this.fills, shadows: shadows ?? this.shadows, radius: radius ?? this.radius);

  @override
  EdgeInsetsGeometry get padding => EdgeInsets.zero;

  @override
  bool hitTest(Size size, Offset position, {TextDirection? textDirection}) => radius.toRRect(Offset.zero & size).contains(position);

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) => Path()..addRRect(radius.resolve(textDirection).toRRect(rect));

  @override
  ClayDecoration? lerpFrom(Decoration? a, double t) => a is ClayDecoration ? ClayDecoration.lerp(a, this, t) : null;
  @override
  ClayDecoration? lerpTo(Decoration? b, double t) => b is ClayDecoration ? ClayDecoration.lerp(this, b, t) : null;

  /// CSS-like interpolation: shadow lists are padded with transparent copies so geometry and colour both animate.
  static ClayDecoration lerp(ClayDecoration a, ClayDecoration b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    final n = math.max(a.shadows.length, b.shadows.length);
    Shadow3 at(List<Shadow3> l, List<Shadow3> o, int i) => i < l.length ? l[i] : o[i].scaleAlpha(0);
    final sh = <Shadow3>[];
    for (var i = 0; i < n; i++) {
      final x = at(a.shadows, b.shadows, i), y = at(b.shadows, a.shadows, i);
      if (x.inset == y.inset) {
        sh.add(Shadow3.lerp(x, y, t));
      } else {
        sh
          ..add(x.scaleAlpha(1 - t))
          ..add(y.scaleAlpha(t));
      }
    }
    final fills = a.fills.length == b.fills.length ? [for (var i = 0; i < a.fills.length; i++) a.fills[i].lerpTo(b.fills[i], t)] : (t < .5 ? a.fills : b.fills);
    return ClayDecoration(fills: fills, shadows: sh, radius: BorderRadius.lerp(a.radius, b.radius, t)!);
  }

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _ClayPainter(this);

  @override
  bool operator ==(Object o) => o is ClayDecoration && _listEq(o.fills, fills) && _listEq(o.shadows, shadows) && o.radius == radius;
  @override
  int get hashCode => Object.hash(Object.hashAll(fills), Object.hashAll(shadows), radius);
}

class _ClayPainter extends BoxPainter {
  _ClayPainter(this.d);
  final ClayDecoration d;

  static RRect _spread(RRect r, double s) {
    Radius adj(Radius x) => Radius.elliptical(math.max(0, x.x + s), math.max(0, x.y + s));
    return RRect.fromLTRBAndCorners(
      r.left - s,
      r.top - s,
      r.right + s,
      r.bottom + s,
      topLeft: adj(r.tlRadius),
      topRight: adj(r.trRadius),
      bottomLeft: adj(r.blRadius),
      bottomRight: adj(r.brRadius),
    );
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final size = cfg.size!;
    final rect = offset & size;
    final rr = d.radius.resolve(TextDirection.ltr).toRRect(rect).scaleRadii();
    // outer shadows, bottom-most (last in CSS) first
    for (final s in d.shadows.reversed) {
      if (s.inset || s.color.a == 0) continue;
      final p = Paint()..color = s.color;
      if (s.blur > 0) p.maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur / 2);
      canvas.drawRRect(_spread(rr, s.spread).shift(Offset(s.dx, s.dy)), p);
    }
    // backgrounds, bottom-most first
    for (final f in d.fills.reversed) {
      canvas.drawRRect(rr, f.paint(rect));
    }
    // inset shadows, clipped to the box
    final insets = d.shadows.reversed.where((s) => s.inset && s.color.a > 0).toList();
    if (insets.isEmpty) return;
    canvas.save();
    canvas.clipRRect(rr);
    for (final s in insets) {
      final hole = _spread(rr, -s.spread).shift(Offset(s.dx, s.dy));
      final pad = s.blur + s.spread.abs() + s.dx.abs() + s.dy.abs() + 4;
      final path = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(pad))
        ..addRRect(hole);
      final p = Paint()..color = s.color;
      if (s.blur > 0) p.maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur / 2);
      canvas.drawPath(path, p);
    }
    canvas.restore();
  }
}
