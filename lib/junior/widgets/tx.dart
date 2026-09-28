import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Text with a CSS-like strut (see [strutOf]); use instead of Text everywhere.
class Tx extends StatelessWidget {
  const Tx(this.data, {super.key, required this.style, this.textAlign, this.maxLines, this.overflow, this.softWrap});
  final String data;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  @override
  Widget build(BuildContext context) =>
      Text(data, style: style, strutStyle: strutOf(style), textAlign: textAlign, maxLines: maxLines, overflow: overflow, softWrap: softWrap);
}
