import 'dart:math';

import 'package:aves/model/settings/settings.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Wraps a top-level page body and lets the user drag the page horizontally
/// to switch to the neighbouring bottom navigation item, PageView-style.
///
/// Uses raw pointer events (`Listener`) instead of drag `GestureDetector`s:
/// collection grids wrap their content in a `GestureDetector` claiming
/// horizontal drags (to keep them away from the scale recognizer), and an
/// inner drag recognizer always wins the gesture arena, so a plain
/// `GestureDetector` at page level never fires on grid pages.
///
/// The page follows the finger while dragging; on release it either
/// completes the switch (through the standard route transition) or
/// settles back to its original position.
class TabSwipeDetector extends StatefulWidget {
  final Widget child;

  const TabSwipeDetector({
    super.key,
    required this.child,
  });

  @override
  State<TabSwipeDetector> createState() => _TabSwipeDetectorState();
}

class _TabSwipeDetectorState extends State<TabSwipeDetector> with SingleTickerProviderStateMixin {
  static const double _touchSlop = 18;
  // leave the screen edge zones to the drawer and system back gestures
  static const double _edgeZone = 28;
  // slow starts are deliberate gestures (e.g. long-press then drag to multi-select), not page swipes
  static const int _maxClaimDelayMs = 400;
  static const double _commitDistanceRatio = 0.35;
  static const double _commitVelocity = 0.7; // logical px per ms
  static const Duration _settleDuration = Duration(milliseconds: 200);
  static const Duration _resetDelay = Duration(milliseconds: 450);

  final ValueNotifier<double> _dragOffset = ValueNotifier(0);
  AnimationController? _settleController;
  double _settleFrom = 0;

  int _pointerCount = 0;
  bool _multiTouch = false;
  // 0 = undecided, 1 = following the finger, -1 = rejected for this gesture
  int _claim = 0;
  // while following: -1 to go to the previous item, 1 to go to the next one
  int _direction = 0;
  Offset? _start;
  Duration _startTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    final controller = AnimationController(vsync: this, duration: _settleDuration);
    controller.addListener(() {
      final t = Curves.easeOutCubic.transform(controller.value);
      _dragOffset.value = _settleFrom * (1 - t);
    });
    _settleController = controller;
  }

  @override
  void dispose() {
    _settleController?.dispose();
    _dragOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: ValueListenableBuilder<double>(
        valueListenable: _dragOffset,
        builder: (context, dx, child) => Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _settleController?.stop();
    _pointerCount++;
    if (_pointerCount > 1) {
      // multi-touch, most likely a pinch to scale gesture
      _multiTouch = true;
      if (_claim == 1) _settleBack();
      _claim = -1;
      _start = null;
      return;
    }
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dx = event.position.dx;
    if (dx < _edgeZone || dx > screenWidth - _edgeZone) {
      // leave the edge zones to the drawer and system gestures
      _start = null;
      return;
    }
    _start = event.position;
    _startTime = event.timeStamp;
    _claim = 0;
    _direction = 0;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final start = _start;
    if (start == null || _multiTouch || _claim == -1) return;

    final delta = event.position - start;
    if (_claim == 0) {
      if (delta.distance < _touchSlop) return;
      if ((event.timeStamp - _startTime).inMilliseconds > _maxClaimDelayMs) {
        _claim = -1;
        return;
      }
      if (delta.dx.abs() <= delta.dy.abs()) {
        // mostly vertical gesture, leave it to scrolling and drag selection
        _claim = -1;
        return;
      }
      final direction = delta.dx < 0 ? 1 : -1;
      if (_neighbourIndex(direction) == -1) {
        _claim = -1;
        return;
      }
      _direction = direction;
      _claim = 1;
    }
    if (_claim == 1) {
      _dragOffset.value = delta.dx;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final wasFollowing = _claim == 1;
    final direction = _direction;
    final elapsedMs = (event.timeStamp - _startTime).inMilliseconds;
    _start = null;
    _claim = 0;
    _direction = 0;
    _pointerCount = max(0, _pointerCount - 1);
    if (_pointerCount == 0) _multiTouch = false;

    if (wasFollowing) {
      final width = MediaQuery.sizeOf(context).width;
      final dx = _dragOffset.value;
      final velocity = elapsedMs > 0 ? dx / elapsedMs : 0.0;
      if (dx.abs() >= width * _commitDistanceRatio || velocity.abs() >= _commitVelocity) {
        _goTo(context, direction);
        // hold the page aside while the route transition plays, then reset
        Future.delayed(_resetDelay, () {
          if (mounted && _claim == 0 && _dragOffset.value != 0) {
            _dragOffset.value = 0;
          }
        });
        return;
      }
    }
    if (_dragOffset.value != 0) _settleBack();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _start = null;
    _claim = 0;
    _direction = 0;
    _pointerCount = max(0, _pointerCount - 1);
    if (_pointerCount == 0) _multiTouch = false;
    if (_dragOffset.value != 0) _settleBack();
  }

  void _settleBack() {
    final from = _dragOffset.value;
    if (!mounted || from == 0) {
      _dragOffset.value = 0;
      return;
    }
    _settleFrom = from;
    _settleController!.forward(from: 0);
  }

  int _neighbourIndex(int direction) {
    final items = context.read<Settings>().bottomNavigationActions;
    if (items.length < 2) return -1;
    final currentRoute = context.currentRouteName;
    if (currentRoute == null) return -1;
    final index = items.indexWhere((item) => item.route == currentRoute);
    if (index < 0) return -1;
    final target = index + direction;
    if (target < 0 || target >= items.length) return -1;
    return target;
  }

  void _goTo(BuildContext context, int direction) {
    final target = _neighbourIndex(direction);
    if (target == -1) return;
    context.read<Settings>().bottomNavigationActions[target].goTo(context, topLevel: null);
  }
}
