import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../junior/theme/styles.dart';
import '../junior/theme/tokens.dart';
import 'unlock_store.dart';

/// First-run gate. Stays up until a Bee Seller JUNIOR code matches this device.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.unlock, required this.onUnlocked});
  final UnlockStore unlock;
  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  final _code = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _tilt;
  String? _id;
  String? _message;
  bool _busy = false;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _tilt = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();
    widget.unlock.deviceId().then((id) {
      if (mounted) setState(() => _id = id);
    });
  }

  @override
  void dispose() {
    _tilt.dispose();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _apply(String raw) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final r = await widget.unlock.applyPayload(raw);
    if (!mounted) return;
    if (r.isOk) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _busy = false;
      _message = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_scanning) {
      return _ScanLayer(
        onClose: () => setState(() => _scanning = false),
        onCode: (code) {
          _code.text = code;
          setState(() => _scanning = false);
          _apply(code);
        },
      );
    }
    final p = Palette.light;
    final clay = Clay(p);
    final pad = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: const Color(0xFF1A120C),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A1A12), Color(0xFF1A120C), Color(0xFF3A2218)],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, pad.top + 18, 20, pad.bottom + 28),
          children: [
            Text('Bee Plus', textAlign: TextAlign.center, style: ts(18, FontWeight.w900, const Color(0xFFFFC9A3))),
            const SizedBox(height: 4),
            Text(
              'BEE PLUS',
              textAlign: TextAlign.center,
              style: ts(40, FontWeight.w900, white, height: 1).copyWith(letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            Text(
              'Grade 6–8  ·  Offline  ·  Notes and exams',
              textAlign: TextAlign.center,
              style: ts(15, FontWeight.w700, const Color(0xFFFFE7D4)),
            ),
            const SizedBox(height: 22),
            AnimatedBuilder(
              animation: _tilt,
              builder: (context, child) {
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateX(-0.16)
                    ..rotateY(0.08 * math.sin(_tilt.value * math.pi * 2)),
                  child: child,
                );
              },
              child: DecoratedBox(
                decoration: clay.puffy(c: p.peach.tile, d: p.peach.deep, radius: 32),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    children: [
                      Text('Your classroom, locked in', textAlign: TextAlign.center, style: ts(18, FontWeight.w900, p.ink)),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          _Pill('2012–2019 papers'),
                          _Pill('Notes'),
                          _Pill('Works offline'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DecoratedBox(
                        decoration: clay.puffy(c: white, d: const Color(0xFFD9CBBA), radius: 22),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              if (_id == null)
                                const SizedBox(width: 168, height: 168)
                              else
                                QrImageView(
                                  data: _id!,
                                  size: 168,
                                  backgroundColor: white,
                                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF3E3129)),
                                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF3E3129)),
                                ),
                              const SizedBox(height: 6),
                              SelectableText(_id ?? '…', textAlign: TextAlign.center, style: ts(13, FontWeight.w800, p.ink)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Show this QR to Bee Seller. One scan unlocks this phone forever.',
                        textAlign: TextAlign.center,
                        style: ts(14, FontWeight.w700, p.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text('Already have a code?', style: ts(16, FontWeight.w900, white)),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: EditableText(
                  controller: _code,
                  focusNode: _focus,
                  style: ts(15, FontWeight.w700, white),
                  cursorColor: p.primary,
                  backgroundCursorColor: p.peach.tile,
                  maxLines: 3,
                  minLines: 2,
                  keyboardType: TextInputType.text,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _Btn(label: _busy ? 'Checking…' : 'Unlock Bee Plus', onTap: _busy ? null : () => _apply(_code.text)),
            const SizedBox(height: 8),
            _Btn(label: 'Scan seller QR', filled: false, onTap: _busy ? null : () => setState(() => _scanning = true)),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, textAlign: TextAlign.center, style: ts(14, FontWeight.w800, const Color(0xFFFFC9A3))),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xFF3E3129), borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(text, style: ts(12, FontWeight.w800, const Color(0xFFFFE7D4))),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, required this.onTap, this.filled = true});
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    final bg = filled ? const Color(0xFFC24E32) : const Color(0xFFFFFCF7);
    final fg = filled ? white : const Color(0xFF3E3129);
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: Center(child: Text(label, style: ts(16, FontWeight.w900, fg))),
        ),
      ),
    );
  }
}

class _ScanLayer extends StatefulWidget {
  const _ScanLayer({required this.onClose, required this.onCode});
  final VoidCallback onClose;
  final ValueChanged<String> onCode;
  @override
  State<_ScanLayer> createState() => _ScanLayerState();
}

class _ScanLayerState extends State<_ScanLayer> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: black,
      child: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_done) return;
              final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().where((s) => s.contains('BEE1|')).firstOrNull;
              if (raw == null) return;
              _done = true;
              widget.onCode(raw);
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            top: top + 12,
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onClose,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: white, borderRadius: BorderRadius.circular(999)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text('Back', style: ts(15, FontWeight.w900, const Color(0xFF3E3129))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Scan the Bee Seller unlock QR', style: ts(15, FontWeight.w800, white))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
