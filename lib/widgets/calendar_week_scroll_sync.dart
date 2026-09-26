import 'package:flutter/widgets.dart';

/// Keeps the visible hour aligned while calendar weeks are paged in and out.
///
/// PageView may detach an offscreen week's ScrollPosition. When that week is
/// rebuilt, its old controller must receive the shared offset at attachment,
/// before the first layout/paint. A post-frame jump would briefly show its
/// stale scroll offset during the page transition.
final class CalendarWeekScrollSync {
  CalendarWeekScrollSync({required double initialOffset})
    : _offset = initialOffset;

  final _controllers = <int, ScrollController>{};
  double _offset;

  ScrollController controllerForWeek(int week) =>
      _controllers.putIfAbsent(week, () {
        late final ScrollController controller;
        controller = ScrollController(
          initialScrollOffset: _offset,
          keepScrollOffset: false,
          onAttach: (position) => position.correctPixels(_offset),
        )..addListener(() => _syncFrom(week, controller));
        return controller;
      });

  void _syncFrom(int sourceWeek, ScrollController source) {
    if (!source.hasClients || !source.position.hasContentDimensions) return;
    _offset = source.offset;
    for (final entry in _controllers.entries) {
      if (entry.key == sourceWeek || !entry.value.hasClients) continue;
      final position = entry.value.position;
      if (!position.hasContentDimensions) continue;
      final target = _offset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - target).abs() > 0.5) {
        entry.value.jumpTo(target);
      }
    }
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
  }
}
