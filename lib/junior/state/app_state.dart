// App state, persisted as one JSON value under "junior:v1" – the same shape as the web app's localStorage record,
// so progress logic stays identical: {v, lang, theme, best, mistakes, run, notes: {read, games, ex, last, mist}}.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/notes_models.dart';
import '../data/repository.dart';
import '../l10n/labels.dart';
import '../notes/session.dart';

class AppState extends ChangeNotifier {
  AppState(this.repo, [this._prefs]);
  final ContentRepo repo;
  SharedPreferences? _prefs;
  static const key = 'junior:v1';

  String lang = 'en';
  bool dark = false;
  Map<String, dynamic> best = {}; // examId -> {stars, last, of}
  Map<String, dynamic> mistakes = {}; // questionId -> examId
  Map<String, dynamic>? run; // unfinished exam run
  Map<String, dynamic> notes = {
    'read': <String, dynamic>{},
    'games': <String, dynamic>{},
    'ex': <String, dynamic>{},
    'last': null,
    'mist': <String, dynamic>{},
  };

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(key);
    if (raw == null) return;
    try {
      final o = jsonDecode(raw) as Map<String, dynamic>;
      if (o['v'] != 1) return;
      lang = kLabels.containsKey(o['lang']) ? o['lang'] as String : 'en';
      dark = o['theme'] == 'dark';
      best = Map<String, dynamic>.from(o['best'] as Map? ?? {});
      mistakes = Map<String, dynamic>.from(o['mistakes'] as Map? ?? {});
      run = o['run'] == null ? null : Map<String, dynamic>.from(o['run'] as Map);
      final n = Map<String, dynamic>.from(o['notes'] as Map? ?? {});
      for (final k in ['read', 'games', 'ex', 'mist']) {
        notes[k] = Map<String, dynamic>.from(n[k] as Map? ?? {});
      }
      notes['last'] = n['last'];
    } catch (_) {
      /* corrupt record: start fresh */
    }
  }

  Map<String, dynamic> toJson() => {'v': 1, 'lang': lang, 'theme': dark ? 'dark' : 'light', 'best': best, 'mistakes': mistakes, 'run': run, 'notes': notes};

  Timer? _saveT;
  void _changed() {
    notifyListeners();
    _saveT?.cancel();
    _saveT = Timer(const Duration(milliseconds: 250), save);
  }

  Future<void> save() async {
    _saveT?.cancel();
    await _prefs?.setString(key, jsonEncode(toJson()));
  }

  // ---- labels
  String t(String k, [Map<String, Object>? vars]) {
    var s = kLabels[lang]?[k] ?? kLabels['en']![k] ?? k;
    if (vars != null) s = s.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => vars[m[1]]?.toString() ?? m[0]!);
    return s;
  }

  String en(String k) => kLabels['en']![k] ?? k;
  String nQ(int n) => n == 1 ? t('oneQuestion') : t('nQuestions', {'n': n});

  void setLang(String l) {
    if (l == lang || !kLabels.containsKey(l)) return;
    lang = l;
    _changed();
  }

  void setDark(bool d) {
    if (d == dark) return;
    dark = d;
    _changed();
  }

  void resetAll() {
    NotesSession.clear();
    best = {};
    mistakes = {};
    run = null;
    notes = {'read': <String, dynamic>{}, 'games': <String, dynamic>{}, 'ex': <String, dynamic>{}, 'last': null, 'mist': <String, dynamic>{}};
    _changed();
  }

  // ---- notes progress (same formulas as the web app)
  Map<String, dynamic> get _read => notes['read'] as Map<String, dynamic>;
  Map<String, dynamic> get _games => notes['games'] as Map<String, dynamic>;
  Map<String, dynamic> get _ex => notes['ex'] as Map<String, dynamic>;
  Map<String, dynamic> get notesMist => notes['mist'] as Map<String, dynamic>;

  double lessonPct(Lesson l) => l.cards.isEmpty ? 1 : (((_read[l.id] as num?) ?? 0) / l.cards.length).clamp(0, 1).toDouble();

  /// lessons 60 %, games 20 %, exercise 20 %
  int unitPct(Unit u) {
    final L = u.lessons.isEmpty ? 0.0 : u.lessons.fold<double>(0, (a, l) => a + lessonPct(l)) / u.lessons.length;
    final G = u.games.isEmpty ? 1.0 : u.games.where((g) => _games[g.id] != null).length / u.games.length;
    return (100 * (0.6 * L + 0.2 * G + 0.2 * (_ex[u.id] != null ? 1 : 0))).round();
  }

  /// {book, unit} of the last opened unit, for the Continue card
  ({String book, String unit})? get lastUnit {
    final l = notes['last'];
    if (l is Map && l['book'] is String && l['unit'] is String) return (book: l['book'] as String, unit: l['unit'] as String);
    return null;
  }

  /// opening a unit: keeps the saved card position when it is the same unit (web: `n.last = Object.assign(...)`)
  void setLast(String book, String unit) {
    final l = notes['last'];
    final keep = l is Map && l['unit'] == unit ? Map<String, dynamic>.from(l) : <String, dynamic>{};
    keep
      ..['book'] = book
      ..['unit'] = unit
      ..remove('lesson');
    notes['last'] = keep;
    _changed();
  }

  /// the card ("lessonId~i") last seen in the last unit
  String? get lastCard {
    final l = notes['last'];
    return l is Map && l['card'] is String ? l['card'] as String : null;
  }

  /// a card counted as read (on screen); saved quietly (no rebuild of the app), like the web IntersectionObserver
  bool markRead(String unitId, String lessonId, int i) {
    var dirty = false;
    if (((_read[lessonId] as num?) ?? 0) < i + 1) {
      _read[lessonId] = i + 1;
      dirty = true;
    }
    final l = notes['last'];
    if (l is Map && l['unit'] == unitId && l['card'] != '$lessonId~$i') {
      l['card'] = '$lessonId~$i';
      dirty = true;
    }
    if (dirty) _quiet();
    return dirty;
  }

  void _quiet() {
    _saveT?.cancel();
    _saveT = Timer(const Duration(milliseconds: 400), save);
  }

  int? gameBest(String gid) => (_games[gid] as num?)?.toInt();
  void gameDone(String gid, int stars) {
    _games[gid] = stars > (gameBest(gid) ?? 0) ? stars : (gameBest(gid) ?? stars);
    _changed();
  }

  Map<String, dynamic>? exResult(String uid) => _ex[uid] as Map<String, dynamic>?;
  void exDone(String uid, int stars, int right, int of) {
    final b = (_ex[uid] as Map?)?['stars'] as num? ?? 0;
    _ex[uid] = {'stars': stars > b ? stars : b.toInt(), 'right': right, 'of': of};
    _changed();
  }

  /// notes exercise: wrong -> My mistakes, right -> removed (`nmMark`)
  void nmMark(String bid, String uid, String qid, bool ok) {
    final k = '$bid|$qid';
    if (ok) {
      notesMist.remove(k);
    } else {
      notesMist[k] = {'b': bid, 'u': uid, 'q': qid, 't': DateTime.now().millisecondsSinceEpoch};
    }
    _changed();
  }

  // ---- exam runs (`S.run`): {qids, i, ans, res, checked, done, mode: paper|mistakes, examId, subj, right, total, stars}
  void startRun(List<String> qids, {required String mode, String? examId, required String subj}) {
    run = {'qids': qids, 'i': 0, 'ans': <String, dynamic>{}, 'res': <String, dynamic>{}, 'checked': false, 'done': false, 'mode': mode, 'examId': ?examId, 'subj': subj};
    _changed();
  }

  void runChoose(String qid, String letter) {
    final r = run;
    if (r == null || r['checked'] == true) return;
    (r['ans'] as Map)[qid] = letter;
    _changed();
  }

  void runCheck(String qid, bool? ok, String examId) {
    final r = run;
    if (r == null) return;
    if (ok != null) {
      (r['res'] as Map)[qid] = ok;
      ok ? mistakes.remove(qid) : mistakes[qid] = examId;
    }
    r['checked'] = true;
    _changed();
  }

  /// next question; at the end: stars + best score (paper mode). Returns true when the run is done.
  bool runNext(int Function(int right, int n) starsFor, bool Function(String qid) gradable) {
    final r = run!;
    final qids = (r['qids'] as List).cast<String>();
    if ((r['i'] as int) + 1 < qids.length) {
      r['i'] = (r['i'] as int) + 1;
      r['checked'] = false;
      _changed();
      return false;
    }
    final g = qids.where(gradable).toList(), res = r['res'] as Map;
    final right = g.where((id) => res[id] == true).length, stars = starsFor(right, g.length);
    r
      ..['done'] = true
      ..['right'] = right
      ..['total'] = g.length
      ..['stars'] = stars;
    if (r['mode'] == 'paper') {
      final b = (best[r['examId']] as Map?)?['stars'] as num? ?? 0;
      best[r['examId'] as String] = {'stars': stars > b ? stars : b.toInt(), 'last': right, 'of': g.length};
    }
    _changed();
    return true;
  }

  /// number shown on the My mistakes badge: exam mistakes + notes-exercise mistakes
  int get mistakeCount => mistakes.length + notesMist.length;

  @override
  void dispose() {
    _saveT?.cancel();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static AppState read(BuildContext c) => c.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
