// `.nfig` figure: a textbook SVG (prepared by svg_prep.dart) with numbered pins on top, positioned in viewBox units.
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/notes_models.dart';
import '../theme/clay.dart';
import '../theme/tokens.dart';
import '../widgets/clay_widgets.dart';
import 'graph_svg.dart';
import 'svg_prep.dart';

enum PinLook { normal, seen, on, onSeen, ask, hidden }

/// white rounded figure box (`.nfig`)
class FigBox extends StatelessWidget {
  const FigBox({super.key, required this.child, this.margin = const EdgeInsets.fromLTRB(0, 4, 0, 8)});
  final Widget child;
  final EdgeInsets margin;
  @override
  Widget build(BuildContext context) {
    final p = Kit.of(context).p;
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: ClayDecoration(
          radius: BorderRadius.circular(22),
          fills: [SolidFill(p.dark ? const Color(0xFFFFFBF4) : white)],
          shadows: [Shadow3.inset(2, 3, 8, 0, p.sh(.14))],
        ),
        child: Padding(padding: const EdgeInsets.all(8), child: child),
      ),
    );
  }
}

/// a unit diagram with optional pins. [look] gives each pin's state; [dim] pins drawn at opacity .45 (steps card).
class DiagramFig extends StatelessWidget {
  const DiagramFig({super.key, required this.path, required this.diagram, this.showKey, this.pins = true, this.look, this.dim, this.onPin, this.maxWidth});
  final String path;
  final Diagram diagram;
  final String? showKey;
  final bool pins;
  final PinLook Function(int i, Pin p)? look;
  final bool Function(int i, Pin p)? dim;
  final void Function(int i, Pin p)? onPin;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final vb = SvgStore.viewBox(path);
    final ar = vb[2] / vb[3];
    final svg = SvgStore.svg(path, showKey);
    return FigBox(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth ?? (430 * ar).roundToDouble()),
          child: AspectRatio(
            aspectRatio: ar,
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth, h = box.maxHeight;
                final kids = <Widget>[Positioned.fill(child: SvgPicture.string(svg, fit: BoxFit.fill))];
                if (pins) {
                  // the one "on" pin is drawn last (z-index 3)
                  final idx = List.generate(diagram.pins.length, (i) => i);
                  final looks = [for (final i in idx) look?.call(i, diagram.pins[i]) ?? PinLook.normal];
                  idx.sort((a, b) => (looks[a] == PinLook.on || looks[a] == PinLook.onSeen ? 1 : 0).compareTo(looks[b] == PinLook.on || looks[b] == PinLook.onSeen ? 1 : 0));
                  for (final i in idx) {
                    final pn = diagram.pins[i];
                    if (looks[i] == PinLook.hidden) continue;
                    kids.add(
                      Positioned(
                        left: (pn.x - vb[0]) / vb[2] * w - 24,
                        top: (pn.y - vb[1]) / vb[3] * h - 24,
                        width: 48,
                        height: 48,
                        child: Opacity(
                          opacity: dim?.call(i, pn) == true ? .45 : 1,
                          child: PinDot(n: i + 1, look: looks[i], onTap: onPin == null ? null : () => onPin!(i, pn)),
                        ),
                      ),
                    );
                  }
                }
                return Stack(clipBehavior: Clip.none, children: kids);
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// `.pin`: 48px hit area, 30px disc (primary / seen sage / on = ring + scale 1.25 / ask = gold, pulsing)
class PinDot extends StatefulWidget {
  const PinDot({super.key, required this.n, required this.look, this.onTap});
  final int n;
  final PinLook look;
  final VoidCallback? onTap;
  @override
  State<PinDot> createState() => _PinDotState();
}

class _PinDotState extends State<PinDot> with TickerProviderStateMixin {
  AnimationController? _pulse;

  void _sync() {
    if (widget.look == PinLook.ask) {
      _pulse ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
    } else {
      _pulse?.dispose();
      _pulse = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PinDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Kit.of(context).p;
    final l = widget.look;
    final seen = l == PinLook.seen || l == PinLook.onSeen;
    final on = l == PinLook.on || l == PinLook.onSeen;
    final List<Fill> fill;
    final List<Shadow3> sh;
    if (l == PinLook.ask) {
      fill = [const RadialFill.circle(.35, .28, [Color(0xFFFFF2B8), Color(0xFFE9A21A)], [0, .7])];
      sh = [const Shadow3(0, 3, 0, 0, Color(0xFF8A6410)), const Shadow3(0, 0, 0, 6, Color.fromRGBO(247, 212, 110, .6))];
    } else if (seen) {
      fill = [RadialFill.circle(.35, .28, [const Color(0xFFCFEFCB), p.sage.deep], const [0, .75])];
      sh = on
          ? [const Shadow3(0, 0, 0, 5, Color.fromRGBO(247, 212, 110, .9)), Shadow3(0, 3, 0, 0, p.primaryEdge)]
          : [const Shadow3(0, 3, 0, 0, Color(0xFF1E4A27)), const Shadow3(0, 5, 8, -3, Color.fromRGBO(0, 0, 0, .4))];
    } else {
      fill = [RadialFill.circle(.35, .28, [const Color(0xFFF4AE97), p.primary], const [0, .7])];
      sh = on
          ? [const Shadow3(0, 0, 0, 5, Color.fromRGBO(247, 212, 110, .9)), Shadow3(0, 3, 0, 0, p.primaryEdge)]
          : [Shadow3(0, 3, 0, 0, p.primaryEdge), const Shadow3(0, 5, 8, -3, Color.fromRGBO(0, 0, 0, .45)), const Shadow3.inset(0, 1, 1, 0, Color.fromRGBO(255, 255, 255, .5))];
    }
    Widget disc = DecoratedBox(
      decoration: ClayDecoration(radius: BorderRadius.circular(99), fills: fill, shadows: sh),
      child: SizedBox(
        width: 30,
        height: 30,
        child: Center(child: Text('${widget.n}', style: ts1000(15, white, height: 1))),
      ),
    );
    if (_pulse != null) {
      disc = AnimatedBuilder(
        animation: _pulse!,
        child: disc,
        builder: (_, ch) {
          final t = _pulse!.value, s = 1 + .2 * (t < .5 ? Curves.easeInOut.transform(t * 2) : Curves.easeInOut.transform((1 - t) * 2));
          return Transform.scale(scale: s, child: ch);
        },
      );
    } else if (on) {
      disc = Transform.scale(scale: 1.25, child: disc);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Center(child: disc),
    );
  }
}

/// number line / coordinate plane from JSON (`graphHTML`), full card width
class GraphFig extends StatelessWidget {
  const GraphFig({super.key, required this.spec, this.showKey});
  final GraphSpec spec;
  final String? showKey;
  static final _cache = Expando<String>();
  static final _vb = Expando<List<double>>();
  @override
  Widget build(BuildContext context) {
    final raw = _cache[spec] ??= prepSvg(graphSvg(spec));
    final vb = _vb[spec] ??= () {
      final m = RegExp(r'viewBox="([^"]+)"').firstMatch(raw);
      return (m?[1] ?? '0 0 320 140').trim().split(RegExp(r'[\s,]+')).map(double.parse).toList();
    }();
    final svg = SvgStore.showString(raw, showKey);
    return FigBox(
      child: AspectRatio(
        aspectRatio: vb[2] / vb[3],
        child: SvgPicture.string(svg, fit: BoxFit.fill),
      ),
    );
  }
}
