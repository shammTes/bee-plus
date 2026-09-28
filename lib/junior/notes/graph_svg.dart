// Number line / coordinate plane drawn from JSON as SVG (port of the web app's numberLineSVG / planeSVG).
// Every part may carry "s" (shown only for those step keys, like data-s in the SVG files).
import 'dart:math' as math;

import '../data/notes_models.dart';

const _ink = '#3E3129', _grid = '#E6DACB', _axis = '#6A5B50', _pt = '#C24E32', _rng = '#2A7A6B';
const _ln = ['#2F5F8F', '#C24E32', '#2A7A6B', '#6A4C9C', '#A8412A'];
const _font = ' font-family="JuniorNunito"';

String _gnum(double x) {
  final r = (x * 1000).round() / 1000;
  final s = r == r.roundToDouble() ? r.toInt().toString() : r.toString();
  return s.replaceFirst('-', '\u2212');
}

String _f(double v) => v.toStringAsFixed(1);
String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
String _gds(List<String> s) => s.isEmpty ? '' : ' data-s="${_esc(s.join(' '))}"';

String graphSvg(GraphSpec g) => g.kind == 'plane' ? _plane(g) : _numberLine(g);

String _numberLine(GraphSpec g) {
  final min = g.min ?? 0, max = g.max ?? 10;
  const L = 26.0, rt = 294.0, y = 70.0;
  double X(double v) => L + (v - min) / (max - min) * (rt - L);
  final step = g.step ?? 1, every = g.labelEvery ?? 1;
  final h = StringBuffer('<line x1="6" y1="$y" x2="314" y2="$y" stroke="$_ink" stroke-width="2.5"/><path d="M4 ${y}l10-6v12zM316 ${y}l-10-6v12z" fill="$_ink"/>');
  for (var k = 0; ; k++) {
    final v = min + k * step;
    if (v > max + 1e-9) break;
    final x = _f(X(v));
    h.write('<line x1="$x" y1="${y - 8}" x2="$x" y2="${y + 8}" stroke="$_ink" stroke-width="2"/>');
    if (k % every == 0) h.write('<text x="$x" y="${y + 30}" font-size="15" font-weight="800" text-anchor="middle" fill="$_ink"$_font>${_esc(_gnum(v))}</text>');
  }
  for (final r in g.ranges) {
    final a = r.from == null ? 6.0 : X(r.from!), b = r.to == null ? 314.0 : X(r.to!);
    const c = _rng;
    var p = '<line x1="$a" y1="$y" x2="$b" y2="$y" stroke="$c" stroke-width="8" stroke-linecap="round" opacity=".8"/>';
    p += r.from == null ? '<path d="M2 ${y}l14-9v18z" fill="$c"/>' : '<circle cx="$a" cy="$y" r="8" fill="${r.fromOpen ? '#fff' : c}" stroke="$c" stroke-width="3.5"/>';
    p += r.to == null ? '<path d="M318 ${y}l-14-9v18z" fill="$c"/>' : '<circle cx="$b" cy="$y" r="8" fill="${r.toOpen ? '#fff' : c}" stroke="$c" stroke-width="3.5"/>';
    h.write('<g${_gds(r.s)}>$p</g>');
  }
  for (final (k, j) in g.jumps.indexed) {
    final a = X(j.from), b = X(j.to), m = (a + b) / 2, hh = 26 + math.min(18, (b - a).abs() / 8), c = _ln[k % _ln.length], dir = b > a ? -1 : 1;
    h.write(
      '<g><path d="M$a ${y - 10}Q$m ${y - 10 - hh * 2} $b ${y - 10}" fill="none" stroke="$c" stroke-width="3"/><path d="M$b ${y - 9}l${dir * 9} -9l${dir * 2} 11z" fill="$c"/>'
      '${j.label != null ? '<text x="$m" y="${y - 16 - hh}" font-size="15" font-weight="900" text-anchor="middle" fill="$c"$_font>${_esc(j.label!)}</text>' : ''}</g>',
    );
  }
  for (final p in g.points) {
    final x = X(p.x), c = p.color ?? _pt;
    h.write(
      '<g${_gds(p.s)}><circle cx="$x" cy="$y" r="8" fill="${p.open ? '#fff' : c}" stroke="$c" stroke-width="3.5"/>'
      '${p.label != null ? '<text x="$x" y="${y + 56}" font-size="16" font-weight="900" text-anchor="middle" fill="$c"$_font>${_esc(p.label!)}</text><path d="M$x ${y + 12}v26" stroke="$c" stroke-width="1.5" stroke-dasharray="3 3"/>' : ''}</g>',
    );
  }
  final hasLab = g.points.any((p) => p.label != null);
  return '<svg viewBox="0 0 320 ${hasLab ? 136 : 112}" xmlns="http://www.w3.org/2000/svg">$h</svg>';
}

List<double>? _clip(double x1, double y1, double x2, double y2, GraphSpec g) {
  var t0 = 0.0, t1 = 1.0;
  final dx = x2 - x1, dy = y2 - y1;
  for (final (p, q) in [(-dx, x1 - g.xmin!), (dx, g.xmax! - x1), (-dy, y1 - g.ymin!), (dy, g.ymax! - y1)]) {
    if (p == 0) {
      if (q < 0) return null;
      continue;
    }
    final r = q / p;
    if (p < 0) {
      if (r > t1) return null;
      if (r > t0) t0 = r;
    } else {
      if (r < t0) return null;
      if (r < t1) t1 = r;
    }
  }
  return [x1 + t0 * dx, y1 + t0 * dy, x1 + t1 * dx, y1 + t1 * dy];
}

String _plane(GraphSpec g) {
  final xmin = g.xmin!, xmax = g.xmax!, ymin = g.ymin!, ymax = g.ymax!;
  const pad = 22.0;
  final xs = xmax - xmin, ys = ymax - ymin, u = math.min((320 - 2 * pad) / xs, (340 - 2 * pad) / ys), W = xs * u + 2 * pad, H = ys * u + 2 * pad;
  String X(double x) => _f(pad + (x - xmin) * u);
  String Y(double y) => _f(pad + (ymax - y) * u);
  double xn(double x) => double.parse(X(x));
  double yn(double y) => double.parse(Y(y));
  final gs = (g.gridStep ?? 1).toDouble(), le = (g.labelEvery ?? 1).toDouble();
  final h = StringBuffer();
  if (g.grid) {
    for (var x = (xmin / gs).ceil() * gs; x <= xmax + 1e-9; x += gs) {
      h.write('<line x1="${X(x)}" y1="${Y(ymin)}" x2="${X(x)}" y2="${Y(ymax)}" stroke="$_grid" stroke-width="1.2"/>');
    }
    for (var y = (ymin / gs).ceil() * gs; y <= ymax + 1e-9; y += gs) {
      h.write('<line x1="${X(xmin)}" y1="${Y(y)}" x2="${X(xmax)}" y2="${Y(y)}" stroke="$_grid" stroke-width="1.2"/>');
    }
  }
  if (g.axes) {
    if (ymin <= 0 && ymax >= 0) {
      h.write(
        '<line x1="${pad - 8}" y1="${Y(0)}" x2="${W - pad + 10}" y2="${Y(0)}" stroke="$_axis" stroke-width="2.2"/><path d="M${W - pad + 14} ${Y(0)}l-10-5v10z" fill="$_axis"/>'
        '<text x="${W - 10}" y="${yn(0) - 8}" font-size="15" font-weight="900" fill="$_axis" font-style="italic"$_font>x</text>',
      );
    }
    if (xmin <= 0 && xmax >= 0) {
      h.write(
        '<line x1="${X(0)}" y1="${H - pad + 8}" x2="${X(0)}" y2="${pad - 10}" stroke="$_axis" stroke-width="2.2"/><path d="M${X(0)} ${pad - 14}l-5 10h10z" fill="$_axis"/>'
        '<text x="${xn(0) + 8}" y="${pad - 6}" font-size="15" font-weight="900" fill="$_axis" font-style="italic"$_font>y</text>',
      );
    }
    for (var x = (xmin / le).ceil() * le; x <= xmax + 1e-9; x += le) {
      if (x.abs() > 1e-9 && ymin <= 0 && ymax >= 0) {
        h.write('<text x="${X(x)}" y="${yn(0) + 16}" font-size="12" font-weight="800" text-anchor="middle" fill="$_axis"$_font>${_gnum(x)}</text>');
      }
    }
    for (var y = (ymin / le).ceil() * le; y <= ymax + 1e-9; y += le) {
      if (y.abs() > 1e-9 && xmin <= 0 && xmax >= 0) {
        h.write('<text x="${xn(0) - 6}" y="${yn(y) + 4}" font-size="12" font-weight="800" text-anchor="end" fill="$_axis"$_font>${_gnum(y)}</text>');
      }
    }
    if (xmin <= 0 && xmax >= 0 && ymin <= 0 && ymax >= 0) {
      h.write('<text x="${xn(0) - 6}" y="${yn(0) + 16}" font-size="12" font-weight="800" text-anchor="end" fill="$_axis"$_font>0</text>');
    }
  }
  for (final (k, p) in g.polygons.indexed) {
    final c = p.color ?? _ln[(k + 2) % _ln.length];
    h.write(
      '<g${_gds(p.s)}><polygon points="${p.pts.map((q) => '${X(q[0])},${Y(q[1])}').join(' ')}" fill="$c" fill-opacity=".18" stroke="$c" stroke-width="3" stroke-linejoin="round"/></g>',
    );
  }
  for (final (k, l) in g.lines.indexed) {
    final c = l.color ?? _ln[k % _ln.length];
    double x1, y1, x2, y2;
    if (l.x != null) {
      x1 = x2 = l.x!;
      y1 = ymin - 1;
      y2 = ymax + 1;
    } else if (l.p1 != null && l.p2 != null) {
      x1 = l.p1![0];
      y1 = l.p1![1];
      x2 = l.p2![0];
      y2 = l.p2![1];
      if (!l.seg) {
        final dx = x2 - x1, dy = y2 - y1, k2 = 4 * (xs + ys) / math.sqrt(dx * dx + dy * dy);
        x1 -= dx * k2;
        y1 -= dy * k2;
        x2 += dx * k2;
        y2 += dy * k2;
      }
    } else {
      final m = l.m ?? 0, cc = l.c ?? 0;
      x1 = xmin - 1;
      x2 = xmax + 1;
      y1 = m * x1 + cc;
      y2 = m * x2 + cc;
    }
    var lab = '';
    final cl = _clip(x1, y1, x2, y2, g);
    if (cl == null) continue;
    if (l.label != null) {
      const tt = 0.8;
      var lx = cl[0] + (cl[2] - cl[0]) * tt;
      final ly = cl[1] + (cl[3] - cl[1]) * tt;
      final up = (cl[3] - cl[1]) * (cl[2] - cl[0]) >= 0;
      lx += up ? 0.25 : -0.25;
      lab = '<text x="${X(lx)}" y="${yn(ly) + 16}" font-size="14" font-weight="900" text-anchor="${up ? 'start' : 'end'}" fill="$c" stroke="#fff" stroke-width="4" paint-order="stroke"$_font>${_esc(l.label!)}</text>';
    }
    h.write(
      '<g${_gds(l.s)}><line x1="${X(cl[0])}" y1="${Y(cl[1])}" x2="${X(cl[2])}" y2="${Y(cl[3])}" stroke="$c" stroke-width="3.2" stroke-linecap="round"${l.dash ? ' stroke-dasharray="8 6"' : ''}/>$lab</g>',
    );
  }
  for (final p in g.points) {
    final c = p.color ?? _pt;
    const dx = 8.0, dy = -8.0;
    h.write(
      '<g${_gds(p.s)}><circle cx="${X(p.x)}" cy="${Y(p.y ?? 0)}" r="6" fill="${p.open ? '#fff' : c}" stroke="$c" stroke-width="3"/>'
      '${p.label != null ? '<text x="${xn(p.x) + dx}" y="${yn(p.y ?? 0) + dy}" font-size="14" font-weight="900" text-anchor="start" fill="$c" stroke="#fff" stroke-width="4" paint-order="stroke"$_font>${_esc(p.label!)}</text>' : ''}</g>',
    );
  }
  return '<svg viewBox="0 0 ${W.toStringAsFixed(0)} ${H.toStringAsFixed(0)}" xmlns="http://www.w3.org/2000/svg">$h</svg>';
}
