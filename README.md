# Junior — native Flutter rebuild (milestones 1–3)

Offline Grade 6–8 study app ("Junior"): Grade 6–8 textbook notes and 26 Grade 8 general-exam papers. It is a **native Flutter**
rebuild of the web preview (`Junior-preview-latest.html`). There's no WebView and no HTML rendering: every screen is built from Flutter
widgets that recreate the web template's 3D clay design (cream background, pastel sage/peach/butter/powder-blue tiles, puffy raised cards, keys that press in).

Tested with **Flutter 3.47.5 / Dart 3.13.4**. The code itself needs Dart ≥ 3.8 (it uses null-aware elements and `_` wildcards).
The committed `pubspec.lock` resolves to packages that need Flutter ≥ 3.44.

## What's done

| Area | Status |
|---|---|
| Content | All JSON and SVG files are copied **unchanged** from `junior/app/content` into `assets/junior/content/` (26 papers / 1,300 questions; 21 books / 195 units / 6,058 cards / 1,272 games / 2,372 exercise questions / 960 diagrams) |
| Data | Typed, strict models (`lib/junior/data/`). Books are lazy-loaded one at a time and parsed off the UI thread (`Isolate.run`) |
| Design system | `ClayDecoration` reproduces the CSS outer and inset shadows. Also `Press` (pressed-in keys), `ClayButton` (primary / soft / danger / yes / no / ghost, disabled), `RoundButton`, `LangToggle`, `ClaySwitch`, `MiniBar`, `TagPill`, `NavBar`. Palette, radii, shadows and type come from the template CSS (light and dark) |
| M1 screens | Bottom-nav shell (Home · General Exam · My mistakes · Settings). Home (greeting, Continue card, grade cards). Grade page (collapsible subjects, unit rows with progress and "Soon"). Settings sheet (English/ትግርኛ, dark mode, start over) |
| M2 unit page | `screens/unit_page.dart`: one vertical scroll, sticky back bar and jump bar (Notes · Memory · Games · Questions; the key follows the section on screen). Unit head with progress, intro card, lessons with all 14 note-card types (`notes/cards.dart`), diagrams with pins, sliders and steps (`notes/diagram.dart`), graphs / number lines / coordinate planes, maths (`flutter_math_fork`), tables, glossary chips with a word sheet. Memory recap (tips, tricks, key words). All 9 game types played inline with Play buttons, stars and best score (`notes/games.dart`). Exercise questions with Check / Show answer, verdict, Why?, Tip, a similar question and a stars summary with Try again (`notes/exercise.dart`). Wrong answers go to My mistakes; the reading position is saved for Continue |
| M3 exams | `screens/exam_player.dart`: practice player (passage box, figure with zoom viewer, A–D options, Check, feedback with Why? and Tip, Next / See result), result page with stars (best stars per paper), Paper A / B page for years with two papers, Continue card on General Exam for an unfinished paper |
| M3 My mistakes | `screens/mistakes_page.dart`: exam mistakes per subject and notes-exercise mistakes per unit (marked "Notes: Science 8, Unit 1"), Practise, one-question-at-a-time retry for notes mistakes with its own result page; a right answer removes the mistake; badge count on the nav bar |
| Labels | `lib/junior/l10n/labels.dart` has 153 en/ti labels generated from the web template, including the user-approved Math = ቁጽሪ, Settings = መስተኻኸሊ and Life Skills = ምንባር ብ ጥበብ |

## Merging into an existing Flutter project

1. **Copy these folders** into the host project:
   - `lib/junior/` → `<host>/lib/junior/`. All imports inside it are relative, so it works under any package name.
   - `assets/junior/` → `<host>/assets/junior/`. This holds content (about 19 MB) and fonts (about 2.9 MB).
   - Optional: `test/` → `<host>/test/junior/`. Replace `package:junior/junior/` with `package:<host_package>/junior/` in the imports.
   - Optional: `tool/` → `<host>/tool/junior/`. These are the asset-sync and label/icon generators; adjust their relative paths.
2. **Add dependencies** to the host `pubspec.yaml`:
   ```yaml
   dependencies:
     flutter_svg: ^2.3.0
     flutter_math_fork: ^0.7.4       # maths rendering on the unit page
     shared_preferences: ^2.5.5
   ```
   Junior doesn't use Material. Keep `uses-material-design: true` if your host app needs it; Junior doesn't care either way.
3. **Add the asset and font entries** under the host's `flutter:` section. The whole block can be pasted as is. Flutter doesn't
   include subfolders automatically, so every SVG folder has to be listed:
   ```yaml
flutter:
  assets:
    - assets/junior/content/
    - assets/junior/content/exams/
    - assets/junior/content/notes/
    - assets/junior/content/media/
    - assets/junior/content/notes/svg/citizenship_6/
    - assets/junior/content/notes/svg/citizenship_7/
    - assets/junior/content/notes/svg/citizenship_8/
    - assets/junior/content/notes/svg/english_8/
    - assets/junior/content/notes/svg/ict_8/
    - assets/junior/content/notes/svg/life_skills_6/
    - assets/junior/content/notes/svg/life_skills_7/
    - assets/junior/content/notes/svg/life_skills_8/
    - assets/junior/content/notes/svg/mathematics_6/
    - assets/junior/content/notes/svg/mathematics_7/
    - assets/junior/content/notes/svg/mathematics_8/
    - assets/junior/content/notes/svg/science_6/
    - assets/junior/content/notes/svg/science_7/
    - assets/junior/content/notes/svg/science_8/
    - assets/junior/content/notes/svg/social_studies_6/
    - assets/junior/content/notes/svg/social_studies_7/
    - assets/junior/content/notes/svg/social_studies_8/
    - assets/junior/content/notes/svg/tigrigna_6/
    - assets/junior/content/notes/svg/tigrigna_7/
  fonts:
    - family: JuniorNunito
      fonts:
        - asset: assets/junior/fonts/Nunito-500.ttf
          weight: 500
        - asset: assets/junior/fonts/Nunito-600.ttf
          weight: 600
        - asset: assets/junior/fonts/Nunito-700.ttf
          weight: 700
        - asset: assets/junior/fonts/Nunito-800.ttf
          weight: 800
        - asset: assets/junior/fonts/Nunito-900.ttf
          weight: 900
        - asset: assets/junior/fonts/Nunito-Italic-700.ttf
          weight: 700
          style: italic
        - asset: assets/junior/fonts/Nunito-Italic-800.ttf
          weight: 800
          style: italic
    - family: JuniorNunito1000
      fonts:
        - asset: assets/junior/fonts/Nunito-1000.ttf
          weight: 900
    - family: JuniorEthiopic
      fonts:
        - asset: assets/junior/fonts/NotoSansEthiopic-500.ttf
          weight: 500
        - asset: assets/junior/fonts/NotoSansEthiopic-600.ttf
          weight: 600
        - asset: assets/junior/fonts/NotoSansEthiopic-700.ttf
          weight: 700
        - asset: assets/junior/fonts/NotoSansEthiopic-800.ttf
          weight: 800
        - asset: assets/junior/fonts/NotoSansEthiopic-900.ttf
          weight: 900
   ```
   The font families are namespaced (`JuniorNunito`, `JuniorNunito1000`, `JuniorEthiopic`) so they can't clash with the host's fonts.
   Ge'ez text uses Noto Sans Ethiopic (OFL) and Latin text uses Nunito (OFL). Both are static weight instances cut from the web app's own variable fonts.
4. **Mount Junior.** Pick one:
   - **Embedded as a route** (the usual choice when merging):
     ```dart
     import 'junior/junior.dart';

     final junior = await Junior.init();   // loads index + manifest + saved progress; cached, safe to call again
     Navigator.of(context).push(PageRouteBuilder(pageBuilder: (_, _, _) => JuniorScreen(state: junior)));
     ```
     `JuniorScreen` has its own inner navigator, bottom nav, sheet and back handling. System back on Junior's Home tab pops the host route.
     `test/embed_test.dart` checks this.
   - **Standalone app:** `runApp(JuniorApp(state: await Junior.init()));`. See `lib/main.dart`, which you can delete when merging.
5. **Android:** nothing special is needed. `android/` in this zip is only a reference config (applicationId `er.junior.app`,
   label "Junior"). Keep your host's own `android/` folder.

### Namespacing and avoiding clashes
- **Persistence:** everything Junior saves goes into one SharedPreferences key, **`junior:v1`**. It's a JSON record with the same shape
  as the web app's localStorage record (progress, stars, mistakes, continue position, language, dark mode). Junior never reads or writes other keys.
  "Start over" in Settings clears progress inside this record and keeps the language and dark-mode choices.
- **Assets:** everything lives under `assets/junior/…`. The loader base path is `ContentRepo.base` in `lib/junior/data/repository.dart`.
- **Fonts:** the `Junior*` families listed above.
- **Code:** everything is under `lib/junior/`. The public API is `lib/junior/junior.dart` (`Junior.init`, `JuniorScreen`, `JuniorApp`, `AppState`, `ContentRepo`).
- **State:** Junior's state is a plain `ChangeNotifier` (`AppState`) provided by its own `InheritedNotifier` (`AppScope`). It doesn't need provider or riverpod, so it won't interfere with the host's state management.
  Per-session widget state (a card's step, a running game, answers not yet checked) lives in `NotesSession` (`lib/junior/notes/session.dart`) and is cleared by "Start over".
- **Navigation:** Junior has its own inner `Navigator` per tab inside `Shell` (`lib/junior/screens/shell.dart`). `Shell.of(context).push / pop / replace`,
  `openTab(tab)` and `resetTo(tab, [pages])` (a new page stack on a tab, like the web app's `STACK.length = 0`). Pages that mix in `NoNavPage`
  (unit page, exam player, result pages, notes retry) hide the bottom nav bar. None of this touches the host's navigator.

## Updating content or labels
- Content: run `tool/sync_assets.sh [path/to/junior/app/content]`. It copies the files unchanged and rewrites `assets/junior/content/index.json`.
- Labels: run `python3 tool/gen_labels.py` to regenerate `lib/junior/l10n/labels.dart` from the web template's LABELS table.
- Icons and illustrations: run `python3 tool/gen_art.py` to regenerate `lib/junior/widgets/art_data.dart`.

## Tests
```
flutter analyze                                   # clean
flutter test                                      # everything (all_units_test takes ~15 min on one core)
flutter test test/all_units_test.dart --total-shards 3 --shard-index 0   # …1, …2: run the 195 units in parallel shards
```
- `content_parse_test.dart`: every paper, question, book, unit, card, game and exercise question parses. Counts match the raw JSON, and every image, SVG and passage reference resolves.
- `all_units_test.dart`: one test per unit (195). The unit page renders every note card, the memory recap, every game and every question with
  no exception (layout overflow included). Every game is started with its Play button and played to the end (with a wrong try where the game allows one),
  and every question is answered and checked. Wrong answers must be in My mistakes and the questions summary must be saved.
- `all_papers_test.dart`: one test per paper (26). The paper opens (through its Paper A / B page when the year has two), is stopped half-way,
  resumes from the Continue card at the same question, and every question is answered to the result page (score, stars, best). Its wrong answers are then
  retried from My mistakes until none are left. Every A / B year page lists its papers.
- `screenshots_test.dart`: renders the M1 screens (en, ti, light, dark) and the M2/M3 scenes (unit top, games, a started game, questions, exam player,
  result, My mistakes, notes retry; en and ti) at 390×844 @2x with the real fonts, into `compare/flutter/`.
- `embed_test.dart`: Junior mounts inside a host navigator, back returns to the host, and the host's prefs keys are left alone.

Side-by-side comparisons with the web preview: `python3 tool/shoot_web.py` and `python3 tool/shoot_web_m2.py` (Playwright, into `compare/web/`),
`flutter test test/screenshots_test.dart`, then `python3 tool/compose_compare.py` (writes `compare/<name>.png`, web left and Flutter right).
Game shuffles use `shuffleRandom` (`notes/session.dart`), which the screenshots seed with the same mulberry32 as the web shooter, so both show the same order.

## Next milestone
- **M4:** polish and performance profiling (60 fps on low-end devices), icon and splash, accessibility, release signing handover.
