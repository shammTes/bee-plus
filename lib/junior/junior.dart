/// Junior: offline Grade 6-8 notes + Grade 8 exams, native clay UI.
///
/// Public API for host apps: `Junior.init()` → [AppState], then mount [JuniorApp] (standalone) or push [JuniorScreen] (embedded).
library;

import 'data/repository.dart';
import 'state/app_state.dart';

export 'app.dart' show JuniorApp, JuniorScreen;
export 'state/app_state.dart' show AppState;
export 'data/repository.dart' show ContentRepo;

abstract final class Junior {
  static Future<AppState>? _boot;

  /// Loads the content index + manifest and the saved progress (SharedPreferences key `junior:v1`). Safe to call repeatedly.
  static Future<AppState> init() => _boot ??= () async {
    final repo = ContentRepo();
    final state = AppState(repo);
    await Future.wait([repo.init(), state.load()]);
    return state;
  }();
}
