// Rich text of the notes and exams, same rules as the web app's ntext()/rich()/nparas():
//   $x$ inline maths (fractions shown full size), $$x$$ display maths, \( \) \[ \] delimiters, **key word**, *italic*,
//   [[highlight]] (grammar/vocab), x^2 / x^(1/2) superscripts, <u>underline</u>, "- " bullet lines.
import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../theme/tokens.dart';

/// one piece of a paragraph: text (with inline markup) or maths
class _Seg {
  final String? text, math;
  final bool display;
  const _Seg.t(this.text) : math = null, display = false;
  const _Seg.m(this.math, this.display) : text = null;
}

final _dollar = RegExp(r'(^|[^$\\])\$([^$\n]+)\$(?!\$)');

/// ntext(): $x$ -> \(x\) with \frac -> \dfrac (young readers), then split maths from text
List<_Seg> _split(String s, {bool notes = true}) {
  if (notes) {
    s = s.replaceAllMapped(_dollar, (m) => '${m[1]}\\(${m[2]!.replaceAll(RegExp(r'\\frac(?![a-z])'), r'\dfrac')}\\)');
  }
  if (!s.contains(r'$$') && !s.contains(r'\(') && !s.contains(r'\[')) return [_Seg.t(s)];
  const delims = [(r'$$', r'$$', true), (r'\[', r'\]', true), (r'\(', r'\)', false)];
  final out = <_Seg>[];
  final buf = StringBuffer();
  var i = 0;
  while (i < s.length) {
    (int, int, int, bool)? hit;
    for (final (o, c, d) in delims) {
      if (s.startsWith(o, i)) {
        final j = s.indexOf(c, i + o.length);
        if (j > i) {
          hit = (o.length, j, c.length, d);
          break;
        }
      }
    }
    if (hit != null) {
      if (buf.isNotEmpty) out.add(_Seg.t(buf.toString()));
      buf.clear();
      out.add(_Seg.m(s.substring(i + hit.$1, hit.$2), hit.$4));
      i = hit.$2 + hit.$3;
      continue;
    }
    buf.write(s[i++]);
  }
  if (buf.isNotEmpty) out.add(_Seg.t(buf.toString()));
  return out;
}

/// Colors used by inline marks
class RichColors {
  final Color butter2, sage3, peach3;
  const RichColors(this.butter2, this.sage3, this.peach3);
  factory RichColors.of(Palette p) => RichColors(p.butter.mid, p.sage.deep, p.peach.deep);
}

class _Style {
  final bool kw, it, hx, u, sup;
  const _Style({this.kw = false, this.it = false, this.hx = false, this.u = false, this.sup = false});
  _Style copy({bool? kw, bool? it, bool? hx, bool? u, bool? sup}) => _Style(kw: kw ?? this.kw, it: it ?? this.it, hx: hx ?? this.hx, u: u ?? this.u, sup: sup ?? this.sup);
}

final _supPrev = RegExp(r'[\w)\]\u00B2\u00B3\u00B9\u2070-\u2079]');
final _supTok = RegExp(r'^[\u2212-]?[A-Za-z0-9]+(?:\.[0-9]+)?');

/// Builds inline spans for one text segment (no maths inside).
class _InlineBuilder {
  _InlineBuilder(this.base, this.c, this.hxMarks, this.strikeHx);
  final TextStyle base;
  final RichColors c;
  final bool hxMarks, strikeHx;
  final spans = <InlineSpan>[];

  TextStyle styleOf(_Style st) {
    var s = base;
    if (st.it) s = s.copyWith(fontStyle: FontStyle.italic);
    if (st.kw) s = s.copyWith(fontWeight: FontWeight.w900);
    if (st.hx) s = s.copyWith(fontFamily: 'JuniorNunito1000', fontWeight: FontWeight.w900);
    if (st.u) s = s.copyWith(decoration: TextDecoration.underline, decorationThickness: 2, decorationColor: s.color);
    return s;
  }

  void addText(String t, _Style st) {
    if (t.isEmpty) return;
    t = t.replaceAll(' °', '\u00A0°').replaceAll(' %', '\u00A0%');
    final s = styleOf(st);
    if (st.kw || st.hx) {
      // mark.kw: lower-half butter highlight / mark.hx: heavy + 4px sage underline. Drawn as one unbreakable box per word so
      // the highlight follows the words like the web <mark>.
      final words = t.split(' ');
      for (var i = 0; i < words.length; i++) {
        final w = words[i];
        if (w.isNotEmpty) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: _Mark(text: w, style: s, kw: st.kw, hx: st.hx, colors: c, strike: strikeHx),
            ),
          );
        }
        if (i < words.length - 1) spans.add(TextSpan(text: ' ', style: s));
      }
      return;
    }
    spans.add(TextSpan(text: t, style: s));
  }

  void addSup(String t, _Style st) {
    final s = styleOf(st);
    final fs = (s.fontSize ?? 18) * .7;
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Transform.translate(
          offset: Offset(0, -(s.fontSize ?? 18) * .33),
          child: Text(t, style: s.copyWith(fontSize: fs, height: 1)),
        ),
      ),
    );
  }

  /// parse **kw**, *it*, [[hx]], <u>, ^sup
  void parse(String t, _Style st) {
    final buf = StringBuffer();
    void flush() {
      addText(buf.toString(), st);
      buf.clear();
    }

    var i = 0;
    while (i < t.length) {
      if (t.startsWith('**', i)) {
        final j = t.indexOf('**', i + 2);
        if (j > i + 2) {
          flush();
          parse(t.substring(i + 2, j), st.copy(kw: true));
          i = j + 2;
          continue;
        }
      }
      if (hxMarks && t.startsWith('[[', i)) {
        final j = t.indexOf(']]', i + 2);
        if (j > i + 2) {
          flush();
          parse(t.substring(i + 2, j), st.copy(hx: true));
          i = j + 2;
          continue;
        }
      }
      if (t.startsWith('<u>', i)) {
        final j = t.indexOf('</u>', i + 3);
        if (j > i) {
          flush();
          parse(t.substring(i + 3, j), st.copy(u: true));
          i = j + 4;
          continue;
        }
      }
      // *example words* -> italics (only at word edges, like the web regex)
      if (t[i] == '*' && (i == 0 || RegExp(r'[\s(“"\x27]').hasMatch(t[i - 1])) && i + 1 < t.length && !RegExp(r'[*\s]').hasMatch(t[i + 1])) {
        final j = t.indexOf('*', i + 1);
        if (j > i + 1 && (j + 1 >= t.length || RegExp(r'[\s.,;:!?)”"\x27]').hasMatch(t[j + 1]))) {
          flush();
          parse(t.substring(i + 1, j), st.copy(it: true));
          i = j + 1;
          continue;
        }
      }
      if (t[i] == '^' && i > 0 && _supPrev.hasMatch(t[i - 1])) {
        if (i + 1 < t.length && t[i + 1] == '(') {
          var dep = 0, j = i + 1;
          for (; j < t.length; j++) {
            if (t[j] == '(') {
              dep++;
            } else if (t[j] == ')' && --dep == 0) {
              break;
            }
          }
          if (j < t.length) {
            flush();
            addSup(t.substring(i + 2, j), st);
            i = j + 1;
            continue;
          }
        }
        final m = _supTok.firstMatch(t.substring(i + 1));
        if (m != null) {
          flush();
          addSup(m[0]!, st);
          i += 1 + m[0]!.length;
          continue;
        }
      }
      buf.write(t[i++]);
    }
    flush();
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.text, required this.style, required this.kw, required this.hx, required this.colors, this.strike = false});
  final String text;
  final TextStyle style;
  final bool kw, hx, strike;
  final RichColors colors;
  @override
  Widget build(BuildContext context) {
    Widget t = Text(text, style: style, strutStyle: strutOf(style));
    if (hx) {
      t = DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: strike ? colors.peach3 : colors.sage3, width: 4)),
          borderRadius: BorderRadius.circular(2),
        ),
        position: DecorationPosition.foreground,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: t),
      );
    }
    if (kw) {
      final hl = withA(colors.butter2, colors.butter2.a * .75);
      t = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [transparent, transparent, hl, hl], stops: const [0, .45, .45, 1]),
        ),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: t),
      );
    }
    return t;
  }
}

Widget _math(String src, bool display, TextStyle base) {
  final fs = (base.fontSize ?? 18) * 1.06 * (display ? .92 : 1);
  return Math.tex(
    src,
    mathStyle: display ? MathStyle.display : MathStyle.text,
    textStyle: TextStyle(fontSize: fs, color: base.color, fontWeight: FontWeight.normal),
    onErrorFallback: (e) => Text(src, style: base),
  );
}

/// Rich paragraph: inline markup + inline maths; display maths become their own centred block.
class RichPara extends StatelessWidget {
  const RichPara(this.text, {super.key, required this.style, this.colors, this.hx = false, this.notes = true, this.textAlign, this.strikeHx = false});
  final String text;
  final TextStyle style;
  final RichColors? colors;
  final bool hx, notes, strikeHx;
  final TextAlign? textAlign;

  static final _cache = <String, List<_Seg>>{};

  @override
  Widget build(BuildContext context) {
    final c = colors ?? const RichColors(Color(0xFFF7D46E), Color(0xFF2F6B3A), Color(0xFFA8412A));
    final segs = _cache.putIfAbsent('$notes|$text', () => _split(text, notes: notes));
    final blocks = <Widget>[];
    var ib = _InlineBuilder(style, c, hx, strikeHx);
    void flush() {
      if (ib.spans.isEmpty) return;
      blocks.add(Text.rich(TextSpan(children: ib.spans), style: style, strutStyle: strutOf(style), textAlign: textAlign));
      ib = _InlineBuilder(style, c, hx, strikeHx);
    }

    for (final s in segs) {
      if (s.math != null && s.display) {
        flush();
        blocks.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: _math(s.math!, true, style)),
          ),
        );
      } else if (s.math != null) {
        ib.spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: FittedBox(fit: BoxFit.scaleDown, child: _math(s.math!, false, style)),
          ),
        );
      } else {
        ib.parse(s.text!, const _Style());
      }
    }
    flush();
    if (blocks.length == 1) return blocks.first;
    return Column(crossAxisAlignment: textAlign == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: blocks);
  }
}

/// nparas(): paragraphs (margin 0 0 [gap]) and "- " bullet lists (padding-left 26, li gap 4)
class RichParas extends StatelessWidget {
  const RichParas(this.list, {super.key, required this.style, this.colors, this.gap = 10, this.hx = false});
  final List<String> list;
  final TextStyle style;
  final RichColors? colors;
  final double gap;
  final bool hx;
  @override
  Widget build(BuildContext context) {
    final lines = list.expand((x) => x.split('\n')).toList();
    final out = <Widget>[];
    var ul = <Widget>[];
    void flushUl() {
      if (ul.isEmpty) return;
      out.add(
        Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: ul),
        ),
      );
      ul = [];
    }

    for (final l in lines) {
      if (l.startsWith('- ')) {
        ul.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 26,
                child: Text('•', textAlign: TextAlign.center, style: style, strutStyle: strutOf(style)),
              ),
              Expanded(
                child: RichPara(l.substring(2), style: style, colors: colors, hx: hx),
              ),
            ],
          ),
        );
      } else {
        flushUl();
        out.add(
          Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: RichPara(l, style: style, colors: colors, hx: hx),
          ),
        );
      }
    }
    flushUl();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: out);
  }
}

/// inline spans only (for text around a widget, e.g. the fill-in blank); display maths are shown inline
class RichSpans {
  static List<InlineSpan> of(String text, TextStyle style, RichColors colors, {bool hx = false}) {
    final ib = _InlineBuilder(style, colors, hx, false);
    for (final s in _split(text)) {
      if (s.math != null) {
        ib.spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: FittedBox(fit: BoxFit.scaleDown, child: _math(s.math!, false, style)),
          ),
        );
      } else {
        ib.parse(s.text!, const _Style());
      }
    }
    return ib.spans;
  }
}
