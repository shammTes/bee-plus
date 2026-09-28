// SVG icons and illustrations from the web template, themed like the CSS (currentColor, var(--…), dark .hl opacity).
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens.dart';
import 'art_data.dart';

String hex(Color c) {
  int ch(double v) => (v * 255).round().clamp(0, 255);
  final rgb = '#${[ch(c.r), ch(c.g), ch(c.b)].map((x) => x.toRadixString(16).padLeft(2, '0')).join()}';
  return rgb;
}

String _theme(String svg, Palette p, Color current) {
  var s = svg.replaceAllMapped(RegExp(r'var\(--([\w-]+)\)'), (m) => hex(p.cssVar(m[1]!) ?? current));
  s = s.replaceAll('currentColor', hex(current));
  // translucent colours: rgba() -> hex + opacity attribute is not needed for the few uses (star outline); flutter_svg reads rgba
  if (current.a < 1) s = s.replaceAll('<path ', '<path opacity="${current.a.toStringAsFixed(3)}" ');
  return s;
}

final Map<String, String> _cache = {};

/// A 24×24 line icon (`ic(name)` in the web app).
class SvgIcon extends StatelessWidget {
  const SvgIcon(this.name, {super.key, this.size = 26, required this.color, required this.palette});
  final String name;
  final double size;
  final Color color;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    final k = 'i|$name|${color.toARGB32()}|${palette.dark}';
    final svg = _cache[k] ??= '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">${_theme(kIcons[name] ?? '', palette, color)}</svg>';
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.string(svg, width: size, height: size),
    );
  }
}

/// A 64×64 clay illustration (subject art, sun, logo …) with the CSS drop-shadow filter.
class ArtIcon extends StatelessWidget {
  const ArtIcon(this.name, {super.key, required this.size, required this.palette, this.shadow, this.shadowDy = 5, this.shadowBlur = 4});
  final String name;
  final double size;
  final Palette palette;

  /// drop-shadow(0 5px 4px color); null = none
  final Color? shadow;
  final double shadowDy, shadowBlur;

  String get _svg {
    final k = 'a|$name|${palette.dark}';
    return _cache[k] ??= () {
      var inner = (kArt[name] ?? kArt['logo']!).replaceFirst(RegExp(r'^<svg[^>]*>'), '').replaceFirst(RegExp(r'</svg>$'), '');
      inner = inner
          .replaceAll('font-family="Nunito,sans-serif"', 'font-family="JuniorNunito"')
          .replaceAll('font-family="\'Junior Ethiopic\',\'Noto Sans Ethiopic\',sans-serif"', 'font-family="JuniorEthiopic"');
      if (palette.dark) inner = inner.replaceAllMapped(RegExp(r'class="hl"( opacity="[.\d]+")?'), (m) => 'opacity=".35"');
      return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><defs>$kSvgDefs</defs>${_theme(inner, palette, palette.ink)}</svg>';
    }();
  }

  @override
  Widget build(BuildContext context) {
    final pic = SvgPicture.string(_svg, width: size, height: size);
    if (shadow == null) return SizedBox(width: size, height: size, child: pic);
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, shadowDy),
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: shadowBlur / 2, sigmaY: shadowBlur / 2, tileMode: TileMode.decal),
                  child: ColorFiltered(colorFilter: ColorFilter.mode(shadow!, BlendMode.srcIn), child: pic),
                ),
              ),
            ),
            pic,
          ],
        ),
      ),
    );
  }
}

/// three stars (filled with the gold gradient) – `starsHTML`
class Stars extends StatelessWidget {
  const Stars(this.n, {super.key, this.size = 22, required this.palette, this.gap = 2, this.only = 3});
  final int n, only;
  final double size, gap;
  final Palette palette;
  @override
  Widget build(BuildContext context) {
    final on = _cache['star-on'] ??=
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><defs><linearGradient id="gStar" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFE68F"/><stop offset=".55" stop-color="#F5B72E"/><stop offset="1" stop-color="#D98E12"/></linearGradient></defs>${kIcons['star']!.replaceFirst('fill="currentColor"', 'fill="url(#gStar)"')}</svg>';
    final offC = mix(palette.ink, .14, transparent);
    final off = _cache['star-off|${palette.dark}'] ??=
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">${kIcons['star']!.replaceFirst('fill="currentColor"', 'fill="${hex(offC)}" fill-opacity="${offC.a.toStringAsFixed(3)}"')}</svg>';
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: gap,
      children: [for (var i = 0; i < only; i++) SvgPicture.string(i < n ? on : off, width: size, height: size)],
    );
  }
}
