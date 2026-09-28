import 'package:flutter/widgets.dart';

import 'screens/shell.dart';
import 'state/app_state.dart';
import 'theme/tokens.dart';

/// Standalone root widget. Uses WidgetsApp (no Material) so nothing but the clay design system paints the UI.
class JuniorApp extends StatelessWidget {
  const JuniorApp({super.key, required this.state, this.home});
  final AppState state;
  final Widget? home;

  @override
  Widget build(BuildContext context) => AppScope(
    state: state,
    child: Builder(
      builder: (context) {
        final s = AppScope.of(context);
        final p = s.dark ? Palette.darkP : Palette.light;
        return WidgetsApp(
          title: 'Junior',
          color: p.primary,
          debugShowCheckedModeBanner: false,
          locale: Locale(s.lang == 'ti' ? 'ti' : 'en'),
          textStyle: ts(18, FontWeight.w700, p.ink),
          builder: (context, _) => JuniorFrame(child: home ?? const Shell()),
        );
      },
    ),
  );
}

/// Text defaults shared by the standalone app and the embedded screen.
class JuniorFrame extends StatelessWidget {
  const JuniorFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).dark ? Palette.darkP : Palette.light;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: DefaultTextStyle(style: ts(18, FontWeight.w700, p.ink), child: child),
    );
  }
}

/// Embeddable entry: push this as a full-screen route inside an existing (Material/Cupertino/Widgets) app.
/// Junior keeps its own inner navigator, bottom nav and back handling; back on its Home tab pops this route.
///
///     final junior = await Junior.init();            // once, e.g. in main() or lazily before the first push
///     Navigator.of(context).push(PageRouteBuilder(pageBuilder: (_, _, _) => JuniorScreen(state: junior)));
class JuniorScreen extends StatelessWidget {
  const JuniorScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final host = Navigator.of(context);
    return AppScope(
      state: state,
      child: JuniorFrame(child: Shell(onExit: () => host.pop())),
    );
  }
}
