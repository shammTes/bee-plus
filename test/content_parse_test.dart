// Every paper / question / book / unit / card / game in the bundled JSON must parse into the typed models.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:junior/junior/data/exam_models.dart';
import 'package:junior/junior/data/notes_models.dart';
import 'package:junior/junior/data/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = ContentRepo(useIsolate: false);

  setUpAll(() async => repo.init());

  test('index lists every content file', () {
    expect(repo.examFiles.length, 26);
    expect(repo.bookFiles.length, 21);
  });

  test('all 26 exam papers and 1,300 questions parse', () async {
    final papers = await repo.papers();
    expect(papers.length, 26);
    final qs = papers.expand((p) => p.questions).toList();
    expect(qs.length, 1300);
    for (final p in papers) {
      expect(p.subject, isNotNull, reason: '${p.id}: unknown subject ${p.exam.subject}');
      expect(p.yr, greaterThan(2000));
      for (final q in p.questions) {
        if (q.isMcq) expect(q.options.containsKey(q.answer), isTrue, reason: '${q.id}: answer ${q.answer} not an option');
        if (q.passageId != null) expect(p.passage(q.passageId), isNotNull, reason: '${q.id}: passage ${q.passageId} missing');
        if (q.image != null) {
          expect(
            File('assets/junior/content/${q.image!.replaceFirst(RegExp(r'^\.?/'), '')}').existsSync() ||
                File('assets/junior/content/media/${q.image!.split('/').last}').existsSync(),
            isTrue,
            reason: '${q.id}: image ${q.image}',
          );
        }
      }
    }
    final subjects = papers.map((p) => p.subject!.id).toSet();
    expect(subjects, containsAll(['english', 'science', 'social', 'citizenship', 'maths']));
  });

  test('manifest: 21 books, 195 units', () {
    final m = repo.manifest!;
    expect(m.books.length, 21);
    expect(m.books.fold(0, (a, b) => a + b.units.length), 195);
    expect(m.totalUnits, 195);
  });

  test('all 21 notes books parse: every unit, lesson, card, game, question; references resolve', () async {
    var units = 0, cards = 0, games = 0, questions = 0, diagrams = 0;
    final cardTypes = <String, int>{}, gameTypes = <String, int>{};
    for (final f in repo.bookFiles) {
      final id = f.replaceAll('.json', '');
      final b = await repo.book(id);
      expect(b.info.id, id);
      final mb = repo.manifest!.byId(id)!;
      for (final mu in mb.units) {
        expect(b.unit(mu.notesId!), isNotNull, reason: '$id: manifest unit ${mu.notesId} missing in book');
      }
      for (final u in b.units) {
        units++;
        for (final d in u.diagrams.values) {
          diagrams++;
          expect(File('assets/junior/content/notes/${d.svg}').existsSync(), isTrue, reason: '${u.id}: ${d.svg} missing');
        }
        for (final l in u.lessons) {
          for (final c in l.cards) {
            cards++;
            cardTypes[c.type] = (cardTypes[c.type] ?? 0) + 1;
            final dia = switch (c) {
              DiagramCard c => c.diagram,
              StepsCard c => c.diagram,
              StatesCard c => c.diagram,
              WorkedCard c => c.diagram,
              _ => null,
            };
            if (dia != null) expect(u.diagrams.containsKey(dia), isTrue, reason: '${l.id}: diagram $dia');
            if (c is CheckCard) expect(c.options.containsKey(c.answer), isTrue, reason: '${l.id}: check answer');
          }
        }
        for (final g in u.games) {
          games++;
          gameTypes[g.type] = (gameTypes[g.type] ?? 0) + 1;
          if (g is LabelGame) expect(u.diagrams[g.diagram]?.pins, isNotEmpty, reason: '${g.id}: label game needs pins');
          if (g is SortGame) {
            final ids = g.groups.map((x) => x.$1).toSet();
            for (final it in g.items) {
              expect(ids.contains(it.$2), isTrue, reason: '${g.id}: item group ${it.$2}');
            }
          }
          if (g is FillGame) {
            for (final it in g.items) {
              expect(it.choices.contains(it.answer), isTrue, reason: '${g.id}: fill answer');
            }
          }
        }
        for (final q in u.exercise.questions) {
          questions++;
          if (q.type == 'mcq') expect(q.options.containsKey(q.answer), isTrue, reason: '${q.id}: mcq answer');
          if (q.type == 'fill') expect(q.choices.contains(q.answer), isTrue, reason: '${q.id}: fill answer');
        }
      }
    }
    // counts from the raw JSON, so nothing is silently skipped
    var rawUnits = 0, rawCards = 0, rawGames = 0, rawQ = 0;
    for (final f in repo.bookFiles) {
      final j = jsonDecode(File('assets/junior/content/notes/$f').readAsStringSync()) as Map<String, dynamic>;
      for (final u in j['units'] as List) {
        rawUnits++;
        for (final l in u['lessons'] as List) {
          rawCards += (l['cards'] as List).length;
        }
        rawGames += (u['games'] as List).length;
        rawQ += (u['exercise']['questions'] as List).length;
      }
    }
    // ignore: avoid_print
    print('parsed $units units, $cards cards $cardTypes, $games games $gameTypes, $questions questions, $diagrams diagrams');
    expect(units, 195);
    expect(units, rawUnits);
    expect(cards, rawCards);
    expect(games, rawGames);
    expect(questions, rawQ);
    expect(cardTypes.length, 14);
    expect(gameTypes.length, 9);
  });

  test('exam version / subject derivation matches the web app', () async {
    final papers = await repo.papers();
    for (final p in papers) {
      expect(p.version, anyOf('A', 'B', null));
    }
    expect(ExamSubject.of('Social Studies')!.id, 'social');
    expect(ExamSubject.of('Mathematics')!.id, 'maths');
  });
}
