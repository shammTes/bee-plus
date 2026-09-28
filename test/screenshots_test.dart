// Renders the app at 390×844 logical px @2x with the real bundled fonts and writes PNGs to compare/flutter/.
//   flutter test test/screenshots_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junior/junior/app.dart';
import 'package:junior/junior/data/repository.dart';
import 'package:junior/junior/notes/session.dart';
import 'package:junior/junior/screens/exam_player.dart';
import 'package:junior/junior/screens/grade_page.dart';
import 'package:junior/junior/screens/mistakes_page.dart';
import 'package:junior/junior/widgets/clay_widgets.dart';
import 'package:junior/junior/notes/games.dart';
import 'package:junior/junior/screens/shell.dart';
import 'package:junior/junior/screens/unit_page.dart';
import 'package:junior/junior/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> loadFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final f in manifest) {
    final loader = FontLoader(f['family'] as String);
    for (final a in f['fonts'] as List) {
      loader.addFont(rootBundle.load(a['asset'] as String));
    }
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = ContentRepo(useIsolate: false);
  final shotKey = GlobalKey();

  setUpAll(() async {
    await loadFonts();
    await repo.init();
    await repo.booksOfGrade(8);
    await repo.papers();
  });

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    required String lang,
    bool dark = false,
    AppTab tab = AppTab.home,
    List<Widget> routes = const [],
    bool settings = false,
    void Function(AppState s)? seed,
    Future<void> Function(WidgetTester t)? act,
  }) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    NotesSession.clear();
    final state = AppState(repo, await SharedPreferences.getInstance());
    state.lang = lang;
    state.dark = dark;
    seed?.call(state);
    await tester.pumpWidget(
      RepaintBoundary(
        key: shotKey,
        child: JuniorApp(
          state: state,
          home: Shell(initialTab: tab, initialRoutes: routes, settingsOpen: settings),
        ),
      ),
    );
    // flutter_svg decodes off the frame: let real async work finish, then settle
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    if (act != null) {
      await act(tester);
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
    }
    final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(shotKey));
    await tester.runAsync(() async {
      final img = await ro.toImage(pixelRatio: 2);
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      final f = File('compare/flutter/$name.png')..createSync(recursive: true);
      f.writeAsBytesSync(bd!.buffer.asUint8List());
    });
  }

  for (final lang in ['en', 'ti']) {
    for (final dark in [false, true]) {
      final sfx = lang + (dark ? '_dark' : '');
      testWidgets('home $sfx', (t) => shoot(t, 'home_$sfx', lang: lang, dark: dark));
      testWidgets('grade8 $sfx', (t) => shoot(t, 'grade8_$sfx', lang: lang, dark: dark, routes: const [GradePage(grade: 8)]));
      testWidgets('settings $sfx', (t) => shoot(t, 'settings_$sfx', lang: lang, dark: dark, settings: true));
      testWidgets('exams $sfx', (t) => shoot(t, 'exams_$sfx', lang: lang, dark: dark, tab: AppTab.exams));
    }
  }

  // ---- milestone 2: unit page
  for (final lang in ['en', 'ti']) {
    testWidgets(
      'unit top $lang',
      (t) => shoot(
        t,
        'unit_top_$lang',
        lang: lang,
        routes: const [
          GradePage(grade: 8),
          UnitPage(bookId: 'science_8', unitId: 'sci8-u1'),
        ],
      ),
    );
  }

  // ---- milestone 2 + 3 scenes (same as tool/shoot_web_m2.py)
  const bid = 'science_8', uid = 'sci8-u1', exam = 'science-2019-g8';
  final qids = [for (var i = 1; i <= 50; i++) '$exam-p1-q${i.toString().padLeft(2, '0')}'];
  const unitRoutes = [GradePage(grade: 8)];
  for (final lang in ['en', 'ti']) {
    testWidgets(
      'm2m3 unit games $lang',
      (t) => shoot(
        t,
        'unit_games_$lang',
        lang: lang,
        routes: const [
          ...unitRoutes,
          UnitPage(bookId: bid, unitId: uid, focus: 'sec:games'),
        ],
      ),
    );
    testWidgets(
      'm2m3 unit game $lang',
      (t) => shoot(
        t,
        'unit_game_$lang',
        lang: lang,
        routes: const [
          ...unitRoutes,
          UnitPage(bookId: bid, unitId: uid, focus: 'g:$uid-g2'),
        ],
        act: (t) async {
          shuffleRandom = mulberry32(7);
          final card = find.byWidgetPredicate((w) => w is GameCard && w.game.id == '$uid-g2', skipOffstage: false);
          t.widget<ClayButton>(find.descendant(of: card, matching: find.byType(ClayButton), skipOffstage: false).first).onTap!();
          await t.pump();
        },
      ),
    );
    testWidgets(
      'm2m3 unit questions $lang',
      (t) => shoot(
        t,
        'unit_questions_$lang',
        lang: lang,
        routes: const [
          ...unitRoutes,
          UnitPage(bookId: bid, unitId: uid, focus: 'sec:questions'),
        ],
        seed: (s) {
          final e = NotesSession.ex(uid);
          e.ans['$uid-q1'] = 'A';
          e.res['$uid-q1'] = false;
          e.ck.add('$uid-q1');
          s.nmMark(bid, uid, '$uid-q1', false);
        },
      ),
    );
    testWidgets(
      'm2m3 exam $lang',
      (t) => shoot(
        t,
        'exam_$lang',
        lang: lang,
        tab: AppTab.exams,
        routes: const [PracticePage()],
        seed: (s) => s.run = {
          'qids': qids,
          'i': 3,
          'ans': {qids[3]: 'B'},
          'res': <String, dynamic>{},
          'checked': false,
          'done': false,
          'mode': 'paper',
          'examId': exam,
          'subj': 'science',
        },
      ),
    );
    testWidgets(
      'm2m3 result $lang',
      (t) => shoot(
        t,
        'result_$lang',
        lang: lang,
        tab: AppTab.exams,
        routes: const [ResultPage()],
        seed: (s) {
          s.run = {
            'qids': qids,
            'i': 49,
            'ans': <String, dynamic>{},
            'res': <String, dynamic>{},
            'checked': true,
            'done': true,
            'mode': 'paper',
            'examId': exam,
            'subj': 'science',
            'right': 38,
            'total': 50,
            'stars': 2,
          };
          s.best[exam] = {'stars': 2, 'right': 38, 'total': 50};
        },
      ),
    );
    void seedMistakes(AppState s) {
      s.mistakes.addAll({qids[0]: exam, qids[1]: exam, 'social-studies-2016-g8-p1-q01': 'social-studies-2016-g8'});
      s.notesMist.addAll({
        '$bid|$uid-q1': {'b': bid, 'u': uid, 'q': '$uid-q1', 't': 1},
        '$bid|$uid-q2': {'b': bid, 'u': uid, 'q': '$uid-q2', 't': 2},
      });
    }

    testWidgets('m2m3 mistakes $lang', (t) => shoot(t, 'mistakes_$lang', lang: lang, tab: AppTab.mistakes, seed: seedMistakes));
    testWidgets(
      'm2m3 nex $lang',
      (t) => shoot(
        t,
        'nex_$lang',
        lang: lang,
        tab: AppTab.mistakes,
        seed: seedMistakes,
        act: (t) async => startNMist(t.element(find.byType(MistakesPage)), bid, uid),
      ),
    );
  }
}
