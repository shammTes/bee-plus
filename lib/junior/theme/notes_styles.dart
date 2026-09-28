// Clay recipes for the unit page, games, questions and the exam player (CSS rules quoted per method).
import 'package:flutter/widgets.dart';

import 'clay.dart';
import 'styles.dart';
import 'tokens.dart';

const _darkEdge = Color(0xFF15110E);

enum OptState { normal, sel, correct, correctChosen, wrongChosen, dim }

extension NotesClay on Clay {
  List<Fill> _raised(Color b, {double lift = .5, double stop = .6}) => [
    LinearFill.vertical([mix(b, lift, p.lift), b], [0, stop]),
  ];

  // ---------------------------------------------------------------- .opt answer options (radius 24)
  (Color b, Color e) optColors(OptState s) {
    Color e(Tone t, double k) => p.dark ? mix(t.tile, .55, black) : mix(t.mid, k, t.deep);
    return switch (s) {
      OptState.sel => (p.blue.tile, e(p.blue, .6)),
      OptState.correct || OptState.correctChosen => (p.sage.tile, e(p.sage, .55)),
      OptState.wrongChosen => (p.peach.tile, e(p.peach, .55)),
      _ => (p.surface, p.edgeN),
    };
  }

  ClayDecoration opt(OptState s, {double radius = 24}) {
    final (b, e) = optColors(s);
    final r = BorderRadius.circular(radius);
    final fills = _raised(b);
    return switch (s) {
      OptState.normal => ClayDecoration(
        radius: r,
        fills: fills,
        shadows: [Shadow3(0, 6, 0, 0, e), Shadow3(0, 14, 18, -10, p.sh(.4)), Shadow3.inset(4, 5, 8, -3, p.hi), Shadow3.inset(-4, -5, 8, -4, p.sh(.10))],
      ),
      OptState.sel => ClayDecoration(
        radius: r,
        fills: fills,
        shadows: [Shadow3(0, 1, 0, 0, e), Shadow3.inset(0, 0, 0, 3, p.blue.mid), Shadow3.inset(4, 6, 10, 0, withA(p.blue.deep, .3))],
      ),
      OptState.correct => ClayDecoration(
        radius: r,
        fills: fills,
        shadows: p.dark
            ? [Shadow3(0, 6, 0, 0, e), const Shadow3(0, 14, 18, -10, Color.fromRGBO(0, 0, 0, .6)), Shadow3.inset(0, 0, 0, 3, p.sage.mid)]
            : [Shadow3(0, 6, 0, 0, e), Shadow3(0, 14, 18, -10, withA(p.sage.deep, .55)), Shadow3.inset(0, 0, 0, 3, p.sage.mid), Shadow3.inset(4, 5, 8, -3, p.hi)],
      ),
      OptState.correctChosen || OptState.wrongChosen => ClayDecoration(
        radius: r,
        fills: fills,
        shadows: [Shadow3(0, 1, 0, 0, e), Shadow3.inset(0, 0, 0, 3, withA(e, .6)), Shadow3.inset(4, 6, 10, 0, withA(e, .45))],
      ),
      OptState.dim => ClayDecoration(radius: r, fills: fills, shadows: [Shadow3(0, 3, 0, 0, p.edgeN), Shadow3.inset(0, 1, 1, 0, p.hi)]),
    };
  }

  /// .opt:active
  ClayDecoration optPressed(OptState s, {double radius = 24}) {
    final (b, e) = optColors(s);
    return ClayDecoration(radius: BorderRadius.circular(radius), fills: _raised(b), shadows: [Shadow3(0, 1, 0, 0, e), Shadow3.inset(3, 4, 8, 0, p.sh(.22))]);
  }

  /// .opt .l letter disc (46)
  ClayDecoration optLetter(OptState s) {
    final Color? tone = switch (s) {
      OptState.sel => p.blue.deep,
      OptState.correct || OptState.correctChosen => p.sage.deep,
      OptState.wrongChosen => p.peach.deep,
      _ => null,
    };
    if (tone == null) {
      return ClayDecoration(
        radius: BorderRadius.circular(R.pill),
        fills: [
          RadialFill.circle(.35, .28, [p.lift, p.surface2], const [0, .7]),
        ],
        shadows: [Shadow3(0, 3, 0, 0, p.edgeN), Shadow3(0, 6, 8, -4, p.sh(.4)), Shadow3.inset(0, 2, 2, 0, p.hi), Shadow3.inset(0, -2, 3, 0, p.sh(.14))],
      );
    }
    return ClayDecoration(
      radius: BorderRadius.circular(R.pill),
      fills: [
        RadialFill.circle(.35, .28, [mix(tone, p.dark ? .8 : .55, white), tone], [0, p.dark ? .7 : .68]),
      ],
      shadows: p.dark
          ? [Shadow3(0, 3, 0, 0, mix(tone, .45, black)), const Shadow3.inset(0, 2, 2, 0, Color.fromRGBO(255, 255, 255, .3))]
          : [Shadow3(0, 3, 0, 0, mix(tone, .7, black)), Shadow3(0, 6, 8, -4, tone), const Shadow3.inset(0, 2, 2, 0, Color.fromRGBO(255, 255, 255, .35))],
    );
  }

  // ---------------------------------------------------------------- disabled / ghost buttons
  ClayDecoration btnDisabled() => ClayDecoration(
    radius: BorderRadius.circular(R.pill),
    fills: [SolidFill(p.surface2)],
    shadows: [Shadow3(0, 1, 0, 0, p.edgeN), Shadow3.inset(0, 3, 8, 0, p.sh(.18))],
  );

  /// .btn.yes / .btn.nope (true / false)
  ClayDecoration btnTone(Tone t) => ClayDecoration(
    radius: BorderRadius.circular(R.pill),
    fills: [
      LinearFill.vertical([mix(t.tile, .5, white), t.tile], const [0, 1]),
    ],
    shadows: [Shadow3(0, 6, 0, 0, t.mid), Shadow3(0, 14, 18, -10, p.sh(.4)), Shadow3.inset(0, 2, 1, 0, p.hi)],
  );
  ClayDecoration btnTonePressed(Tone t) => btnTone(t).copyWith(shadows: [Shadow3(0, 1, 0, 0, t.mid), Shadow3.inset(0, 3, 8, 0, p.sh(.25))]);

  // ---------------------------------------------------------------- chips
  ClayDecoration chip({bool blue = false}) {
    final t = blue ? p.blue : p.butter;
    return ClayDecoration(
      radius: BorderRadius.circular(R.pill),
      fills: [
        LinearFill.vertical([mix(t.tile, .5, white), t.tile], const [0, 1]),
      ],
      shadows: [Shadow3(0, 4, 0, 0, t.mid), Shadow3(0, 8, 10, -6, p.sh(.35)), Shadow3.inset(0, 2, 1, 0, p.hi)],
    );
  }

  ClayDecoration chipOn({bool blue = false}) => blue
      ? ClayDecoration(radius: BorderRadius.circular(R.pill), fills: [SolidFill(p.blue.mid)], shadows: [Shadow3.inset(2, 3, 6, 0, p.sh(.3))])
      : chip().copyWith(shadows: [Shadow3(0, 0, 0, 0, withA(p.butter.mid, 0)), Shadow3.inset(2, 3, 6, 0, p.sh(.25))]);

  // ---------------------------------------------------------------- unit page
  ClayDecoration secPill(Tone t) => p.dark
      ? ClayDecoration(
          radius: BorderRadius.circular(R.pill),
          fills: [SolidFill(p.surface2)],
          shadows: const [Shadow3(0, 5, 0, 0, _darkEdge), Shadow3(0, 12, 16, -10, Color.fromRGBO(0, 0, 0, .6))],
        )
      : ClayDecoration(
          radius: BorderRadius.circular(R.pill),
          fills: [
            LinearFill.vertical([mix(t.tile, .5, p.lift), t.tile], const [0, 1]),
          ],
          shadows: [Shadow3(0, 5, 0, 0, t.mid), Shadow3(0, 12, 16, -10, p.sh(.45)), Shadow3.inset(0, 2, 1, 0, p.hi)],
        );

  /// .pbar (22 tall, padding 4) track and puffy fill
  ClayDecoration pbar() => ClayDecoration(
    radius: BorderRadius.circular(99),
    fills: [SolidFill(p.surface2)],
    shadows: [Shadow3.inset(2, 4, 7, 0, p.sh(.28)), Shadow3.inset(-1, -2, 3, 0, p.hi2)],
  );
  ClayDecoration pbarFill() => p.dark
      ? ClayDecoration(
          radius: BorderRadius.circular(99),
          fills: [
            LinearFill.vertical([const Color(0xFF9BCB9E), p.sage.mid, const Color(0xFF5E9463)], const [0, .6, 1]),
          ],
          shadows: const [Shadow3.inset(0, 1, 1, 0, Color.fromRGBO(255, 255, 255, .25))],
        )
      : ClayDecoration(
          radius: BorderRadius.circular(99),
          fills: [
            LinearFill.vertical([mix(p.sage.mid, .55, white), p.sage.mid, mix(p.sage.mid, .7, p.sage.deep)], const [0, .55, 1]),
          ],
          shadows: [
            Shadow3(0, 2, 3, 0, withA(p.sage.deep, .4)),
            const Shadow3.inset(0, 2, 1, 0, Color.fromRGBO(255, 255, 255, .6)),
            Shadow3.inset(0, -2, 3, 0, withA(p.sage.deep, .3)),
          ],
        );

  /// sunk panels: .steptext, .pg, .nfig, .rpass …
  ClayDecoration sunk(Color c, {double radius = 18, double dx = 1, double dy = 2, double blur = 5, double a = .14}) =>
      ClayDecoration(radius: BorderRadius.circular(radius), fills: [SolidFill(c)], shadows: [Shadow3.inset(dx, dy, blur, 0, p.sh(a))]);

  ClayDecoration flat(Color c, {double radius = 18}) => ClayDecoration(radius: BorderRadius.circular(radius), fills: [SolidFill(c)]);

  /// .letter (mnemonic letter tiles)
  ClayDecoration letter() => ClayDecoration(
    radius: BorderRadius.circular(20),
    fills: [
      LinearFill.vertical([mix(p.surface, .5, p.lift), p.surface], const [0, 1]),
    ],
    shadows: [Shadow3(0, 5, 0, 0, mix(p.lilac.mid, .6, p.lilac.deep)), Shadow3(0, 10, 14, -8, p.sh(.4)), Shadow3.inset(0, 2, 1, 0, p.hi)],
  );

  /// .verdict .ico (56) / .ghead .num etc.
  ClayDecoration icoDisc(Color d) => ClayDecoration(
    radius: BorderRadius.circular(R.pill),
    fills: [
      RadialFill.circle(.35, .28, [p.lift, p.surface], const [0, .65]),
    ],
    shadows: p.dark
        ? [const Shadow3(0, 5, 0, 0, _darkEdge), const Shadow3(0, 10, 14, -8, Color.fromRGBO(0, 0, 0, .6)), Shadow3.inset(0, 2, 2, 0, p.hi)]
        : [Shadow3(0, 4, 0, 0, mix(d, .35, p.edgeN)), Shadow3(0, 8, 12, -6, withA(d, .5)), Shadow3.inset(0, 2, 2, 0, p.hi)],
  );

  /// .row .num with a custom edge (lilac for games)
  ClayDecoration numEdge(Color edge) => ClayDecoration(
    radius: BorderRadius.circular(18),
    fills: [
      RadialFill.circle(.35, .28, [p.lift, p.surface], const [0, .65]),
    ],
    shadows: [Shadow3(0, 4, 0, 0, edge), Shadow3.inset(0, 2, 2, 0, p.hi)],
  );

  // ---------------------------------------------------------------- games
  ClayDecoration tile(Color b, Color e, {double radius = 22, bool down = false, bool ring = false, Color? ringC}) => ClayDecoration(
    radius: BorderRadius.circular(radius),
    fills: _raised(b),
    shadows: down
        ? [Shadow3(0, 1, 0, 0, e), if (ring) Shadow3.inset(0, 0, 0, 3, ringC ?? e)]
        : [Shadow3(0, 6, 0, 0, e), Shadow3(0, 12, 16, -10, p.sh(.4)), Shadow3.inset(3, 4, 7, -3, p.hi)],
  );

  ClayDecoration wtile(Color b, Color e, {bool down = false}) => ClayDecoration(
    radius: BorderRadius.circular(18),
    fills: _raised(b),
    shadows: down ? [Shadow3(0, 1, 0, 0, e)] : [Shadow3(0, 5, 0, 0, e), Shadow3(0, 10, 14, -8, p.sh(.4)), Shadow3.inset(2, 3, 6, -3, p.hi)],
  );

  ClayDecoration bin(Tone t, {bool down = false}) => ClayDecoration(
    radius: BorderRadius.circular(24),
    fills: [SolidFill(t.tile)],
    shadows: down
        ? [Shadow3(0, 1, 0, 0, t.edge(p.dark)), Shadow3.inset(3, 4, 8, 0, p.sh(.2))]
        : [Shadow3(0, 6, 0, 0, t.edge(p.dark)), Shadow3(0, 14, 18, -10, p.sh(.4)), Shadow3.inset(4, 5, 8, -3, p.hi)],
  );

  ClayDecoration item() => ClayDecoration(
    radius: BorderRadius.circular(26),
    fills: [
      LinearFill.vertical([white, p.surface], const [0, 1]),
    ],
    shadows: [Shadow3(0, 7, 0, 0, p.edgeN), Shadow3(0, 16, 22, -10, p.sh(.45)), Shadow3.inset(0, 2, 1, 0, p.hi)],
  );

  ClayDecoration face(Tone t) => ClayDecoration(
    radius: BorderRadius.circular(30),
    fills: [
      LinearFill.vertical([mix(t.tile, .5, white), t.tile], const [0, 1]),
    ],
    shadows: [Shadow3(0, 8, 0, 0, t.mid), Shadow3(0, 18, 24, -12, p.sh(.45)), Shadow3.inset(0, 3, 2, 0, p.hi)],
  );

  ClayDecoration timerTrack() => sunk(p.surface2, radius: 12, dx: 2, dy: 3, blur: 6, a: .28);
  ClayDecoration timerFill() => ClayDecoration(
    radius: BorderRadius.circular(12),
    fills: [
      LinearFill.horizontal([p.butter.mid, p.peach.mid], const [0, 1]),
    ],
  );

  /// slider thumb (44) and pins
  ClayDecoration primaryDisc({Color? edge}) => ClayDecoration(
    radius: BorderRadius.circular(R.pill),
    fills: [
      RadialFill.circle(.35, .28, [const Color(0xFFF4AE97), p.primary], const [0, .7]),
    ],
    shadows: [Shadow3(0, 4, 0, 0, edge ?? p.primaryEdge), const Shadow3(0, 8, 10, -4, Color.fromRGBO(0, 0, 0, .4))],
  );
}
