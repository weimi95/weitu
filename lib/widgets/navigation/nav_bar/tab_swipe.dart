import 'package:aves/model/settings/settings.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Wraps a top-level page body and switches to the neighbouring
/// bottom navigation item on a horizontal fling gesture.
class TabSwipeDetector extends StatelessWidget {
  final Widget child;

  const TabSwipeDetector({
    super.key,
    required this.child,
  });

  static const double _minFlingVelocity = 400;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) => _onDragEnd(context, details),
      child: child,
    );
  }

  void _onDragEnd(BuildContext context, DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -_minFlingVelocity) {
      _goTo(context, 1);
    } else if (velocity > _minFlingVelocity) {
      _goTo(context, -1);
    }
  }

  void _goTo(BuildContext context, int offset) {
    final items = context.read<Settings>().bottomNavigationActions;
    if (items.length < 2) return;
    final currentRoute = context.currentRouteName;
    if (currentRoute == null) return;
    final index = items.indexWhere((item) => item.route == currentRoute);
    if (index < 0) return;
    final target = index + offset;
    if (target < 0 || target >= items.length) return;
    items[target].goTo(context, topLevel: null);
  }
}
