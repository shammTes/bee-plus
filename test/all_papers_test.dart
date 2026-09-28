// Every bundled exam paper opens (through its Paper A / B page when the year has two papers), every question can be
// answered (Check / Show answer, then Next), the result page shows the score, wrong answers land in My mistakes and can be
// retried from the My mistakes tab; a stopped paper shows the Continue card and resumes at the same question.
//   flutter test test/all_papers_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junior/junior/app.dart';
import 'package:junior/junior/data/exam_models.dart';
import 'package:junior/junior/data/repository.dart';
import 'package:junior/junior/notes/session.dart';
import 'package:junior/junior/notes/ui.dart';
import 'package:junior/junior/screens/exam_player.dart';
import 'package:junior/junior/screens/exams_page.dart';
import 'package:junior/junior/screens/mistakes_page.dart';
import 'package:junior/junior/screens/shell.dart';
import 'package:junior/junior/state/app_state.dart';
import 'package:junior/junior/widgets/clay_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<String> allPaperIds() {
  final idx = jsonDecode(File('assets/junior/content/index.json').readAsStringSync()) as Map;
  return [
    for (final f in (idx['exams'] as List).cast<String>()) ((jsonDecode(File('assets/junior/content/exams/$f').readAsStringSync()) as Map)['exam'] as Map)['id'] as String,
  ];
}

Future<void> settle(WidgetTester t) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await t.pump(const Duration(milliseconds: 100));
  await t.pumpAndSettle();
}

Finder button(String label) => find.byWidgetPredicate((w) => w is ClayButton && w.label == label);

Future<void> tapButton(WidgetTester t, String label) async {
  final f = button(label);
  expect(f, findsOneWidget, reason: 'button "$label"');
  t.widget<ClayButton>(f).onTap!();
  await settle(t);
}

/// answer the current run from question i to the end: even questions right, odd questions wrong
Future<void> answerRun(WidgetTester t, AppState s, {int? stopAt}) async {
  while (true) {
    final r = s.run!;
    final qids = (r['qids'] as List).cast<String>(), i = r['i'] as int;
    if (stopAt != null && i == stopAt) return;
    final (q, _) = s.repo.qid[qids[i]]!;
    expect(find.byType(PracticePage), findsOneWidget);
    if (q.image != null) await settle(t);
    if (gradable(q)) {
      final letters = q.options.keys.toList();
      final right = letters.firstWhere(q.isCorrect, orElse: () => letters.first);
      final wrong = letters.firstWhere((l) => !q.isCorrect(l), orElse: () => right);
      final pick = i.isEven ? right : wrong;
      final opts = find.byType(OptButton);
      expect(opts, findsNWidgets(letters.length));
      t.widget<OptButton>(opts.at(letters.indexOf(pick))).onTap!();
      await t.pump();
      await tapButton(t, s.t('check'));
      expect(s.mistakes.containsKey(q.id), !q.isCorrect(pick));
    } else {
      await tapButton(t, s.t('showAnswer'));
    }
    expect(find.byType(ExamFeedback), findsOneWidget);
    await tapButton(t, i + 1 < qids.length ? s.t('next') : s.t('seeResult'));
    if (i + 1 >= qids.length) return;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = ContentRepo(useIsolate: false);
  setUpAll(() async => repo.init());
  tearDown(NotesSession.clear);

  Future<AppState> boot(WidgetTester t, {AppTab tab = AppTab.exams}) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppState(repo, await SharedPreferences.getInstance());
    await t.runAsync(repo.papers);
    await t.pumpWidget(JuniorApp(state: s, home: Shell(initialTab: tab)));
    await settle(t);
    return s;
  }

  final ids = allPaperIds();
  test('there are 26 papers', () => expect(ids.length, 26));

  for (final id in ids) {
    testWidgets('paper $id', (t) async {
      final s = await boot(t);
      final e = repo.paper(id)!;
      expect(e.questions, isNotEmpty);
      final sameYear = repo.papersIfLoaded!.where((x) => x.subject?.id == e.subject?.id && x.yr == e.yr).toList();
      final ctx = t.element(find.byType(ExamsPage));
      if (sameYear.length > 1) {
        Shell.of(ctx).push(YearPage(subject: e.subject!, year: e.yr, papers: sameYear));
        await settle(t);
        final label = e.version != null ? s.t('paper', {'v': e.version!}) : s.t('paperOnly');
        final card = find.ancestor(of: find.text(label), matching: find.byType(Press));
        t.widget<Press>(card.first).onTap!();
      } else {
        startExam(ctx, e);
      }
      await settle(t);
      expect(s.run?['examId'], id);

      // stop half-way: the Continue card resumes at the same question
      final half = e.questions.length ~/ 2;
      if (half > 0) {
        await answerRun(t, s, stopAt: half);
        t.widget<RoundButton>(find.byType(RoundButton).first).onTap();
        await settle(t);
        expect(find.byType(ContCard), findsOneWidget);
        t.widget<ContCard>(find.byType(ContCard)).onTap();
        await settle(t);
        expect(s.run!['i'], half);
      }
      await answerRun(t, s);
      expect(find.byType(ResultPage), findsOneWidget);
      final r = s.run!;
      expect(r['done'], isTrue);
      final graded = e.questions.where(gradable).length;
      expect(r['total'], graded);
      expect(s.best[id], graded > 0 ? isNotNull : anything);
      expect(find.text(s.t('nRight', {'n': r['right'], 't': r['total']})), findsOneWidget);

      // wrong answers are in My mistakes: retry them all right
      final wrong = [for (final q in e.questions) if (gradable(q) && s.mistakes.containsKey(q.id)) q.id];
      if (wrong.isNotEmpty) {
        Shell.of(t.element(find.byType(ResultPage))).openTab(AppTab.mistakes);
        await settle(t);
        expect(find.byType(MistakeRow), findsWidgets);
        await tapButton(t, s.t('practise'));
        while (s.run!['done'] != true) {
          final qids = (s.run!['qids'] as List).cast<String>(), i = s.run!['i'] as int;
          final (q, _) = repo.qid[qids[i]]!;
          final letters = q.options.keys.toList();
          t.widget<OptButton>(find.byType(OptButton).at(letters.indexOf(letters.firstWhere(q.isCorrect)))).onTap!();
          await t.pump();
          await tapButton(t, s.t('check'));
          await tapButton(t, i + 1 < qids.length ? s.t('next') : s.t('seeResult'));
        }
        expect(s.mistakes, isEmpty);
        expect(find.text(s.t('allFixed')), findsOneWidget);
      }
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('every A / B year page lists its papers', (t) async {
    final s = await boot(t);
    final ctx = t.element(find.byType(ExamsPage));
    final groups = <String, List<Paper>>{};
    for (final e in repo.papersIfLoaded!) {
      groups.putIfAbsent('${e.subject?.id}|${e.yr}', () => []).add(e);
    }
    for (final g in groups.values.where((g) => g.length > 1)) {
      Shell.of(ctx).push(YearPage(subject: g.first.subject!, year: g.first.yr, papers: g));
      await settle(t);
      for (final e in g) {
        expect(find.text(e.version != null ? s.t('paper', {'v': e.version!}) : s.t('paperOnly')), findsOneWidget);
      }
      Shell.of(ctx).pop();
      await settle(t);
    }
  });
}
