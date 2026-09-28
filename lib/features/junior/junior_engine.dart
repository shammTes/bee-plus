import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class JuniorEngine {
  JuniorEngine._();
  static final JuniorEngine instance = JuniorEngine._();

  static const asset = 'assets/junior/index.html';

  WebViewController? controller;
  String? error;
  final ValueNotifier<bool> loading = ValueNotifier(true);
  bool _injecting = false;

  Future<void> preload() async {
    if (controller != null) return;
    try {
      late final WebViewController c;
      if (WebViewPlatform.instance is AndroidWebViewPlatform) {
        c = WebViewController.fromPlatformCreationParams(
          AndroidWebViewControllerCreationParams(),
        );
        final android = c.platform as AndroidWebViewController;
        await android.setMediaPlaybackRequiresUserGesture(false);
        await android.setTextZoom(100);
      } else {
        c = WebViewController();
      }
      await c.setJavaScriptMode(JavaScriptMode.unrestricted);
      await c.setBackgroundColor(const Color(0xFFF7F0E5));
      await c.enableZoom(false);
      await c.setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; wv) AppleWebKit/537.36 JuniorApp BeePlus',
      );
      c.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            loading.value = false;
            _fitPage();
          },
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

  Future<void> applySafeInsets(EdgeInsets pad) async {
    final c = controller;
    if (c == null) return;
    final top = pad.top.ceil();
    final bottom = pad.bottom.ceil();
    await c.runJavaScript('''
(function(){
  var m = document.querySelector('meta[name=viewport]');
  if (!m) {
    m = document.createElement('meta');
    m.name = 'viewport';
    document.head.appendChild(m);
  }
  m.setAttribute('content',
    'width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover');
  document.documentElement.style.setProperty('--sat', '${top}px');
  document.documentElement.style.setProperty('--sab', '${bottom}px');
  document.documentElement.style.height = '100%';
  document.body.style.margin = '0';
  document.body.style.minHeight = '100%';
  document.body.style.paddingTop = 'var(--sat)';
  document.body.style.paddingBottom = 'var(--sab)';
  document.body.style.overflowX = 'hidden';
  if (window.dispatchEvent) window.dispatchEvent(new Event('resize'));
})();
''');
  }

  Future<void> _fitPage() async {
    if (_injecting) return;
    _injecting = true;
    try {
      await applySafeInsets(const EdgeInsets.only(top: 28, bottom: 16));
    } catch (_) {}
    _injecting = false;
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
