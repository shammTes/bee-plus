// Per-session widget state of the unit page (web: CW / GS / EXS): lives while the app runs, so a card scrolled away and back
// (or a unit left and re-opened) keeps its step, chosen answer or running game. Cleared by "Start over".
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/notes_models.dart';

int starsFor(int r, int n) {
  if (n == 0) return 0;
  final p = r / n;
  return p >= 0.8 ? 3 : p >= 0.5 ? 2 : p > 0 ? 1 : 0;
}

final _rnd = math.Random();

/// random source of [shuffled] in [0, 1) (web `Math.random`); tests and screenshots replace it with a seeded one
double Function() shuffleRandom = _rnd.nextDouble;

/// Fisher-Yates exactly like the web app's `shuffle`, so a seeded run gives the same order on both
List<T> shuffled<T>(List<T> a) {
  final b = List<T>.of(a);
  for (var i = b.length - 1; i > 0; i--) {
    final j = (shuffleRandom() * (i + 1)).floor();
    final t = b[i];
    b[i] = b[j];
    b[j] = t;
  }
  return b;
}

/// mulberry32 (same numbers as the JS version used by tool/shoot_web_m2.py)
double Function() mulberry32(int seed) {
  var a = seed & 0xFFFFFFFF;
  return () {
    a = (a + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = a;
    t = _imul(t ^ (t >> 15), t | 1);
    t ^= (t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296;
  };
}

int _imul(int a, int b) => ((a & 0xFFFFFFFF) * (b & 0xFFFFFFFF)) & 0xFFFFFFFF;

/// state of one notes card ("lessonId~i")
class CardW {
  String? pin;
  final Set<String> seen = {};
  bool? legend;
  int step = 0, state = 0, shown = 0;
  final Set<int> rq = {};
  String? ans;
}

/// feedback of the current game item
class GameFb {
  GameFb({required this.ok, this.late = false, this.bin, this.pick, this.show = false});
  final bool ok, late, show;
  final String? bin, pick;
}

/// one inline game being played (web `G` / `GS[gid]`)
class GameS extends ChangeNotifier {
  GameS(this.g, this.u) {
    switch (g) {
      case MatchGame(:final pairs):
        this.pairs = pairs;
      case WordMatchGame(:final pairs):
        this.pairs = pairs;
      case BuilderGame(:final items):
        order = shuffled(List.generate(items.length, (i) => i));
      case SortGame(:final items):
        order = shuffled(List.generate(items.length, (i) => i));
      case TfGame(:final items):
        order = shuffled(List.generate(items.length, (i) => i));
      case FillGame(:final items):
        order = shuffled(List.generate(items.length, (i) => i));
      case FormGame(:final items):
        order = shuffled(List.generate(items.length, (i) => i));
      case FlashGame(:final cards):
        order = shuffled(List.generate(cards.length, (i) => i));
      case LabelGame(:final diagram):
        order = shuffled(List.generate(u.diagrams[diagram]?.pins.length ?? 0, (i) => i));
    }
    if (pairs != null) {
      left = shuffled(List.generate(pairs!.length, (i) => i));
      rightO = shuffled(List.generate(pairs!.length, (i) => i));
      total = pairs!.length;
    } else {
      total = order.length;
    }
  }
  final Game g;
  final Unit u;
  int right = 0, total = 0, miss = 0, i = 0;
  GameFb? fb;
  List<int> order = [];
  // match / wordmatch
  List<(String, String)>? pairs;
  List<int> left = [], rightO = [];
  final Set<int> done = {};
  ({String side, int i})? sel;
  ({int a, int b})? bad;
  // fill / label: wrong tries; label: option pool
  List<Object>? tried;
  List<int>? pool;
  bool flip = false;
  // builder
  List<int>? bank;
  List<int> line = [];
  int tries = 0;
  // tf timer
  Timer? timer;
  double timeLeft = 1;
  // result
  ({int stars, int right, int total})? over;
  bool disposed = false;

  void changed() {
    if (!disposed) notifyListeners();
  }

  void stopTimer() {
    timer?.cancel();
    timer = null;
  }

  @override
  void dispose() {
    disposed = true;
    stopTimer();
    super.dispose();
  }
}

/// exercise answers of one unit (web `EXS[u.id]`)
class ExS {
  final Map<String, Object> ans = {};
  final Map<String, bool> res = {};
  final Set<String> ck = {};
  final Set<String> sim = {};
  bool saved = false;
}

class NotesSession {
  NotesSession._();
  static final cw = <String, CardW>{};
  static final gs = <String, GameS>{};
  static final exs = <String, ExS>{};
  static CardW card(String unitId, String key) => cw.putIfAbsent('$unitId|$key', CardW.new);
  static ExS ex(String unitId) => exs.putIfAbsent(unitId, ExS.new);
  static void stopTimers() {
    for (final g in gs.values) {
      g.stopTimer();
    }
  }

  static void clear() {
    for (final g in gs.values) {
      g.dispose();
    }
    cw.clear();
    gs.clear();
    exs.clear();
  }
}
