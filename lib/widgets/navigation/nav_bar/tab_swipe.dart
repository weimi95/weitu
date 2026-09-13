import 'dart:math';

import 'package:aves/model/settings/settings.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Wraps a top-level page body and switches to the neighbouring
/// bottom navigation item on a horizontal swipe gesture.
///
/// Uses raw pointer events (`Listener`) instead of a drag `GestureDetector`:
/// collection grids wrap their content in a `GestureDetector` claiming
/// horizontal drags (to keep them away from the scale recognizer), and an
/// inner drag recognizer always wins the gesture arena, so a plain
/// `GestureDetector` at page level never fires on grid pages.
class TabSwipeDetector extends StatefulWidget {
  final Widget child;

  const TabSwipeDetector({
    super.key,
    required this.child,
  });

  @override
  State<TabSwipeDetector> createState() => _TabSwipeDetectorState();
}

class _TabSwipeDetectorState extends State<TabSwipeDetector> {
  static const double _minSwipeDistance = 80;
  static const int _maxSwipeDurationMs = 600;
  // leave the screen edge zones to the drawer and system back gestures
  static const double _edgeZone = 28;

  int _pointerCount = 0;
  Offset? _start;
  Duration _startTime = Duration.zero;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerCount++;
    if (_pointerCount > 1) {
      // multi-touch, most likely a pinch to scale gesture
      _start = null;
      return;
    }
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dx = event.position.dx;
    if (dx < _edgeZone || dx > screenWidth - _edgeZone) return;
    _start = event.position;
    _startTime = event.timeStamp;
  }

  void _onPointerUp(PointerUpEvent event) {
    final isSinglePointer = _pointerCount == 1;
    _pointerCount = max(0, _pointerCount - 1);
    final start = _start;
    _start = null;
    if (!isSinglePointer || start == null) return;

    final delta = event.position - start;
    final elapsedMs = (event.timeStamp - _startTime).inMilliseconds;
    if (elapsedMs <= 0 || elapsedMs > _maxSwipeDurationMs) return;
    if (delta.dx.abs() < _minSwipeDistance) return;
    // reject mostly vertical gestures (scrolling, drag to multi-select)
    if (delta.dx.abs() < delta.dy.abs()) return;
    _goTo(context, delta.dx < 0 ? 1 : -1);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerCount = max(0, _pointerCount - 1);
    _start = null;
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
