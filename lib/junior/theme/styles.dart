// The CSS "3D embossed clay layer" as reusable decorations (one function per CSS rule set).
import 'package:flutter/widgets.dart';

import 'clay.dart';
import 'tokens.dart';

const _defD = Color(0xFF9C7A5B); // --deep fallback (#9C7A5B)
const _darkEdge = Color(0xFF15110E);

class Clay {
  Clay(this.p);
  final Palette p;

  // ---------------------------------------------------------------- puffy raised panels (.gradecard .shead .row .card .nav .sheet …)
  List<Fill> puffyFill(Color c, Color d) => [
    LinearFill.vertical([mix(c, .58, p.lift), c, mix(c, .9, d)], const [0, .52, 1]),
  ];

  ClayDecoration puffy({Color? c, Color? d, double radius = 28}) {
    final cc = c ?? p.surface, dd = d ?? _defD;
    return ClayDecoration(
      radius: BorderRadius.circular(radius),
      fills: puffyFill(cc, dd),
      shadows: p.dark
          ? [
              const Shadow3(0, 22, 30, -16, Color.fromRGBO(0, 0, 0, .75)),
              const Shadow3(0, 8, 14, -8, Color.fromRGBO(0, 0, 0, .5)),
              Shadow3.inset(5, 7, 12, -4, p.hi),
              const Shadow3.inset(-7, -10, 16, -6, Color.fromRGBO(0, 0, 0, .38)),
            ]
          : [
              Shadow3(0, 22, 30, -18, withA(dd, .6)),
              Shadow3(0, 8, 14, -8, withA(dd, .38)),
              Shadow3.inset(6, 8, 12, -4, p.hi),
              Shadow3.inset(-7, -10, 16, -6, withA(dd, .3)),
            ],
    );
  }

  /// :active state of puffy tappables (translateY(3px) scale(.985) is applied by the press widget)
  ClayDecoration puffyPressed({Color? c, Color? d, double radius = 28}) {
    final cc = c ?? p.surface, dd = d ?? _defD;
    return ClayDecoration(
      radius: BorderRadius.circular(radius),
      fills: puffyFill(cc, dd),
      shadows: p.dark
          ? [
              const Shadow3(0, 8, 14, -10, Color.fromRGBO(0, 0, 0, .7)),
              Shadow3.inset(5, 7, 12, -4, p.hi),
              const Shadow3.inset(-5, -7, 14, -4, Color.fromRGBO(0, 0, 0, .45)),
            ]
          : [Shadow3(0, 10, 16, -12, withA(dd, .6)), Shadow3.inset(6, 8, 12, -4, p.hi), Shadow3.inset(-5, -7, 14, -4, withA(dd, .38))],
    );
  }

  ClayDecoration puffyTone(Tone t, {double radius = 28}) => puffy(c: t.tile, d: t.deep, radius: radius);
  ClayDecoration puffyTonePressed(Tone t, {double radius = 28}) => puffyPressed(c: t.tile, d: t.deep, radius: radius);

  /// .row[disabled] / .paperbtn[disabled]
  ClayDecoration sunkenRow({double radius = 28}) =>
      ClayDecoration(radius: BorderRadius.circular(radius), fills: [SolidFill(p.surface2)], shadows: [Shadow3.inset(3, 4, 8, 0, p.sh(.16))]);

  // ---------------------------------------------------------------- raised keys (.lang button, .seg button, .nav button, .jump button)
  ClayDecoration key({double radius = R.pill, double lift = .5, double shadowSpread = -6}) => ClayDecoration(
    radius: BorderRadius.circular(radius),
    fills: [
      LinearFill.vertical([mix(p.surface, lift, p.lift), p.surface], const [0, 1]),
    ],
    shadows: [Shadow3(0, 4, 0, 0, p.edgeN), Shadow3(0, 8, 10, shadowSpread, p.sh(.35)), Shadow3.inset(0, 2, 1, 0, p.hi)],
  );

  /// the chosen key, pressed in (sage)
  ClayDecoration keyOn({double radius = R.pill, double blur = 6, double dx = 2, double dy = 3, double a = .35, bool zeroEdge = true}) => ClayDecoration(
    radius: BorderRadius.circular(radius),
    fills: [SolidFill(p.sage.tile)],
    shadows: [
      if (zeroEdge) Shadow3(0, 0, 0, 0, withA(p.edgeN, 0)),
      Shadow3.inset(0, 0, 0, 2, p.sage.mid),
      Shadow3.inset(dx, dy, blur, 0, withA(p.sage.deep, a)),
    ],
  );

  ClayDecoration navKey() => key(radius: 22, lift: .45, shadowSpread: -8);
  ClayDecoration navKeyOn() => keyOn(radius: 22, dx: 3, dy: 4, blur: 8, a: .32, zeroEdge: false);

  /// debossed track (.lang, .jump)
  ClayDecoration track({double radius = 30}) => ClayDecoration(
    radius: BorderRadius.circular(radius),
    fills: [SolidFill(p.surface2)],
    shadows: [Shadow3.inset(3, 4, 8, 0, p.sh(.2)), Shadow3.inset(-2, -2, 5, 0, p.hi2)],
  );

  // ---------------------------------------------------------------- buttons (.btn.primary / .soft / .danger)
  ClayDecoration btnPrimary() => ClayDecoration(
    radius: BorderRadius.circular(R.pill),
    fills: [
      const RadialFill.ellipse(1.2, .7, .5, -.1, [Color.fromRGBO(255, 255, 255, .32), transparent], [0, .55]),
      LinearFill.vertical([p.primary2, p.primary], const [0, 1]),
    ],
    shadows: [
      Shadow3(0, 6, 0, 0, p.primaryEdge),
      Shadow3(0, 16, 20, -10, withA(p.primary, .7)),
      const Shadow3.inset(0, 2, 1, 0, Color.fromRGBO(255, 255, 255, .45)),
      const Shadow3.inset(0, -3, 5, 0, Color.fromRGBO(0, 0, 0, .12)),
    ],
  );
  ClayDecoration btnPrimaryPressed() => btnPrimary().copyWith(
    shadows: [Shadow3(0, 1, 0, 0, p.primaryEdge), Shadow3(0, 4, 8, -4, p.primary), const Shadow3.inset(0, 3, 8, 0, Color.fromRGBO(0, 0, 0, .28))],
  );

  ClayDecoration _btnB(Color b, Color e) => ClayDecoration(
    radius: BorderRadius.circular(R.pill),
    fills: [
      LinearFill.vertical([mix(b, .55, p.lift), b], const [0, 1]),
    ],
    shadows: [Shadow3(0, 6, 0, 0, e), Shadow3(0, 14, 18, -10, p.sh(.4)), Shadow3.inset(0, 2, 1, 0, p.hi), Shadow3.inset(0, -3, 5, 0, p.sh(.08))],
  );
  ClayDecoration btnSoft() => _btnB(p.surface, p.edgeN);
  ClayDecoration btnSoftPressed() => btnSoft().copyWith(shadows: [Shadow3(0, 1, 0, 0, p.edgeN), Shadow3.inset(0, 3, 8, 0, p.sh(.25))]);
  Color get dangerEdge => mix(p.peach.mid, .6, p.peach.deep);
  ClayDecoration btnDanger() => _btnB(p.peach.tile, dangerEdge);
  ClayDecoration btnDangerPressed() => btnDanger().copyWith(shadows: [Shadow3(0, 1, 0, 0, dangerEdge), Shadow3.inset(0, 3, 8, 0, p.sh(.25))]);

  // ---------------------------------------------------------------- round buttons
  ClayDecoration cbtn() => ClayDecoration(
    radius: BorderRadius.circular(R.pill),
    fills: [
      RadialFill.circle(.35, .28, [p.lift, p.surface], const [0, .62]),
    ],
    shadows: [Shadow3(0, 5, 0, 0, p.edgeN), Shadow3(0, 12, 16, -8, p.sh(.45)), Shadow3.inset(0, -3, 5, 0, p.sh(.12)), Shadow3.inset(0, 2, 2, 0, p.hi)],
  );
  ClayDecoration cbtnPressed() => cbtn().copyWith(shadows: [Shadow3(0, 1, 0, 0, p.edgeN), Shadow3.inset(0, 3, 6, 0, p.sh(.3))]);

  ClayDecoration play() => ClayDecoration(
    radius: BorderRadius.circular(R.pill),
    fills: [
      const RadialFill.circle(.35, .28, [Color.fromRGBO(255, 255, 255, .4), transparent], [0, .45]),
      LinearFill.vertical([p.primary2, p.primary], const [0, 1]),
    ],
    shadows: [Shadow3(0, 5, 0, 0, p.primaryEdge), Shadow3(0, 12, 16, -8, p.primary), const Shadow3.inset(0, 2, 1, 0, Color.fromRGBO(255, 255, 255, .4))],
  );

  /// .gradecard .gnum (82px, radius 28)
  ClayDecoration gnum(Tone t) => ClayDecoration(
    radius: BorderRadius.circular(28),
    fills: [
      RadialFill.circle(.35, .28, [p.lift, p.surface], const [0, .65]),
    ],
    shadows: p.dark
        ? [const Shadow3(0, 5, 0, 0, _darkEdge), const Shadow3(0, 10, 14, -8, Color.fromRGBO(0, 0, 0, .6)), Shadow3.inset(0, 2, 2, 0, p.hi)]
        : [
            Shadow3(0, 6, 0, 0, t.edge(false)),
            Shadow3(0, 12, 16, -8, withA(t.deep, .5)),
            Shadow3.inset(0, 2, 2, 0, p.hi),
            Shadow3.inset(0, -3, 5, 0, p.sh(.1)),
          ],
  );

  /// .row .num (52px, radius 18)
  ClayDecoration num(Tone? t) => ClayDecoration(
    radius: BorderRadius.circular(18),
    fills: [
      RadialFill.circle(.35, .28, [p.lift, p.surface], const [0, .65]),
    ],
    shadows: [Shadow3(0, 4, 0, 0, t == null ? p.edgeN : t.edge(p.dark)), Shadow3.inset(0, 2, 2, 0, p.hi)],
  );

  ClayDecoration minibar() => ClayDecoration(radius: BorderRadius.circular(9), fills: [SolidFill(p.surface2)], shadows: [Shadow3.inset(1, 2, 4, 0, p.sh(.25))]);
  ClayDecoration minibarFill() => ClayDecoration(
    radius: BorderRadius.circular(9),
    fills: [
      LinearFill.vertical([mix(p.sage.mid, .5, white), p.sage.mid], const [0, 1]),
    ],
  );

  ClayDecoration tag() => ClayDecoration(
    radius: BorderRadius.circular(R.pill),
    fills: [
      p.dark ? SolidFill(p.butter.tile) : LinearFill.vertical([mix(p.butter.tile, .5, white), p.butter.tile], const [0, 1]),
    ],
    shadows: [Shadow3(0, 2, 0, 0, p.butter.mid), Shadow3.inset(0, 1, 1, 0, p.hi)],
  );

  /// .sw switch track (64×36) and knob
  ClayDecoration swTrack(bool on) => ClayDecoration(
    radius: BorderRadius.circular(18),
    fills: [SolidFill(on ? p.sage.mid : p.surface2)],
    shadows: [Shadow3.inset(2, 3, 6, 0, p.sh(.3)), Shadow3.inset(-1, -1, 2, 0, p.hi2)],
  );
  ClayDecoration swKnob() => ClayDecoration(
    radius: BorderRadius.circular(14),
    fills: const [
      RadialFill.circle(.35, .30, [white, Color(0xFFEDE3D6)], [0, .7]),
    ],
    shadows: [Shadow3(0, 3, 0, 0, p.sh(.25)), const Shadow3(0, 4, 6, 0, Color.fromRGBO(0, 0, 0, .25))],
  );

  /// badge dot on the nav
  ClayDecoration dot() => ClayDecoration(
    radius: BorderRadius.circular(11),
    fills: [SolidFill(p.primary)],
    shadows: [Shadow3(0, 2, 0, 0, p.primaryEdge), const Shadow3.inset(0, 1, 1, 0, Color.fromRGBO(255, 255, 255, .4))],
  );

  /// settings sheet
  ClayDecoration sheet() => ClayDecoration(
    radius: const BorderRadius.vertical(top: Radius.circular(36)),
    fills: puffyFill(p.surface, _defD),
    shadows: [Shadow3(0, -14, 30, -10, p.sh(.35)), Shadow3.inset(0, 8, 12, -6, p.hi)],
  );
}
