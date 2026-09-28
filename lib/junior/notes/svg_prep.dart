// SVG preprocessing for flutter_svg, so textbook diagrams look like they do in the browser:
//  * <marker> arrowheads are expanded into plain shapes at the path ends (flutter_svg does not draw markers)
//  * paint-order="stroke" text (white halo behind labels) becomes a stroke-only copy under a fill-only copy
//  * Nunito font family -> the bundled JuniorNunito
//  * applyShow(): [data-s] elements are only shown for their step keys; [data-hl] elements are dimmed (opacity .28) for others
import 'dart:math' as math;

import 'package:flutter/services.dart';

class SvgStore {
  SvgStore._();
  static final _raw = <String, String>{};
  static final _shown = <String, String>{};
  static final _vb = <String, List<double>>{};

  static bool has(String path) => _raw.containsKey(path);

  static Future<void> preload(AssetBundle bundle, Iterable<String> paths) async {
    await Future.wait([
      for (final p in paths.where((p) => !_raw.containsKey(p)))
        bundle.loadString(p).then((s) {
          _raw[p] = prepSvg(s);
        }),
    ]);
  }

  /// viewBox [x, y, w, h] (default 0 0 320 320)
  static List<double> viewBox(String path) => _vb.putIfAbsent(path, () {
    final m = RegExp(r'viewBox="([^"]+)"').firstMatch(_raw[path] ?? '');
    final v = (m?[1] ?? '0 0 320 320').trim().split(RegExp(r'[\s,]+')).map(double.parse).toList();
    return v.length == 4 ? v : [0, 0, 320, 320];
  });

  /// the prepared SVG with the [key] step shown (null = everything)
  static String svg(String path, String? key) {
    final raw = _raw[path];
    if (raw == null) return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"/>';
    if (!raw.contains('data-s=') && !raw.contains('data-hl=')) return raw;
    return _shown.putIfAbsent('$path|$key', () => applyShow(raw, key));
  }

  /// used by the graph cards (SVG generated in code)
  static String showString(String svg, String? key) => applyShow(svg, key);
}

// ---------------------------------------------------------------- tag scanning helpers
final _attrRe = RegExp(r'([\w:-]+)="([^"]*)"');

class _Tag {
  final int start, end; // [start, end) of the start tag
  final String name;
  final bool selfClosing;
  _Tag(this.start, this.end, this.name, this.selfClosing);
}

Iterable<_Tag> _startTags(String s) sync* {
  final re = RegExp(r'<([a-zA-Z][\w:-]*)\b[^>]*?(/?)>');
  for (final m in re.allMatches(s)) {
    yield _Tag(m.start, m.end, m[1]!, m[2] == '/');
  }
}

/// end index (exclusive) of the element starting at [t]
int _elementEnd(String s, _Tag t) {
  if (t.selfClosing) return t.end;
  final re = RegExp('<(/?)${RegExp.escape(t.name)}\\b[^>]*?(/?)>');
  var depth = 1;
  for (final m in re.allMatches(s, t.end)) {
    if (m[1] == '/') {
      if (--depth == 0) return m.end;
    } else if (m[2] != '/') {
      depth++;
    }
  }
  return s.length;
}

String _attr(String tag, String name) => RegExp('\\s$name="([^"]*)"').firstMatch(tag)?[1] ?? '';

// ---------------------------------------------------------------- one-time preparation
String prepSvg(String s) {
  s = s.replaceAll(RegExp(r'''font-family="(?:Nunito|'Nunito')[^"]*"'''), 'font-family="JuniorNunito"');
  s = s.replaceAll(RegExp(r'\sclass="swing"'), '');
  if (s.contains('<marker')) s = _expandMarkers(s);
  if (s.contains('paint-order')) s = _haloText(s);
  return s;
}

String _haloText(String s) => s.replaceAllMapped(RegExp(r'<text\b([^>]*?)paint-order="stroke"([^>]*)>(.*?)</text>', dotAll: true), (m) {
  final attrs = '${m[1]}${m[2]}';
  final strokeOnly = attrs.replaceAll(RegExp(r'\sfill="[^"]*"'), '');
  final fillOnly = attrs.replaceAll(RegExp(r'\sstroke(-width|-linejoin|-linecap)?="[^"]*"'), '');
  return '<text$strokeOnly fill="none">${m[3]}</text><text$fillOnly>${m[3]}</text>';
});

class _Marker {
  final List<double> vb;
  final double refX, refY, w, h;
  final String orient, inner;
  _Marker(this.vb, this.refX, this.refY, this.w, this.h, this.orient, this.inner);
}

String _expandMarkers(String s) {
  final markers = <String, _Marker>{};
  s = s.replaceAllMapped(RegExp(r'<marker\b([^>]*)>(.*?)</marker>', dotAll: true), (m) {
    final a = m[1]!;
    final vb = (_attr(a, 'viewBox').isEmpty ? '0 0 10 10' : _attr(a, 'viewBox')).split(RegExp(r'[\s,]+')).map(double.parse).toList();
    double n(String k, double d) => double.tryParse(_attr(a, k)) ?? d;
    markers[_attr(a, 'id')] = _Marker(vb, n('refX', 0), n('refY', 0), n('markerWidth', 3), n('markerHeight', 3), _attr(a, 'orient'), m[2]!);
    return '';
  });
  return s.replaceAllMapped(RegExp(r'<path\b[^>]*marker-(?:end|start)="url\(#[^)]+\)"[^>]*/>'), (m) {
    final tag = m[0]!;
    final ends = pathEnds(_attr(tag, 'd'));
    if (ends == null) return tag;
    final sw = double.tryParse(_attr(tag, 'stroke-width')) ?? 1;
    final keep = [for (final k in ['data-s', 'data-hl']) if (_attr(tag, k).isNotEmpty) ' $k="${_attr(tag, k)}"'].join();
    final out = StringBuffer(tag);
    void place(String id, math.Point<double> at, math.Point<double> dir, bool start) {
      final mk = markers[id];
      if (mk == null) return;
      var ang = math.atan2(dir.y, dir.x) * 180 / math.pi;
      if (start && mk.orient == 'auto-start-reverse') ang += 180;
      if (mk.orient != 'auto' && mk.orient != 'auto-start-reverse') ang = double.tryParse(mk.orient) ?? 0;
      final k = math.min(mk.w * sw / mk.vb[2], mk.h * sw / mk.vb[3]);
      out.write('<g$keep transform="translate(${at.x} ${at.y}) rotate($ang) scale($k) translate(${-mk.refX} ${-mk.refY})">${mk.inner}</g>');
    }

    final me = RegExp(r'marker-end="url\(#([^)]+)\)"').firstMatch(tag);
    final ms = RegExp(r'marker-start="url\(#([^)]+)\)"').firstMatch(tag);
    if (ms != null) place(ms[1]!, ends.$1, ends.$2, true);
    if (me != null) place(me[1]!, ends.$3, ends.$4, false);
    return out.toString().replaceFirst(RegExp(r'\smarker-(end|start)="[^"]*"'), '').replaceFirst(RegExp(r'\smarker-(end|start)="[^"]*"'), '');
  });
}

/// start point + direction and end point + direction of an SVG path
(math.Point<double>, math.Point<double>, math.Point<double>, math.Point<double>)? pathEnds(String d) {
  final toks = RegExp(r'[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?').allMatches(d).map((m) => m[0]!).toList();
  var i = 0;
  String cmd = 'M';
  var cur = const math.Point(0.0, 0.0), start = cur;
  math.Point<double>? p0, d0, p1, d1;
  double num() => double.parse(toks[i++]);
  bool isNum() => i < toks.length && !RegExp(r'^[A-Za-z]$').hasMatch(toks[i]);
  void seg(math.Point<double> from, math.Point<double> c1, math.Point<double> c2, math.Point<double> to) {
    var ds = c1 - from;
    if (ds.magnitude < 1e-9) ds = to - from;
    var de = to - c2;
    if (de.magnitude < 1e-9) de = to - from;
    if (p0 == null) {
      p0 = from;
      d0 = ds;
    }
    p1 = to;
    d1 = de;
  }

  while (i < toks.length) {
    if (!isNum()) cmd = toks[i++];
    final rel = cmd == cmd.toLowerCase();
    math.Point<double> pt(double x, double y) => rel ? math.Point(cur.x + x, cur.y + y) : math.Point(x, y);
    switch (cmd.toUpperCase()) {
      case 'M':
        cur = pt(num(), num());
        start = cur;
        cmd = rel ? 'l' : 'L';
      case 'L':
      case 'T':
        final to = pt(num(), num());
        seg(cur, cur, cur, to);
        cur = to;
      case 'H':
        final x = num();
        final to = math.Point(rel ? cur.x + x : x, cur.y);
        seg(cur, cur, cur, to);
        cur = to;
      case 'V':
        final y = num();
        final to = math.Point(cur.x, rel ? cur.y + y : y);
        seg(cur, cur, cur, to);
        cur = to;
      case 'Q':
        final c = pt(num(), num()), to = pt(num(), num());
        seg(cur, c, c, to);
        cur = to;
      case 'S':
        final c2 = pt(num(), num()), to = pt(num(), num());
        seg(cur, c2, c2, to);
        cur = to;
      case 'C':
        final c1 = pt(num(), num()), c2 = pt(num(), num()), to = pt(num(), num());
        seg(cur, c1, c2, to);
        cur = to;
      case 'A':
        num();
        num();
        num();
        num();
        num();
        final to = pt(num(), num());
        seg(cur, cur, cur, to);
        cur = to;
      case 'Z':
        seg(cur, cur, cur, start);
        cur = start;
      default:
        return null;
    }
    if (cmd.toUpperCase() == 'Z' && isNum()) cmd = 'L';
  }
  if (p0 == null) return null;
  return (p0!, d0!, p1!, d1!);
}

// ---------------------------------------------------------------- step keys
String applyShow(String s, String? key) {
  final edits = <(int, int, String)>[]; // replace [a, b) with text
  var skipUntil = -1;
  for (final t in _startTags(s)) {
    if (t.start < skipUntil) continue;
    final tag = s.substring(t.start, t.end);
    final ds = _attr(tag, 'data-s');
    if (ds.isNotEmpty && key != null && !ds.split(RegExp(r'\s+')).contains(key)) {
      final e = _elementEnd(s, t);
      edits.add((t.start, e, ''));
      skipUntil = e;
      continue;
    }
    final hl = _attr(tag, 'data-hl');
    if (hl.isNotEmpty && key != null && !hl.split(RegExp(r'\s+')).contains(key)) {
      var nt = tag.replaceAll(RegExp(r'\sopacity="[^"]*"'), '');
      nt = nt.replaceFirstMapped(RegExp(r'^<([\w:-]+)'), (m) => '<${m[1]} opacity=".28"');
      edits.add((t.start, t.end, nt));
    }
  }
  if (edits.isEmpty) return s;
  final b = StringBuffer();
  var at = 0;
  for (final (a, e, txt) in edits) {
    b.write(s.substring(at, a));
    b.write(txt);
    at = e;
  }
  b.write(s.substring(at));
  return b.toString();
}

/// attributes helper for other modules
Map<String, String> svgAttrs(String tag) => {for (final m in _attrRe.allMatches(tag)) m[1]!: m[2]!};
