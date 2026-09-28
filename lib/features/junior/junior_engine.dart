import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class JuniorEngine {
  JuniorEngine._();
  static final JuniorEngine instance = JuniorEngine._();

  static const asset = 'assets/junior/index.html';

  WebViewController? controller;
  String? error;
  final ValueNotifier<bool> loading = ValueNotifier(true);

  Future<void> preload() async {
    if (controller != null) return;
    try {
      final c = WebViewController();
      await c.setJavaScriptMode(JavaScriptMode.unrestricted);
      await c.setBackgroundColor(const Color(0xFFF7F0E5));
      await c.enableZoom(false);
      await c.setUserAgent('Mozilla/5.0 (Linux; Android 14) JuniorApp BeePlus');
      c.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => loading.value = false,
          onWebResourceError: (e) {
            error = e.description;
            loading.value = false;
          },
        ),
      );
      await c.loadFlutterAsset(asset);
      controller = c;
    } catch (e) {
      error = '$e';
      loading.value = false;
    }
  }

  Future<bool> handleBack() async {
    final c = controller;
    if (c == null) return false;
    try {
      final raw = await c.runJavaScriptReturningResult(
        'window.APP && window.APP.back ? window.APP.back() : false',
      );
      return '$raw'.toLowerCase().contains('true');
    } catch (_) {
      return false;
    }
  }
}
