import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/licensing/device_id.dart';
import '../../core/licensing/unlock_store.dart';
import '../scan/qr_scan_page.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key, this.onUnlocked});
  final VoidCallback? onUnlocked;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final controller = TextEditingController();
  String? deviceId;
  String? message;

  @override
  void initState() {
    super.initState();
    DeviceIdProvider.getId().then((id) {
      if (mounted) setState(() => deviceId = id);
    });
  }

  @override
  void dispose() {
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F0E5),
      appBar: AppBar(
        title: const Text('Bee Plus'),
        backgroundColor: const Color(0xFFF7F0E5),
        foregroundColor: const Color(0xFF3E3129),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Locked — show this Device ID to Bee Seller',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFFFFFAF2),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (deviceId != null)
                    QrImageView(data: deviceId!, size: 180, backgroundColor: Colors.white)
                  else
                    const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  SelectableText(deviceId ?? '…',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: deviceId == null
                        ? null
                        : () => Clipboard.setData(ClipboardData(text: deviceId!)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Unlock code from Bee Seller',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _apply,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEE7B5F)),
            child: const Text('Apply unlock'),
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
            label: const Text('Scan QR'),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(message!, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}
