import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/licensing/device_id.dart';
import '../../core/licensing/unlock_store.dart';
import '../junior/junior_engine.dart';
import '../scan/qr_scan_page.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key, this.onUnlocked});
  final VoidCallback? onUnlocked;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen>
    with SingleTickerProviderStateMixin {
  final controller = TextEditingController();
  String? deviceId;
  String? message;
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    DeviceIdProvider.getId().then((id) {
      if (mounted) setState(() => deviceId = id);
    });
    JuniorEngine.instance.preload();
  }

  @override
  void dispose() {
    _spin.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final r = await UnlockStore.instance.applyPayload(controller.text.trim());
    setState(() => message = r.isOk ? r.value : r.error);
    if (r.isOk) widget.onUnlocked?.call();
  }

  @override
  Widget build(BuildContext context) {
    final engine = JuniorEngine.instance;
    return Stack(
      children: [
        if (engine.controller != null)
          Offstage(
            offstage: true,
            child: SizedBox(
              width: 1,
              height: 1,
              child: WebViewWidget(controller: engine.controller!),
            ),
          ),
        Scaffold(
          backgroundColor: const Color(0xFF1A120C),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A1A12), Color(0xFF1A120C), Color(0xFF3A2218)],
              ),
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  const Text(
                    'ንብ ፓሉስ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFFC9A3),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'BEE PLUS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 40,
                      letterSpacing: 2,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Grade 6–8  ·  Offline  ·  Tigrinya + English',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFFE7D4),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  AnimatedBuilder(
                    animation: _spin,
                    builder: (context, child) {
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0014)
                          ..rotateX(-0.18)
                          ..rotateY(0.10 * math.sin(_spin.value * math.pi * 2)),
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFFF6EC),
                            Color(0xFFFFD7B8),
                            Color(0xFFEE7B5F),
                          ],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x88EE7B5F),
                            blurRadius: 40,
                            offset: Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Your classroom in one tap',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Color(0xFF3E3129),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _Pill(text: '2012–2019 papers'),
                              _Pill(text: 'Notes + diagrams'),
                              _Pill(text: 'ትግርኛ'),
                              _Pill(text: 'Works offline'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              children: [
                                if (deviceId != null)
                                  QrImageView(
                                    data: deviceId!,
                                    size: 168,
                                    backgroundColor: Colors.white,
                                  )
                                else
                                  const SizedBox(
                                    height: 168,
                                    child: Center(
                                        child: CircularProgressIndicator()),
                                  ),
                                const SizedBox(height: 6),
                                SelectableText(
                                  deviceId ?? '…',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: deviceId == null
                                      ? null
                                      : () => Clipboard.setData(
                                            ClipboardData(text: deviceId!),
                                          ),
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text('Copy Device ID'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Show this QR to Bee Seller. One scan. Unlocked forever.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3E3129),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Already have a code?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Paste Bee Seller code',
                      hintStyle: TextStyle(color: Color(0x99FFE7D4)),
                      filled: true,
                      fillColor: Color(0x33FFFFFF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEE7B5F),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text('Unlock Bee Plus',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => QrScanPage(
                          title: 'Scan Bee Seller QR',
                          onScan: (code) async {
                            controller.text = code;
                            await _apply();
                          },
                        ),
                      ));
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan seller QR'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFC9A3),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF3E3129),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFE7D4),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
