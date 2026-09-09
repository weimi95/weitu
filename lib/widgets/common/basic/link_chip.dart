import 'package:aves/theme/icons.dart';
import 'package:aves/widgets/aves_app.dart';
import 'package:flutter/material.dart';

class LinkChip extends StatelessWidget {
  final Widget? leading;
  final String text;
  final String? urlString;
  final Color? color;
  final TextStyle? textStyle;
  final VoidCallback? onTap;
  final int? maxLines;
  final bool softWrap;

  static const borderRadius = BorderRadius.all(Radius.circular(8));

  const LinkChip({
    super.key,
    this.leading,
    required this.text,
    this.urlString,
    this.color,
    this.textStyle,
    this.onTap,
    this.maxLines = 1,
    this.softWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: (textStyle ?? const TextStyle()).copyWith(color: color),
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap ?? () => AvesApp.launchUrl(urlString),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: .min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  text,
                  softWrap: softWrap,
                  overflow: TextOverflow.fade,
                  maxLines: maxLines,
                ),
              ),
              const SizedBox(width: 8),
              Builder(
                builder: (context) => Icon(
                  AIcons.openOutside,
                  size: DefaultTextStyle.of(context).style.fontSize,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
