import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'junior/junior.dart';
import 'junior/state/app_state.dart';
import 'junior/theme/tokens.dart';
import 'licensing/lock_screen.dart';
import 'licensing/unlock_store.dart';

/// Bee Plus. Locked until Bee Seller issues a JUNIOR code for this phone.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final unlock = UnlockStore();
  await unlock.init();
  runApp(BeePlusRoot(unlock: unlock));
}

class BeePlusRoot extends StatefulWidget {
  const BeePlusRoot({super.key, required this.unlock});
  final UnlockStore unlock;

  @override
  State<BeePlusRoot> createState() => _BeePlusRootState();
}

class _BeePlusRootState extends State<BeePlusRoot> {
  AppState? _junior;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    if (widget.unlock.isUnlocked) _open();
  }

  Future<void> _open() async {
    if (_opening || _junior != null) return;
    setState(() => _opening = true);
    final state = await Junior.init();
    if (!mounted) return;
    setState(() => _junior = state);
  }

  @override
  Widget build(BuildContext context) {
    final junior = _junior;
    if (junior != null) return JuniorApp(state: junior);
    if (_opening) {
      return WidgetsApp(
        title: 'Bee Plus',
        color: Palette.light.primary,
        debugShowCheckedModeBanner: false,
        builder: (_, _) => const ColoredBox(
          color: Color(0xFF1A120C),
          child: Center(child: Text('Opening Bee Plus…', style: TextStyle(color: Color(0xFFFFE7D4), fontWeight: FontWeight.w800))),
        ),
      );
    }
    return WidgetsApp(
      title: 'Bee Plus',
      color: Palette.light.primary,
      debugShowCheckedModeBanner: false,
      builder: (_, _) => LockScreen(unlock: widget.unlock, onUnlocked: _open),
    );
  }
}
