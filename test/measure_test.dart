// Dumps text boxes of a Flutter screen (for comparing positions with tool/measure_web.py). MEASURE=home|grade8|settings|exams LANG=en|ti
import 'dart:convert';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junior/junior/app.dart';
import 'package:junior/junior/data/repository.dart';
import 'package:junior/junior/screens/grade_page.dart';
import 'package:junior/junior/screens/shell.dart';
import 'package:junior/junior/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screenshots_test.dart' show loadFonts;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final scr = Platform.environment['MEASURE'] ?? 'home', lang = Platform.environment['LANG_UI'] ?? 'en';
  testWidgets('measure $scr $lang', (tester) async {
    await loadFonts();
    final repo = ContentRepo(useIsolate: false);
    await tester.runAsync(() async {
      await repo.init();
      await repo.booksOfGrade(8);
      await repo.papers();
    });
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    SharedPreferences.setMockInitialValues({});
    final state = AppState(repo, await SharedPreferences.getInstance())..lang = lang;
    await tester.pumpWidget(
      JuniorApp(
        state: state,
        home: Shell(
          initialTab: scr == 'exams' ? AppTab.exams : AppTab.home,
          initialRoutes: scr == 'grade8' ? const [GradePage(grade: 8)] : const [],
          settingsOpen: scr == 'settings',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final out = [];
    for (final e in find.byType(RichText).evaluate()) {
      final ro = e.renderObject as RenderParagraph;
      final r = MatrixUtils.transformRect(ro.getTransformTo(null), Offset.zero & ro.size);
      if (r.bottom < 0 || r.top > 844) continue;
      out.add([ro.text.toPlainText().trim(), (r.left * 10).round() / 10, (r.top * 10).round() / 10, (r.height * 10).round() / 10]);
    }
    File(Platform.environment['MEASURE_OUT'] ?? 'build/measure_flutter.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(out));
  }, skip: !Platform.environment.containsKey('MEASURE')); // dev tool: only runs when MEASURE is set
}
