// Every unit of every bundled notes book: the unit page renders all note cards, memory recap, games and questions without
// exceptions (overflow included); every game is started with its Play button and played to the end (with a wrong try where
// the game allows one); every exercise question is answered and checked (wrong answers must land in My mistakes).
//   flutter test test/all_units_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junior/junior/app.dart';
import 'package:junior/junior/data/notes_models.dart';
import 'package:junior/junior/data/repository.dart';
import 'package:junior/junior/notes/cards.dart';
import 'package:junior/junior/notes/exercise.dart';
import 'package:junior/junior/notes/games.dart';
import 'package:junior/junior/notes/session.dart';
import 'package:junior/junior/notes/ui.dart';
import 'package:junior/junior/screens/shell.dart';
import 'package:junior/junior/screens/unit_page.dart';
import 'package:junior/junior/state/app_state.dart';
import 'package:junior/junior/widgets/clay_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// (book id, unit id) of every unit, read synchronously so each unit is its own test
List<(String, String)> allUnits() {
  final idx = jsonDecode(File('assets/junior/content/index.json').readAsStringSync()) as Map;
  final out = <(String, String)>[];
  for (final f in (idx['notes'] as List).cast<String>()) {
    final j = jsonDecode(File('assets/junior/content/notes/$f').readAsStringSync()) as Map;
    final bid = f.replaceAll('.json', '');
    for (final u in j['units'] as List) {
      out.add((bid, (u as Map)['id'] as String));
    }
  }
  return out;
}

Future<void> settle(WidgetTester t) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await t.pump(const Duration(milliseconds: 100));
  await t.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 20));
}

/// play one started game to its end through the same engine calls its buttons make
Future<void> playGame(WidgetTester t, AppState app, Game g) async {
  final s = NotesSession.gs[g.id];
  expect(s, isNotNull, reason: 'Play did not start ${g.id}');
  final e = GameEngine(s!, app);
  var guard = 0;
  while (s.over == null) {
    if (++guard > 400) fail('game ${g.id} did not end');
    switch (g) {
      case MatchGame() || WordMatchGame():
        final n = s.total;
        if (s.done.isEmpty && n > 1 && s.miss == 0) {
          e.matchTap('a', 0);
          await t.pump();
          e.matchTap('b', 1);
          await t.pump(const Duration(milliseconds: 600));
        }
        for (var i = 0; i < n; i++) {
          if (s.done.contains(i)) continue;
          e.matchTap('a', i);
          await t.pump();
          e.matchTap('b', i);
          await t.pump();
        }
        await t.pump(const Duration(milliseconds: 600));
      case FlashGame():
        s.flip = true;
        s.changed();
        await t.pump(const Duration(milliseconds: 700));
        s.right++;
        e.next();
      case TfGame(:final items):
        final it = items[s.order[s.i]];
        e.answer(s.i == 0 ? !it.answer : it.answer);
        await t.pump();
        e.next();
      case SortGame(:final items, :final groups):
        final it = items[s.order[s.i]];
        final wrong = groups.map((x) => x.$1).firstWhere((x) => x != it.$2, orElse: () => it.$2);
        e.answer(s.i == 0 ? wrong : it.$2);
        await t.pump();
        e.next();
      case FillGame(:final items) || FormGame(:final items):
        final ChoiceItem it = items[s.order[s.i]];
        final wrong = it.choices.where((c) => c != it.answer).firstOrNull;
        if (s.i == 0 && wrong != null) {
          e.answer(wrong);
          await t.pump();
          if (s.fb == null) e.answer(it.answer);
        } else {
          e.answer(it.answer);
        }
        await t.pump();
        e.next();
      case LabelGame():
        final k = s.order[s.i];
        if (s.i == 0 && s.total > 1) {
          e.answer((k + 1) % s.total);
          await t.pump();
        }
        e.answer(k);
        await t.pump();
        e.next();
      case BuilderGame(:final items):
        final it = items[s.order[s.i]];
        e.ensureBank();
        final n = it.words.length;
        if (s.i == 0 && n > 1) {
          for (var k = n - 1; k >= 0; k--) {
            e.bankTap(k);
          }
          await t.pump();
          e.check();
          await t.pump();
          e.clear();
        }
        for (var k = 0; k < n; k++) {
          e.bankTap(k);
        }
        await t.pump();
        e.check();
        await t.pump();
        e.next();
    }
    await t.pump();
  }
  expect(app.gameBest(g.id), isNotNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = ContentRepo(useIsolate: false);
  setUpAll(() async => repo.init());
  tearDown(NotesSession.clear);

  final units = allUnits();
  test('there are 195 units', () => expect(units.length, 195));

  for (final (bid, uid) in units) {
    testWidgets('unit $bid/$uid', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({});
      final app = AppState(repo, await SharedPreferences.getInstance());
      final book = await t.runAsync(() => repo.book(bid));
      final u = book!.unit(uid)!;
      await t.pumpWidget(
        JuniorApp(
          state: app,
          home: Shell(initialRoutes: [UnitPage(bookId: bid, unitId: uid)]),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await t.pump(const Duration(milliseconds: 100));
      }
      await t.pumpAndSettle();

      // every lesson card is on the page (one scrolling column)
      final nCards = u.lessons.fold<int>(0, (a, l) => a + l.cards.length);
      expect(find.byType(NoteCardView, skipOffstage: false), findsAtLeastNWidgets(nCards));

      // scroll to the end so the read marks / jump bar tracking run over the whole page
      final scroll = find.byType(Scrollable).first;
      final pos = t.state<ScrollableState>(scroll).position;
      while (pos.pixels < pos.maxScrollExtent) {
        pos.jumpTo((pos.pixels + 700).clamp(0, pos.maxScrollExtent));
        await t.pump(const Duration(milliseconds: 50));
      }
      await t.pumpAndSettle();

      // games: Play, then play to the end
      expect(find.byType(GameCard, skipOffstage: false), findsNWidgets(u.games.length));
      for (final g in u.games) {
        final card = find.byWidgetPredicate((w) => w is GameCard && w.game.id == g.id, skipOffstage: false);
        final play = find.descendant(of: card, matching: find.byType(ClayButton), skipOffstage: false);
        t.widget<ClayButton>(play.first).onTap!();
        await t.pump();
        await playGame(t, app, g);
        await t.pump();
      }
      await settle(t);

      // questions: answer each (alternating first / last option), Check, open the similar question
      final qs = u.exercise.questions;
      expect(find.byType(QCard, skipOffstage: false), findsNWidgets(qs.length));
      for (final (i, q) in qs.indexed) {
        final card = find.byWidgetPredicate((w) => w is QCard && w.q.id == q.id, skipOffstage: false);
        final opts = find.descendant(of: card, matching: find.byType(OptButton), skipOffstage: false);
        if (exGraded(q)) {
          final n = opts.evaluate().length;
          expect(n, greaterThan(0), reason: 'question ${q.id} has no options');
          t.widget<OptButton>(opts.at(i.isEven ? 0 : n - 1)).onTap!();
          await t.pump();
        }
        final btn = find.descendant(of: card, matching: find.byType(ClayButton), skipOffstage: false);
        t.widget<ClayButton>(btn.last).onTap!();
        await t.pump();
        final sim = find.descendant(of: card, matching: find.byType(ClayButton), skipOffstage: false);
        if (sim.evaluate().isNotEmpty) {
          t.widget<ClayButton>(sim.last).onTap?.call();
          await t.pump();
        }
      }
      await settle(t);
      final e = NotesSession.ex(u.id);
      for (final q in qs.where(exGraded)) {
        expect(e.ck.contains(q.id), isTrue);
        expect(app.notesMist.containsKey('$bid|${q.id}'), e.res[q.id] == false, reason: 'My mistakes out of sync for ${q.id}');
      }
      if (qs.any(exGraded)) expect(app.exResult(u.id), isNotNull);

      // leave the page cleanly (timers stopped)
      NotesSession.stopTimers();
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  }
}
