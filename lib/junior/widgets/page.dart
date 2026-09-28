// Page scaffold matching the web layout: fixed top bar (min 76, padding 14 20 6) + scrolling screen (padding 6 20, bottom 124 above the nav).
import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import 'art.dart';
import 'clay_widgets.dart';
import 'tx.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 76),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, spacing: 12, children: children),
    ),
  );
}

/// `<h1>` of the top bar (24px/900), optional leading art
class TopTitle extends StatelessWidget {
  const TopTitle(this.text, {super.key, this.logo = false});
  final String text;
  final bool logo;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Expanded(
      child: Row(
        spacing: 10,
        children: [
          if (logo) ArtIcon('logo', size: 44, palette: k.p),
          Flexible(
            child: Tx(text, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, style: ts(24, FontWeight.w900, k.p.ink, height: 1.15)),
          ),
        ],
      ),
    );
  }
}

/// back button + title (`backTop`)
class BackTop extends StatelessWidget {
  const BackTop(this.title, {super.key, required this.onBack});
  final String title;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return TopBar(
      children: [
        RoundButton(icon: 'back', onTap: onBack, label: k.t('back')),
        TopTitle(title),
      ],
    );
  }
}

/// bottom padding of the scrolling screen when the nav bar floats over it
const kNavPad = 124.0;

class ScreenScroll extends StatelessWidget {
  const ScreenScroll({super.key, required this.children, this.controller, this.bottom = kNavPad});
  final List<Widget> children;
  final ScrollController? controller;
  final double bottom;
  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: const NoGlow(),
    child: ListView(controller: controller, padding: EdgeInsets.fromLTRB(20, 6, 20, bottom + MediaQuery.paddingOf(context).bottom), children: children),
  );
}

class NoGlow extends ScrollBehavior {
  const NoGlow();
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

class PageShell extends StatelessWidget {
  const PageShell({super.key, required this.top, required this.body});
  final Widget top;
  final Widget body;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      top,
      Expanded(child: body),
    ],
  );
}

/// h2.title (30px/900) and h3.title (26px/900)
Tx h2(String s, Color c) => Tx(s, style: ts(30, FontWeight.w900, c, height: 1.15, spacing: -.3));
Tx h3(String s, Color c) => Tx(s, style: ts(26, FontWeight.w900, c, height: 1.2));
Tx lead(String s, Color c) => Tx(s, style: ts(19, FontWeight.w700, c));
