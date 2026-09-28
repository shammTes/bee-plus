import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'junior_engine.dart';

class JuniorScreen extends StatefulWidget {
  const JuniorScreen({super.key});

  @override
  State<JuniorScreen> createState() => _JuniorScreenState();
}

class _JuniorScreenState extends State<JuniorScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    JuniorEngine.instance.preload();
  }

  @override
  Widget build(BuildContext context) {
    final engine = JuniorEngine.instance;
    final pad = MediaQuery.paddingOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      engine.applySafeInsets(pad);
    });
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFFF7F0E5),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final handled = await engine.handleBack();
          if (!handled && context.mounted) SystemNavigator.pop();
        },
        child: ColoredBox(
          color: const Color(0xFFF7F0E5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (engine.controller != null)
                WebViewWidget(controller: engine.controller!),
              ValueListenableBuilder<bool>(
                valueListenable: engine.loading,
                builder: (context, loading, _) {
                  if (engine.error != null && engine.controller == null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Bee Plus failed to open.\n${engine.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  if (!loading) return const SizedBox.shrink();
                  return const ColoredBox(
                    color: Color(0xFFF7F0E5),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFFEE7B5F)),
                          SizedBox(height: 12),
                          Text('Opening Bee Plus…',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
