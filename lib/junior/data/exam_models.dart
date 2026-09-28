// Typed models for the Grade 8 general-exam papers (content/<subject>_<year>_g8.json, High's per-paper schema).
import 'json_util.dart';

/// App subject ids used by the General Exam tab (same order and tones as the web app's SUBJECTS).
class ExamSubject {
  final String id, key, tone;
  final RegExp match;
  const ExamSubject._(this.id, this.key, this.tone, this.match);
  static final all = [
    ExamSubject._('english', 's_english', 'blue', RegExp(r'^english', caseSensitive: false)),
    ExamSubject._('science', 's_science', 'sage', RegExp(r'science', caseSensitive: false)),
    ExamSubject._('social', 's_social', 'peach', RegExp(r'social', caseSensitive: false)),
    ExamSubject._('citizenship', 's_citizenship', 'butter', RegExp(r'citizen|civic', caseSensitive: false)),
    ExamSubject._('maths', 's_maths', 'mint', RegExp(r'math', caseSensitive: false)),
  ];
  static ExamSubject? of(String subject) => all.where((s) => s.match.hasMatch(subject)).firstOrNull;
  static ExamSubject? byId(String id) => all.where((s) => s.id == id).firstOrNull;
}

class Paper {
  final ExamInfo exam;
  final List<ExamQuestion> questions;
  final List<Passage> passages;
  final String file;
  Paper(this.exam, this.questions, this.passages, this.file);
  factory Paper.fromJson(Object? o, String file) {
    final j = J(o, file);
    return Paper(ExamInfo.fromJ(j.obj('exam')), j.objs('questions', ExamQuestion.fromJ), j.objs('passages', Passage.fromJ, optional: true), file);
  }

  String get id => exam.id;
  ExamSubject? get subject => ExamSubject.of(exam.subject);
  int get yr => int.tryParse(exam.year.substring(0, exam.year.length.clamp(0, 4))) ?? 0;

  /// exam.version, else an id ending in -a/-b, else "Version A/B" in the title; null = the year's one unlettered paper
  String? get version {
    final v =
        exam.version ??
        RegExp(r'-([ab])$', caseSensitive: false).firstMatch(exam.id)?.group(1) ??
        RegExp(r'\bversion\s*([AB])\b', caseSensitive: false).firstMatch(exam.title)?.group(1);
    return (v == null || v.isEmpty) ? null : v.toUpperCase();
  }

  Passage? passage(String? id) => id == null ? null : passages.where((p) => p.id == id).firstOrNull;
}

class ExamInfo {
  final String id, year, subject, title, type;
  final String? version, duration;
  final int grade;
  final int? durationMinutes, totalPoints;
  final List<ExamPart> parts;
  ExamInfo(
    this.id,
    this.year,
    this.subject,
    this.grade,
    this.version,
    this.type,
    this.title,
    this.duration,
    this.durationMinutes,
    this.totalPoints,
    this.parts,
  );
  static ExamInfo fromJ(J j) => ExamInfo(
    j.str('id'),
    j.str('year'),
    j.str('subject'),
    j.integer('grade'),
    j.strOr('version'),
    j.str('type'),
    j.str('title'),
    j.strOr('duration'),
    j.intOr('duration_minutes'),
    j.intOr('total_points'),
    j.objs('parts', ExamPart.fromJ, optional: true),
  );
}

class ExamPart {
  final int part;
  final String title, questionType;
  final int? questionCount, points;
  final String? instructions;
  ExamPart(this.part, this.title, this.questionType, this.questionCount, this.points, this.instructions);
  static ExamPart fromJ(J j) =>
      ExamPart(j.integer('part'), j.str('title'), j.str('question_type'), j.intOr('question_count'), j.intOr('points'), j.strOr('instructions'));
}

class ExamQuestion {
  final String id, examId, type, stem, answer;
  final String? stemTex, passageId, image, imageAlt, section, explainSimple, reviewFlag;
  final int part, number, marks;
  final Map<String, String> options;
  final List<String> acceptedAnswers, explanationSteps, tips, topics;
  final List<SimilarQuestion> similar;
  final List<DataTable> stemTables;
  ExamQuestion(
    this.id,
    this.examId,
    this.part,
    this.number,
    this.type,
    this.marks,
    this.stem,
    this.stemTex,
    this.options,
    this.answer,
    this.acceptedAnswers,
    this.explanationSteps,
    this.explainSimple,
    this.tips,
    this.similar,
    this.topics,
    this.passageId,
    this.image,
    this.imageAlt,
    this.section,
    this.stemTables,
    this.reviewFlag,
  );
  static ExamQuestion fromJ(J j) => ExamQuestion(
    j.str('id'),
    j.str('exam_id'),
    j.integer('part'),
    j.integer('number'),
    j.str('type'),
    j.integer('marks'),
    j.str('stem'),
    j.strOr('stem_tex'),
    j.strMap('options', optional: true),
    j.str('answer'),
    j.strs('accepted_answers', optional: true),
    j.strs('explanation_steps', optional: true),
    j.strOr('explain_simple'),
    j.strs('tips', optional: true),
    j.objs('similar_questions', SimilarQuestion.fromJ, optional: true),
    j.strs('topics', optional: true),
    j.strOr('passage_id'),
    j.strOr('image'),
    j.strOr('image_alt'),
    j.strOr('section'),
    j.objs('stem_tables', DataTable.fromJ, optional: true),
    j.strOr('review_flag'),
  );

  bool get isMcq => type == 'mcq' && options.length > 1;
  List<String> get rightLetters => acceptedAnswers.isNotEmpty ? acceptedAnswers : [answer];
  bool isCorrect(String letter) => rightLetters.contains(letter);

  /// "Why?" shows explain_simple when present, else the explanation steps; only tips[0] is shown
  List<String> get why => explainSimple != null ? [explainSimple!] : explanationSteps;
}

class SimilarQuestion {
  final String stem, answer;
  final Map<String, String> options;
  final List<String> explanationSteps;
  SimilarQuestion(this.stem, this.options, this.answer, this.explanationSteps);
  static SimilarQuestion fromJ(J j) =>
      SimilarQuestion(j.str('stem'), j.strMap('options', optional: true), j.str('answer'), j.strs('explanation_steps', optional: true));
}

class Passage {
  final String id, kind, title;
  final String? instructions, note;
  final List<String> paragraphs;
  final List<int> questionNumbers;
  final int? part;
  final DataTable? table;
  Passage(this.id, this.kind, this.title, this.instructions, this.paragraphs, this.questionNumbers, this.part, this.table, this.note);
  static Passage fromJ(J j) => Passage(
    j.str('id'),
    j.str('kind'),
    j.str('title'),
    j.strOr('instructions'),
    j.strs('paragraphs'),
    [for (final n in j.list('question_numbers', optional: true)) (n as num).toInt()],
    j.intOr('part'),
    j.objOr('table') == null ? null : DataTable.fromJ(j.obj('table')),
    j.strOr('note'),
  );
}

class DataTable {
  final String? title, kind;
  final List<String> columns, align;
  final List<List<String>> rows;
  DataTable(this.title, this.kind, this.columns, this.rows, this.align);
  static DataTable fromJ(J j) => DataTable(j.strOr('title'), j.strOr('kind'), j.strs('columns'), [
    for (final r in j.list('rows')) [for (final c in (r as List)) c as String],
  ], j.strs('align', optional: true));
}
