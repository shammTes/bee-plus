// Typed models for content/notes/<book>.json (format: content/notes_schema.json) and content/notes/manifest.json.
import 'json_util.dart';

// ---------------------------------------------------------------- manifest (all 21 books, 195 units; light, loaded at start)
class NotesManifest {
  final List<ManifestBook> books;
  final int totalUnits;
  NotesManifest(this.books, this.totalUnits);
  factory NotesManifest.fromJson(Object? o) {
    final j = J(o, 'manifest');
    return NotesManifest(j.objs('books', ManifestBook.fromJ), j.obj('totals').integer('units'));
  }
  List<ManifestBook> grade(int g) => books.where((b) => b.grade == g).toList();
  ManifestBook? byId(String id) => books.where((b) => b.id == id).firstOrNull;
}

class ManifestBook {
  final String id, subject, subjectName;
  final int grade;
  final List<ManifestUnit> units;
  ManifestBook(this.id, this.subject, this.subjectName, this.grade, this.units);
  static ManifestBook fromJ(J j) => ManifestBook(j.str('id'), j.str('subject'), j.str('subject_name'), j.integer('grade'), j.objs('units', ManifestUnit.fromJ));
}

class ManifestUnit {
  final int n;
  final String title, status;
  final String? notesId;
  final int? page;
  ManifestUnit(this.n, this.title, this.status, this.notesId, this.page);
  static ManifestUnit fromJ(J j) => ManifestUnit(j.integer('n'), j.str('title'), j.str('status'), j.strOr('notes_id'), j.intOr('page'));
}

// ---------------------------------------------------------------- one textbook
class NotesBook {
  final BookInfo info;
  final List<Unit> units;
  NotesBook(this.info, this.units);
  factory NotesBook.fromJson(Object? o, String file) {
    final j = J(o, file);
    return NotesBook(BookInfo.fromJ(j.obj('book')), j.objs('units', Unit.fromJ));
  }
  Unit? unit(String id) => units.where((u) => u.id == id).firstOrNull;

  /// content language: book.lang, else "ti" for Tigrigna books, else "en"
  String get lang => info.lang ?? (info.subject == 'tigrigna' ? 'ti' : 'en');
}

class BookInfo {
  final String id, subject, title, pdf, source;
  final int grade, pageOffset;
  final String? lang;
  BookInfo(this.id, this.subject, this.grade, this.title, this.pdf, this.pageOffset, this.source, this.lang);
  static BookInfo fromJ(J j) =>
      BookInfo(j.str('id'), j.str('subject'), j.integer('grade'), j.str('title'), j.str('pdf'), j.integer('page_offset'), j.str('source'), j.strOr('lang'));
}

class Unit {
  final String id, title, status, tone, intro;
  final int number;
  final int? introPage;
  final List<int> pages;
  final Map<String, Diagram> diagrams;
  final List<Lesson> lessons;
  final List<GlossaryItem> glossary;
  final List<Tip> tips;
  final List<Game> games;
  final Exercise exercise;
  final List<Map<String, dynamic>> links;
  Unit(
    this.id,
    this.number,
    this.title,
    this.status,
    this.pages,
    this.tone,
    this.intro,
    this.introPage,
    this.diagrams,
    this.lessons,
    this.glossary,
    this.tips,
    this.games,
    this.exercise,
    this.links,
  );
  static Unit fromJ(J j) {
    final id = j.str('id');
    final dj = j.obj('diagrams');
    return Unit(
      id,
      j.integer('number'),
      j.str('title'),
      j.str('status'),
      [for (final p in j.list('pages')) (p as num).toInt()],
      j.str('tone'),
      j.str('intro'),
      j.intOr('intro_page'),
      {for (final e in dj.m.entries) e.key: Diagram.fromJ(J(e.value, '${dj.where}.${e.key}'))},
      j.objs('lessons', Lesson.fromJ),
      j.objs('glossary', GlossaryItem.fromJ),
      j.objs('tips', Tip.fromJ),
      j.objs('games', Game.fromJ),
      Exercise.fromJ(j.obj('exercise')),
      [for (final x in j.list('links', optional: true)) Map<String, dynamic>.from(x as Map)],
    );
  }

  int get cardCount => lessons.fold(0, (a, l) => a + l.cards.length);
}

class Diagram {
  final String svg, title;
  final String? figure;
  final int page;
  final List<Pin> pins;
  Diagram(this.svg, this.title, this.figure, this.page, this.pins);
  static Diagram fromJ(J j) => Diagram(j.str('svg'), j.str('title'), j.strOr('figure'), j.integer('page'), j.objs('pins', Pin.fromJ));
}

class Pin {
  final String id, text;
  final double x, y;
  Pin(this.id, this.text, this.x, this.y);
  static Pin fromJ(J j) => Pin(j.str('id'), j.str('text'), j.number('x'), j.number('y'));
}

class Lesson {
  final String id, title;
  final String number; // "1.2" (as printed)
  final List<int> pages;
  final List<NoteCard> cards;
  Lesson(this.id, this.number, this.title, this.pages, this.cards);
  static Lesson fromJ(J j) => Lesson(
    j.str('id'),
    '${j.m['number'] is num || j.m['number'] is String ? j.m['number'] : throw FormatException('${j.where}.number')}',
    j.str('title'),
    [for (final p in j.list('pages')) (p as num).toInt()],
    j.objs('cards', NoteCard.fromJ),
  );
}

class GlossaryItem {
  final String term, meaning;
  final int page;
  final List<String> forms;
  GlossaryItem(this.term, this.meaning, this.page, this.forms);
  static GlossaryItem fromJ(J j) => GlossaryItem(j.str('term'), j.str('meaning'), j.integer('page'), j.strs('forms', optional: true));
}

class Tip {
  final String text;
  final int? page;
  Tip(this.text, this.page);
  static Tip fromJ(J j) => Tip(j.str('text'), j.intOr('page'));
}

// ---------------------------------------------------------------- cards
sealed class NoteCard {
  final String type;
  final int page;
  final String title;
  final List<String> body;
  NoteCard(J j, {String? title})
    : type = j.str('type'),
      page = j.integer('page'),
      title = title ?? j.strOr('title') ?? '',
      body = j.strs('body', optional: true);

  static NoteCard fromJ(J j) => switch (j.str('type')) {
    'text' => TextCard(j),
    'remember' => RememberCard(j),
    'mnemonic' => MnemonicCard(j),
    'diagram' => DiagramCard(j),
    'steps' => StepsCard(j),
    'states' => StatesCard(j),
    'table' => TableCard(j),
    'check' => CheckCard(j),
    'grammar' => GrammarCard(j),
    'vocab' => VocabCard(j),
    'reading' => ReadingCard(j),
    'model' => ModelCard(j),
    'worked' => WorkedCard(j),
    'graph' => GraphCard(j),
    final t => throw FormatException('${j.where}: unknown card type "$t"'),
  };
}

class TextCard extends NoteCard {
  TextCard(super.j);
}

class RememberCard extends NoteCard {
  RememberCard(super.j);
}

class MnemonicCard extends NoteCard {
  final List<MnemonicLetter> letters;
  MnemonicCard(J j) : letters = j.objs('letters', (x) => MnemonicLetter(x.str('l'), x.str('w'), x.str('m')), optional: true), super(j);
}

class MnemonicLetter {
  final String l, w, m;
  MnemonicLetter(this.l, this.w, this.m);
}

/// mode: explore (tap the pins) | labels (names shown) | plain
class DiagramCard extends NoteCard {
  final String diagram, mode;
  final String? show;
  DiagramCard(J j) : diagram = j.str('diagram'), mode = j.str('mode'), show = j.strOr('show'), super(j);
}

class StepsCard extends NoteCard {
  final String diagram;
  final List<StepItem> steps;
  StepsCard(J j) : diagram = j.str('diagram'), steps = j.objs('steps', StepItem.fromJ), super(j);
}

class StepItem {
  final String text;
  final String? show, math;
  final List<String> pins;
  StepItem(this.text, this.show, this.math, this.pins);
  static StepItem fromJ(J j) => StepItem(j.strOr('text') ?? '', j.strOr('show'), j.strOr('math'), j.strs('pins', optional: true));
}

class StatesCard extends NoteCard {
  final String diagram;
  final List<StateItem> states;
  StatesCard(J j) : diagram = j.str('diagram'), states = j.objs('states', (x) => StateItem(x.str('key'), x.str('label'), x.str('text'))), super(j);
}

class StateItem {
  final String key, label, text;
  StateItem(this.key, this.label, this.text);
}

class TableCard extends NoteCard {
  final List<String> head;
  final List<List<String>> rows;
  TableCard(J j)
    : head = j.strs('head'),
      rows = [
        for (final (i, r) in j.list('rows').indexed)
          [for (final c in (r as List)) c is String ? c : throw FormatException('${j.where}.rows[$i]: cell not a string')],
      ],
      super(j);
}

class CheckCard extends NoteCard {
  final String q, answer, why;
  final Map<String, String> options;
  CheckCard(J j) : q = j.str('q'), options = j.strMap('options'), answer = j.str('answer'), why = j.str('why'), super(j);
}

class GrammarCard extends NoteCard {
  final List<String> rule;
  final String? pattern;
  final List<GrammarExample> examples;
  GrammarCard(J j)
    : rule = j.strs('rule'),
      pattern = j.strOr('pattern'),
      examples = j.objs('examples', (x) => GrammarExample(x.str('text'), x.boolean('ok'), x.strOr('fix'), x.strOr('note'))),
      super(j);
}

class GrammarExample {
  final String text;
  final bool ok;
  final String? fix, note;
  GrammarExample(this.text, this.ok, this.fix, this.note);
}

class VocabCard extends NoteCard {
  final String word, meaning, example;
  final String? pos, say;
  VocabCard(J j)
    : word = j.str('word'),
      pos = j.strOr('pos'),
      meaning = j.str('meaning'),
      example = j.str('example'),
      say = j.strOr('say'),
      super(j, title: j.str('word'));
}

class ReadingCard extends NoteCard {
  final String source;
  final List<String> paras;
  final List<ReadingQ> questions;
  ReadingCard(J j)
    : source = j.str('source'),
      paras = j.strs('paras'),
      questions = j.objs('questions', (x) => ReadingQ(x.str('q'), x.str('a'), x.intOr('page'))),
      super(j);
}

class ReadingQ {
  final String q, a;
  final int? page;
  ReadingQ(this.q, this.a, this.page);
}

/// kind: writing (model text) | speaking (dialogue lines)
class ModelCard extends NoteCard {
  final String kind;
  final List<String> task, model, phrases;
  final List<DialogueLine> lines;
  ModelCard(J j)
    : kind = j.str('kind'),
      task = j.strOrStrs('task'),
      model = j.strs('model', optional: true),
      phrases = j.strs('phrases', optional: true),
      lines = j.objs('lines', (x) => DialogueLine(x.str('who'), x.str('text')), optional: true),
      super(j);
}

class DialogueLine {
  final String who, text;
  DialogueLine(this.who, this.text);
}

/// mode: show (all steps) | try (reveal step by step)
class WorkedCard extends NoteCard {
  final String problem, answer;
  final String? mode, diagram;
  final List<StepItem> steps;
  final GraphSpec? graph;
  WorkedCard(J j)
    : problem = j.str('problem'),
      answer = j.str('answer'),
      mode = j.strOr('mode'),
      diagram = j.strOr('diagram'),
      steps = j.objs('steps', StepItem.fromJ),
      graph = j.objOr('graph') == null ? null : GraphSpec.fromJ(j.obj('graph')),
      super(j);
}

class GraphCard extends NoteCard {
  final GraphSpec graph;
  final List<StepItem> steps;
  GraphCard(J j) : graph = GraphSpec.fromJ(j.obj('graph')), steps = j.objs('steps', StepItem.fromJ, optional: true), super(j);
}

/// kind: numberline (min/max/step, points, ranges, jumps) | plane (x/y range, points, lines, polygons)
class GraphSpec {
  final String kind;
  final double? min, max, step, xmin, xmax, ymin, ymax;
  final int? labelEvery, gridStep;
  final bool grid, axes;
  final List<GPoint> points;
  final List<GLine> lines;
  final List<GPolygon> polygons;
  final List<GRange> ranges;
  final List<GJump> jumps;
  GraphSpec(
    this.kind,
    this.min,
    this.max,
    this.step,
    this.xmin,
    this.xmax,
    this.ymin,
    this.ymax,
    this.labelEvery,
    this.gridStep,
    this.grid,
    this.axes,
    this.points,
    this.lines,
    this.polygons,
    this.ranges,
    this.jumps,
  );
  static GraphSpec fromJ(J j) => GraphSpec(
    j.str('kind'),
    j.numOr('min'),
    j.numOr('max'),
    j.numOr('step'),
    j.numOr('xmin'),
    j.numOr('xmax'),
    j.numOr('ymin'),
    j.numOr('ymax'),
    j.intOr('label_every'),
    j.intOr('grid_step'),
    j.boolean('grid', true),
    j.boolean('axes', true),
    j.objs('points', GPoint.fromJ, optional: true),
    j.objs('lines', GLine.fromJ, optional: true),
    j.objs('polygons', GPolygon.fromJ, optional: true),
    j.objs('ranges', GRange.fromJ, optional: true),
    j.objs('jumps', GJump.fromJ, optional: true),
  );
}

List<double>? _pt(J j, String k) => j.has(k) ? [for (final v in j.list(k)) (v as num).toDouble()] : null;

class GPoint {
  final double x;
  final double? y;
  final String? label, color;
  final bool open;
  final List<String> s; // steps in which the point is shown (empty = always)
  GPoint(this.x, this.y, this.label, this.color, this.open, this.s);
  static GPoint fromJ(J j) => GPoint(j.number('x'), j.numOr('y'), j.strOr('label'), j.strOr('color'), j.boolean('open', false), j.strOrStrs('s'));
}

class GLine {
  final List<double>? p1, p2;
  final bool seg, dash;
  final double? m, c, x;
  final String? label, color;
  final List<String> s;
  GLine(this.p1, this.p2, this.seg, this.dash, this.m, this.c, this.x, this.label, this.color, this.s);
  static GLine fromJ(J j) => GLine(
    _pt(j, 'p1'),
    _pt(j, 'p2'),
    j.boolean('seg', false),
    j.boolean('dash', false),
    j.numOr('m'),
    j.numOr('c'),
    j.numOr('x'),
    j.strOr('label'),
    j.strOr('color'),
    j.strOrStrs('s'),
  );
}

class GPolygon {
  final List<List<double>> pts;
  final String? color;
  final List<String> s;
  GPolygon(this.pts, this.color, this.s);
  static GPolygon fromJ(J j) => GPolygon(
    [
      for (final p in j.list('pts')) [for (final v in (p as List)) (v as num).toDouble()],
    ],
    j.strOr('color'),
    j.strOrStrs('s'),
  );
}

class GRange {
  final double? from, to;
  final bool fromOpen, toOpen;
  final List<String> s;
  GRange(this.from, this.to, this.fromOpen, this.toOpen, this.s);
  static GRange fromJ(J j) => GRange(j.numOr('from'), j.numOr('to'), j.boolean('from_open', false), j.boolean('to_open', false), j.strOrStrs('s'));
}

class GJump {
  final double from, to;
  final String? label;
  GJump(this.from, this.to, this.label);
  static GJump fromJ(J j) => GJump(j.number('from'), j.number('to'), j.strOr('label'));
}

// ---------------------------------------------------------------- games
sealed class Game {
  final String id, type, title;
  final String? lesson;
  Game(J j) : id = j.str('id'), type = j.str('type'), title = j.str('title'), lesson = j.strOr('lesson');

  static Game fromJ(J j) => switch (j.str('type')) {
    'match' => MatchGame(j),
    'sort' => SortGame(j),
    'flash' => FlashGame(j),
    'tf' => TfGame(j),
    'fill' => FillGame(j),
    'label' => LabelGame(j),
    'wordmatch' => WordMatchGame(j),
    'form' => FormGame(j),
    'builder' => BuilderGame(j),
    final t => throw FormatException('${j.where}: unknown game type "$t"'),
  };
}

class MatchGame extends Game {
  final List<(String, String)> pairs;
  MatchGame(J j) : pairs = j.objs('pairs', (x) => (x.str('a'), x.str('b'))), super(j);
}

class SortGame extends Game {
  final List<(String id, String label)> groups;
  final List<(String text, String group)> items;
  SortGame(J j) : groups = j.objs('groups', (x) => (x.str('id'), x.str('label'))), items = j.objs('items', (x) => (x.str('text'), x.str('group'))), super(j);
}

class FlashGame extends Game {
  final List<(String front, String back)> cards;
  FlashGame(J j) : cards = j.objs('cards', (x) => (x.str('front'), x.str('back'))), super(j);
}

class TfGame extends Game {
  final int seconds;
  final List<TfItem> items;
  TfGame(J j) : seconds = j.integer('seconds'), items = j.objs('items', (x) => TfItem(x.str('text'), x.boolean('answer'), x.strOr('why'))), super(j);
}

class TfItem {
  final String text;
  final bool answer;
  final String? why;
  TfItem(this.text, this.answer, this.why);
}

class FillGame extends Game {
  final List<ChoiceItem> items;
  FillGame(J j) : items = j.objs('items', ChoiceItem.fromJ), super(j);
}

class FormGame extends Game {
  final List<ChoiceItem> items;
  FormGame(J j) : items = j.objs('items', ChoiceItem.fromJ), super(j);
}

class ChoiceItem {
  final String text, answer;
  final List<String> choices;
  final String? why;
  ChoiceItem(this.text, this.answer, this.choices, this.why);
  static ChoiceItem fromJ(J j) => ChoiceItem(j.str('text'), j.str('answer'), j.strs('choices'), j.strOr('why'));
}

class LabelGame extends Game {
  final String diagram;
  LabelGame(J j) : diagram = j.str('diagram'), super(j);
}

class WordMatchGame extends Game {
  final List<(String word, String meaning)> pairs;
  WordMatchGame(J j) : pairs = j.objs('pairs', (x) => (x.str('word'), x.str('meaning'))), super(j);
}

class BuilderGame extends Game {
  final List<BuilderItem> items;
  BuilderGame(J j) : items = j.objs('items', (x) => BuilderItem(x.strs('words'), x.strs('extra', optional: true), x.strOr('why'), x.strOr('hint'))), super(j);
}

class BuilderItem {
  final List<String> words, extra;
  final String? why, hint;
  BuilderItem(this.words, this.extra, this.why, this.hint);
}

// ---------------------------------------------------------------- exercise
class Exercise {
  final List<ExQuestion> questions;
  Exercise(this.questions);
  static Exercise fromJ(J j) => Exercise(j.objs('questions', ExQuestion.fromJ));
}

/// type: mcq | tf | fill (with choices) | short (typed answer, `accept` = other right answers)
class ExQuestion {
  final String id, type, q, tip;
  final int page;
  final Map<String, String> options;
  final String answer; // tf answers are stored as "true" / "false"
  final List<String> choices, accept, why;
  final List<(String q, String a)> similar;
  ExQuestion(this.id, this.type, this.page, this.q, this.options, this.answer, this.choices, this.accept, this.why, this.tip, this.similar);
  static ExQuestion fromJ(J j) {
    final type = j.str('type');
    if (!const ['mcq', 'tf', 'fill', 'short'].contains(type)) throw FormatException('${j.where}: unknown question type "$type"');
    final a = j.m['answer'];
    final answer = type == 'tf' ? (a is bool ? '$a' : throw FormatException('${j.where}.answer: tf answer must be bool')) : j.str('answer');
    return ExQuestion(
      j.str('id'),
      type,
      j.integer('page'),
      j.str('q'),
      j.strMap('options', optional: true),
      answer,
      j.strs('choices', optional: true),
      j.strs('accept', optional: true),
      j.strs('why'),
      j.str('tip'),
      j.objs('similar', (x) => (x.str('q'), x.str('a'))),
    );
  }

  /// graded questions (a wrong answer goes to My mistakes); "short" answers are self-checked
  bool get graded => type == 'mcq' || type == 'tf' || type == 'fill';
}
