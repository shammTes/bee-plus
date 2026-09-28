// Notes subjects: label key, art and tone (NSUBJ / NORDER in the web app).
class NotesSubject {
  final String key, art, tone;
  const NotesSubject(this.key, this.art, this.tone);
}

const kNotesSubjects = {
  'science': NotesSubject('s_science', 'science', 'sage'),
  'mathematics': NotesSubject('s_maths', 'maths', 'mint'),
  'english': NotesSubject('s_english', 'english', 'blue'),
  'social_studies': NotesSubject('s_social', 'social', 'peach'),
  'citizenship': NotesSubject('s_citizenship', 'citizenship', 'butter'),
  'ict': NotesSubject('s_ict', 'ict', 'lilac'),
  'life_skills': NotesSubject('s_life', 'life', 'mint'),
  'tigrigna': NotesSubject('s_tigrigna', 'tigrigna', 'butter'),
};

const kNotesOrder = ['science', 'mathematics', 'english', 'social_studies', 'citizenship', 'ict', 'life_skills', 'tigrigna'];

NotesSubject notesSubject(String s) => kNotesSubjects[s] ?? NotesSubject(s, 'logo', 'sage');

/// grade card tones on Home
String gradeTone(int g) => g == 8
    ? 'sage'
    : g == 7
    ? 'blue'
    : 'peach';
