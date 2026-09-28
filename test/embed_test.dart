// Junior mounted inside a host app: push JuniorScreen as a route, system back on Junior's Home pops back to the host.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junior/junior/junior.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('JuniorScreen embeds in a host navigator', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'host:other': 1});
    final repo = ContentRepo(useIsolate: false);
    late AppState state;
    await tester.runAsync(() async {
      await repo.init();
      state = AppState(repo, await SharedPreferences.getInstance());
    });
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        pageRouteBuilder: <T>(s, b) => PageRouteBuilder<T>(settings: s, pageBuilder: (c, _, _) => b(c)),
        home: Builder(
          builder: (context) => GestureDetector(
            onTap: () => Navigator.of(context).push(PageRouteBuilder(pageBuilder: (_, _, _) => JuniorScreen(state: state))),
            child: const Text('HOST', textDirection: TextDirection.ltr),
          ),
        ),
      ),
    );
    await tester.tap(find.text('HOST'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a grade'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Pick a grade'), findsNothing);
    expect(find.text('HOST'), findsOneWidget);
    // Junior's own data lives under a single namespaced key and never touches the host's keys
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('host:other'), 1);
  });
}
