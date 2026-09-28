// App shell: phone background, one Navigator for the current tab, the floating clay nav bar and the settings sheet.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import '../widgets/clay_widgets.dart';
import 'exams_page.dart';
import 'home_page.dart';
import 'mistakes_page.dart';
import 'settings_sheet.dart';
import '../widgets/tx.dart';

enum AppTab { home, exams, mistakes }

class Shell extends StatefulWidget {
  const Shell({super.key, this.initialTab = AppTab.home, this.initialRoutes = const [], this.settingsOpen = false, this.onExit});
  final AppTab initialTab;

  /// extra pages pushed on start (used by screenshot tests, e.g. the Grade 8 page)
  final List<Widget> initialRoutes;
  final bool settingsOpen;

  /// Called when system back is pressed on the Home tab. Null = close the app (standalone). When Junior is embedded in a host
  /// app, JuniorScreen passes a callback that pops the host route instead.
  final VoidCallback? onExit;
  static ShellState of(BuildContext c) => c.findAncestorStateOfType<ShellState>()!;
  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> with TickerProviderStateMixin {
  late AppTab tab = widget.initialTab;
  var _nav = GlobalKey<NavigatorState>(); // a new Navigator per tab switch (the web app resets the stack on a tab tap)
  late List<Widget> _initial = widget.initialRoutes;
  late _NavObs _obs = _NavObs(this);
  bool _hideNav = false; // the current page has no nav bar (unit page, practice, result …)
  late final AnimationController _gsheet = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  Widget? _gsheetChild;
  late final AnimationController _sheet = AnimationController(vsync: this, duration: const Duration(milliseconds: 450), value: widget.settingsOpen ? 1 : 0);
  bool get settingsOpen => _sheet.value > 0 && _sheet.status != AnimationStatus.reverse;

  String _toastMsg = '';
  bool _toastOn = false;
  Timer? _toastT;
  void toast(String msg) {
    _toastT?.cancel();
    setState(() {
      _toastMsg = msg;
      _toastOn = true;
    });
    _toastT = Timer(const Duration(seconds: 2), () => mounted ? setState(() => _toastOn = false) : null);
  }

  @override
  void dispose() {
    _toastT?.cancel();
    _sheet.dispose();
    _gsheet.dispose();
    super.dispose();
  }

  void openTab(AppTab t) => resetTo(t, const []);

  /// new page stack on tab [t]: the tab's root page, then [pages] (the web app's `STACK.length = 0; …`)
  void resetTo(AppTab t, List<Widget> pages) {
    setState(() {
      tab = t;
      _initial = pages;
      _nav = GlobalKey<NavigatorState>();
      _obs = _NavObs(this);
      _hideNav = _wantHide = pages.isNotEmpty && pages.last is NoNavPage;
    });
  }

  /// the page on top wants no nav bar (pages marked with [NoNavPage])
  bool _wantHide = false;
  void _topChanged(Route<dynamic>? r) {
    // the latest top route wins (initial routes are pushed root first, in one go)
    _wantHide = r is PageRoute && r.settings.arguments == _noNav;
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _wantHide != _hideNav) setState(() => _hideNav = _wantHide);
      });
    }
  }

  void push(Widget page) => _nav.currentState!.push(enterRoute(page));

  /// replace the page on top (practice -> result)
  void replace(Widget page) => _nav.currentState!.pushReplacement(enterRoute(page));

  /// bottom sheet above everything (glossary word)
  void showSheet(Widget child) {
    setState(() => _gsheetChild = child);
    _gsheet.animateTo(1, curve: springCurve);
  }

  void closeSheet() => _gsheet.animateBack(0, duration: const Duration(milliseconds: 260), curve: Curves.easeIn);
  bool get sheetOpen => _gsheet.value > 0 && _gsheet.status != AnimationStatus.reverse;
  void pop() => _nav.currentState!.maybePop();

  void openSettings() => _sheet.animateTo(1, curve: springCurve);
  void closeSettings() => _sheet.animateBack(0, duration: const Duration(milliseconds: 260), curve: Curves.easeIn);

  /// system back: sheet → page stack → Home tab → close the app (same order as the web app's APP.back())
  Future<void> _back() async {
    if (settingsOpen) return closeSettings();
    if (sheetOpen) return closeSheet();
    if (await _nav.currentState!.maybePop()) return;
    if (tab != AppTab.home) return openTab(AppTab.home);
    final exit = widget.onExit;
    exit != null ? exit() : SystemNavigator.pop();
  }

  Widget _root() => switch (tab) {
    AppTab.home => const HomePage(),
    AppTab.exams => const ExamsPage(),
    AppTab.mistakes => const MistakesPage(),
  };

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: p.dark ? SystemUiOverlayStyle.light.copyWith(statusBarColor: transparent) : SystemUiOverlayStyle.dark.copyWith(statusBarColor: transparent),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: p.phone, stops: [0, p.dark ? .5 : .45, 1]),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: SafeArea(
                  bottom: false,
                  child: HeroControllerScope.none(
                    child: Navigator(
                      key: _nav,
                      observers: [_obs],
                      onGenerateInitialRoutes: (nav, _) => [
                        enterRoute(_root(), animate: false),
                        for (final r in _initial) enterRoute(r, animate: false),
                      ],
                    ),
                  ),
                ),
              ),
              if (!_hideNav)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14 + bottomInset,
                  child: NavBar(on: tab),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 110 + bottomInset,
                child: IgnorePointer(
                  child: AnimatedSlide(
                    offset: _toastOn ? Offset.zero : const Offset(0, .35),
                    duration: const Duration(milliseconds: 300),
                    child: AnimatedOpacity(
                      opacity: _toastOn ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                          decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(999)),
                          child: Tx(_toastMsg, style: ts(18, FontWeight.w900, p.bg, height: 1.2)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: SheetHost(controller: _sheet, onClose: closeSettings, child: const SettingsSheet()),
              ),
              Positioned.fill(
                child: SheetHost(controller: _gsheet, onClose: closeSheet, child: _gsheetChild ?? const SizedBox.shrink()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _noNav = 'noNav';

/// a page shown without the nav bar (the web views that return no `nav`: unit page, practice, result …)
mixin NoNavPage on Widget {}

class _NavObs extends NavigatorObserver {
  _NavObs(this.shell);
  final ShellState shell;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => shell._topChanged(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => shell._topChanged(previousRoute);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => shell._topChanged(previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => shell._topChanged(newRoute);
}

/// the web "enter" animation (.42s, fade + 12px rise); the page below is hidden at once, as when the web app re-renders
Route<void> enterRoute(Widget page, {bool animate = true}) => PageRouteBuilder<void>(
  settings: RouteSettings(arguments: page is NoNavPage ? _noNav : null),
  transitionDuration: animate ? const Duration(milliseconds: 420) : Duration.zero,
  reverseTransitionDuration: const Duration(milliseconds: 260),
  opaque: false,
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (context, a, sa, child) {
    final c = CurvedAnimation(parent: a, curve: const Cubic(.2, .8, .2, 1));
    return FadeTransition(
      opacity: sa.drive(Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: const Threshold(.001)))),
      child: FadeTransition(
        opacity: c,
        child: AnimatedBuilder(
          animation: c,
          child: child,
          builder: (_, ch) => Transform.translate(offset: Offset(0, 12 * (1 - c.value)), child: ch),
        ),
      ),
    );
  },
);

/// `.nav`: raised clay bar with four raised keys; the current one pressed in (sage)
class NavBar extends StatelessWidget {
  const NavBar({super.key, required this.on});
  final AppTab on;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, sh = Shell.of(context);
    final n = k.s.mistakeCount;
    Widget item(double w, String icon, String label, bool selected, VoidCallback tap, {int badge = 0}) => SizedBox(
      width: w,
      child: Press(
        onTap: tap,
        selected: selected,
        deco: k.c.navKey(),
        pressedDeco: k.c.navKeyOn(),
        dy: 4,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), // Chrome's default <button> padding
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60), // min-height:62px, grows when a label wraps
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  k.icon(icon, size: 28, color: selected ? p.sage.deep : p.ink2),
                  Tx(label, textAlign: TextAlign.center, maxLines: 2, style: ts(14.5, FontWeight.w900, selected ? p.sage.deep : p.ink2, height: 1.1)),
                ],
              ),
              if (badge > 0)
                Positioned(
                  top: 6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(19, 0),
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        height: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: k.c.dot(),
                        child: Align(widthFactor: 1, child: Tx('$badge', style: ts(13, FontWeight.w900, p.onPrimary, height: 1))),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return DecoratedBox(
      decoration: k.c.puffy(radius: 32),
      child: SizedBox(
        height: 84,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
          child: LayoutBuilder(
            builder: (context, box) {
              final labels = [k.t('home'), k.t('generalExam'), k.t('mistakes'), k.t('settings')];
              final w = navWidths(box.maxWidth - 18, [for (final l in labels) _minContent(l, ts(14.5, FontWeight.w900, p.ink, height: 1.1)) + 12]);
              return Row(
                spacing: 6,
                children: [
                  item(w[0], 'home', labels[0], on == AppTab.home, () => sh.openTab(AppTab.home)),
                  item(w[1], 'exam', labels[1], on == AppTab.exams, () => sh.openTab(AppTab.exams)),
                  item(w[2], 'retry', labels[2], on == AppTab.mistakes, () => sh.openTab(AppTab.mistakes), badge: n),
                  item(w[3], 'gear', labels[3], false, sh.openSettings),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// min-content width of a label (its longest unbreakable word), like CSS
double _minContent(String label, TextStyle style) {
  var m = 28.0; // the icon
  for (final word in label.split(' ')) {
    final tp = TextPainter(
      text: TextSpan(text: word, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    if (tp.width > m) m = tp.width;
    tp.dispose();
  }
  return m;
}

/// CSS `flex:1` (basis 0) with `min-width:auto`: equal shares, but no item narrower than its min-content.
List<double> navWidths(double total, List<double> mins) {
  final sum = mins.fold(0.0, (a, b) => a + b);
  if (sum >= total) return [for (final m in mins) m * total / sum]; // huge text scale: never overflow the bar
  final w = List<double?>.filled(mins.length, null);
  while (true) {
    final free = [
      for (var i = 0; i < w.length; i++)
        if (w[i] == null) i,
    ];
    if (free.isEmpty) break;
    final used = [for (final x in w) ?x].fold(0.0, (a, b) => a + b);
    final share = (total - used) / free.length;
    final tooSmall = free.where((i) => mins[i] > share).toList();
    if (tooSmall.isEmpty) {
      for (final i in free) {
        w[i] = share;
      }
      break;
    }
    for (final i in tooSmall) {
      w[i] = mins[i];
    }
  }
  return [for (final x in w) x!];
}
