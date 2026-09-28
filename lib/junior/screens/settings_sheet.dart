// Settings bottom sheet (`settingsSheet` in the web app): language, dark screen, start over, close.
import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import '../widgets/clay_widgets.dart';
import 'shell.dart';
import '../widgets/tx.dart';

/// scrim (rgba(40,28,20,.38), .25s) + sheet sliding up with the spring (.45s)
class SheetHost extends StatelessWidget {
  const SheetHost({super.key, required this.controller, required this.onClose, required this.child});
  final AnimationController controller;
  final VoidCallback onClose;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final v = controller.value;
      if (v <= 0) return const SizedBox.shrink();
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onClose,
              child: ColoredBox(color: Color.fromRGBO(40, 28, 20, .38 * v.clamp(0.0, 1.0))),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionalTranslation(
              translation: Offset(0, 1 - v),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .92),
                child: child,
              ),
            ),
          ),
        ],
      );
    },
  );
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});
  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  bool confirming = false;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context), p = k.p, s = k.s;
    Widget seg(String l, String name) {
      final on = s.lang == l;
      return Expanded(
        child: Press(
          onTap: () => s.setLang(l),
          selected: on,
          deco: k.c.key(radius: 22),
          pressedDeco: k.c.keyOn(radius: 22),
          dy: 4,
          child: SizedBox(
            height: 60,
            child: Center(child: Tx(name, style: ts(20, FontWeight.w900, on ? p.sage.deep : p.ink, normal: true))),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: k.c.sheet(),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(22, 12, 22, 26 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 6,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: withA(p.ink2, .3), borderRadius: BorderRadius.circular(9)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 14),
              child: Tx(k.t('settings'), textAlign: TextAlign.center, style: ts(28, FontWeight.w900, p.ink)),
            ),
            // language
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                spacing: 10,
                children: [
                  k.icon('lang', size: 28, color: p.ink),
                  Tx(k.t('language'), style: ts(19, FontWeight.w900, p.ink)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4 + 20),
              child: Row(spacing: 12, children: [seg('en', 'English'), seg('ti', 'ትግርኛ')]),
            ),
            // dark screen
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Press(
                onTap: () => s.setDark(!s.dark),
                deco: k.c.puffy(radius: R.md),
                scale: .96,
                spring: true,
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: Row(
                          spacing: 10,
                          children: [
                            k.icon('moon', size: 28, color: p.ink),
                            Flexible(child: Tx(k.t('darkMode'), style: ts(20, FontWeight.w900, p.ink, normal: true))),
                          ],
                        ),
                      ),
                      ClaySwitch(s.dark),
                    ],
                  ),
                ),
              ),
            ),
            // start over
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: confirming
                  ? DecoratedBox(
                      decoration: k.c.puffy(c: p.peach.tile, d: p.peach.deep, radius: 28),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Tx(k.t('sure'), style: ts(22, FontWeight.w900, p.peach.deep)),
                            ),
                            Row(
                              spacing: 12,
                              children: [
                                Expanded(
                                  child: ClayButton(
                                    label: k.t('yesDelete'),
                                    kind: BtnKind.danger,
                                    onTap: () {
                                      s.resetAll();
                                      setState(() => confirming = false);
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: ClayButton(label: k.t('no'), kind: BtnKind.soft, onTap: () => setState(() => confirming = false)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClayButton(label: k.t('startOver'), icon: 'trash', kind: BtnKind.soft, onTap: () => setState(() => confirming = true)),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Tx(k.t('startOverSub'), textAlign: TextAlign.center, style: ts(17, FontWeight.w700, p.ink2)),
                        ),
                      ],
                    ),
            ),
            ClayButton(label: k.t('close'), onTap: () => Shell.of(context).closeSettings()),
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Tx(
                'Developed by Shamm Tesfalem 07162947',
                textAlign: TextAlign.center,
                style: ts(15, FontWeight.w800, p.ink2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
