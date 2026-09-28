import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/licensing/unlock_store.dart';
import 'features/junior/junior_engine.dart';
import 'features/junior/junior_screen.dart';
import 'features/unlock/unlock_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Hive.initFlutter();
  await UnlockStore.instance.init();
  JuniorEngine.instance.preload();
  runApp(const BeePlusApp());
}

class BeePlusApp extends StatelessWidget {
  const BeePlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bee Plus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Nunito',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF5B8C63),
          secondary: Color(0xFFEE7B5F),
          surface: Color(0xFFFFFAF2),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F0E5),
      ),
      home: const _Gate(),
    );
  }
}

class _Gate extends StatefulWidget {
  const _Gate();
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  @override
  Widget build(BuildContext context) {
    if (!UnlockStore.instance.isUnlocked) {
      return UnlockScreen(onUnlocked: () => setState(() {}));
    }
    return const JuniorScreen();
  }
}
