// ignore_for_file: constant_identifier_names

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Converts a vertical two-finger span into a bounded calendar scale.
abstract final class CalendarZoomGeometry {
  static const _HOURS_PER_DAY = 24;
  static const _MIN_READABLE_HOUR_HEIGHT = 20.0;
  static const _MAX_HOUR_HEIGHT = 180.0;

  /// The full 24-hour grid must cover at least the scrollable viewport.
  static double minimumHourHeight(double viewportHeight) =>
      math.max(_MIN_READABLE_HOUR_HEIGHT, viewportHeight / _HOURS_PER_DAY);

  static double maximumHourHeight(double viewportHeight) =>
      math.max(_MAX_HOUR_HEIGHT, minimumHourHeight(viewportHeight) * 2);

  /// Keeps the time underneath the fingers at the same screen coordinate.
  static ({double hourHeight, double offset}) zoom({
    required double initialHourHeight,
    required double initialOffset,
    required double initialFocalY,
    required double currentFocalY,
    required double initialSpan,
    required double currentSpan,
    required double viewportHeight,
  }) {
    final minimum = minimumHourHeight(viewportHeight);
    final hourHeight = (initialHourHeight * currentSpan / initialSpan).clamp(
      minimum,
      maximumHourHeight(viewportHeight),
    );
    final focalHour = (initialOffset + initialFocalY) / initialHourHeight;
    final maxOffset = math.max(
      0.0,
      _HOURS_PER_DAY * hourHeight - viewportHeight,
    );
    final offset = (focalHour * hourHeight - currentFocalY).clamp(
      0.0,
      maxOffset,
    );
    return (hourHeight: hourHeight, offset: offset);
  }
}

/// Tracks two raw pointers without joining the gesture arena.
///
/// A scale recognizer also accepts one-finger movement and would steal the
/// existing vertical scroll or horizontal week swipe. Raw pointer tracking
/// leaves those gestures untouched and enables zoom only with two fingers.
final class CalendarVerticalPinchRegion extends StatefulWidget {
  const CalendarVerticalPinchRegion({
    required this.hourHeight,
    required this.scrollOffset,
    required this.viewportHeight,
    required this.onPinchChanged,
    required this.onPinchingChanged,
    required this.child,
    super.key,
  });

  final double hourHeight;
  final double scrollOffset;
  final double viewportHeight;
  final void Function(double hourHeight, double scrollOffset) onPinchChanged;
  final ValueChanged<bool> onPinchingChanged;
  final Widget child;

  @override
  State<CalendarVerticalPinchRegion> createState() =>
      _CalendarVerticalPinchRegionState();
}

final class _CalendarVerticalPinchRegionState
    extends State<CalendarVerticalPinchRegion> {
  static const _MIN_START_SPAN = 24.0;

  final _pointers = <int, Offset>{};
  double? _startSpan;
  double _startHourHeight = 0;
  double _startOffset = 0;
  double _startFocalY = 0;

  void _beginIfReady() {
    if (_pointers.length != 2 || _startSpan != null) return;
    final points = _pointers.values.toList(growable: false);
    final span = (points[0].dy - points[1].dy).abs();
    if (span < _MIN_START_SPAN) return;
    _startSpan = span;
    _startHourHeight = widget.hourHeight;
    _startOffset = widget.scrollOffset;
    _startFocalY = (points[0].dy + points[1].dy) / 2;
  }

  void _down(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2) {
      _beginIfReady();
      widget.onPinchingChanged(true);
    } else if (_pointers.length > 2) {
      // A new pair must establish its own baseline after any finger leaves.
      _startSpan = null;
    }
  }

  void _move(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length != 2) return;
    _beginIfReady();
    final initialSpan = _startSpan;
    if (initialSpan == null) return;
    final points = _pointers.values.toList(growable: false);
    final span = (points[0].dy - points[1].dy).abs();
    if (span < _MIN_START_SPAN) return;
    final result = CalendarZoomGeometry.zoom(
      initialHourHeight: _startHourHeight,
      initialOffset: _startOffset,
      initialFocalY: _startFocalY,
      currentFocalY: (points[0].dy + points[1].dy) / 2,
      initialSpan: initialSpan,
      currentSpan: span,
      viewportHeight: widget.viewportHeight,
    );
    if ((result.hourHeight - widget.hourHeight).abs() > 0.05) {
      widget.onPinchChanged(result.hourHeight, result.offset);
    }
  }

  void _end(int pointer) {
    _pointers.remove(pointer);
    _startSpan = null;
    if (_pointers.length == 2) _beginIfReady();
    if (_pointers.length < 2) widget.onPinchingChanged(false);
  }

  @override
  Widget build(BuildContext context) => Listener(
    key: const ValueKey('calendar-pinch-region'),
    behavior: HitTestBehavior.translucent,
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: (event) => _end(event.pointer),
    onPointerCancel: (event) => _end(event.pointer),
    child: widget.child,
  );
}
