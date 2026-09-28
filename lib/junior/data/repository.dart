// Loads the bundled JSON content. Books and papers are parsed lazily (on first use) in a background isolate and cached.
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';

import 'exam_models.dart';
import 'notes_models.dart';

class ContentRepo {
  ContentRepo({AssetBundle? bundle, this.useIsolate = true}) : bundle = bundle ?? rootBundle;
  final AssetBundle bundle;
  final bool useIsolate;
  static const base = 'assets/junior/content';

  NotesManifest? manifest;
  List<String> examFiles = const [], bookFiles = const [];
  final Map<String, NotesBook> _books = {};
  final Map<String, Future<NotesBook>> _bookLoads = {};
  List<Paper>? _papers;
  Future<List<Paper>>? _paperLoad;

  /// light start-up work: the manifest (unit titles for all 21 books) + the file index
  Future<void> init() async {
    final idx = jsonDecode(await bundle.loadString('$base/index.json')) as Map<String, dynamic>;
    examFiles = List<String>.from(idx['exams'] as List);
    bookFiles = List<String>.from(idx['notes'] as List);
    manifest = NotesManifest.fromJson(jsonDecode(await bundle.loadString('$base/notes/manifest.json')));
  }

  /// Decode off the UI isolate. The model is built on the caller isolate (custom objects cannot cross isolates).
  Future<Object?> _decode(String s) {
    if (!useIsolate) return Future.value(jsonDecode(s));
    return Isolate.run(() => jsonDecode(s));
  }

  bool hasBook(String id) => bookFiles.contains('$id.json');
  NotesBook? bookIfLoaded(String id) => _books[id];

  Future<NotesBook> book(String id) {
    final hit = _books[id];
    if (hit != null) return Future.value(hit); // not SynchronousFuture: it breaks Future.wait
    return _bookLoads[id] ??= () async {
      final file = '$id.json';
      final s = await bundle.loadString('$base/notes/$file', cache: false);
      // jsonDecode's maps can cross isolates. NotesBook cannot, so build it here.
      final b = NotesBook.fromJson(await _decode(s), file);
      _books[id] = b;
      return b;
    }();
  }

  /// every book of a grade, loaded in parallel (books without a notes file are skipped)
  Future<List<NotesBook>> booksOfGrade(int g) => Future.wait([
    for (final b in manifest!.grade(g))
      if (hasBook(b.id)) book(b.id),
  ]);

  /// the grade's books if they are all parsed already (lets pages paint complete on the first frame)
  List<NotesBook>? booksOfGradeIfLoaded(int g) {
    final ids = [
      for (final b in manifest!.grade(g))
        if (hasBook(b.id)) b.id,
    ];
    if (ids.any((id) => !_books.containsKey(id))) return null;
    return [for (final id in ids) _books[id]!];
  }

  Future<List<Paper>> papers() {
    if (_papers != null) return Future.value(_papers!);
    return _paperLoad ??= () async {
      final raw = await Future.wait([for (final f in examFiles) bundle.loadString('$base/exams/$f', cache: false)]);
      final files = examFiles;
      final decoded = <Object?>[];
      for (var i = 0; i < raw.length; i += 4) {
        final end = i + 4 > raw.length ? raw.length : i + 4;
        decoded.addAll(await Future.wait([for (final s in raw.sublist(i, end)) _decode(s)]));
        await Future<void>.delayed(Duration.zero);
      }
      final list = <Paper>[];
      for (var i = 0; i < decoded.length; i++) {
        list.add(Paper.fromJson(decoded[i], files[i]));
        if (i % 3 == 2) await Future<void>.delayed(Duration.zero);
      }
      return _papers = list;
    }();
  }

  List<Paper>? get papersIfLoaded => _papers;

  Map<String, (ExamQuestion, Paper)>? _qid;

  /// question id -> (question, its paper) (web QID / QEXAM); empty until [papers] has loaded
  Map<String, (ExamQuestion, Paper)> get qid {
    final ps = _papers;
    if (ps == null) return const {};
    return _qid ??= {
      for (final e in ps)
        for (final q in e.questions) q.id: (q, e),
    };
  }

  Paper? paper(String id) => _papers?.where((e) => e.id == id).firstOrNull;

  /// exam figure (question.image is "media/…"), relative to content/
  String mediaPath(String image) => '$base/${image.replaceFirst(RegExp(r'^\.?/'), '')}';

  /// diagram.svg is relative to content/notes (e.g. "svg/science_8/heart.svg")
  String svgPath(String svg) => '$base/notes/$svg';
}
