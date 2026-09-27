// ignore_for_file: constant_identifier_names

import 'package:flutter/widgets.dart';

/// Pages between calendar weeks with an interactive horizontal transition.
final class CalendarWeekPager extends StatefulWidget {
  const CalendarWeekPager({
    required this.weekCount,
    required this.initialWeek,
    required this.onWeekChanged,
    required this.itemBuilder,
    this.scrollEnabled = true,
    super.key,
  });

  final int weekCount;
  final int initialWeek;
  final ValueChanged<int> onWeekChanged;
  final Widget Function(BuildContext context, int week) itemBuilder;
  final bool scrollEnabled;

  @override
  State<CalendarWeekPager> createState() => CalendarWeekPagerState();
}

final class CalendarWeekPagerState extends State<CalendarWeekPager> {
  static const _BUTTON_TRANSITION_DURATION = Duration(milliseconds: 300);

  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialWeek - 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Animates arrow-button navigation through the same pages used by swipes.
  void animateBy(int delta) {
    if (!_controller.hasClients) return;
    final currentPage = _controller.page?.round() ?? widget.initialWeek - 1;
    final targetPage = (currentPage + delta).clamp(0, widget.weekCount - 1);
    if (targetPage == currentPage) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(targetPage);
    } else {
      _controller.animateToPage(
        targetPage,
        duration: _BUTTON_TRANSITION_DURATION,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => PageView.builder(
    controller: _controller,
    physics: widget.scrollEnabled ? null : const NeverScrollableScrollPhysics(),
    itemCount: widget.weekCount,
    onPageChanged: (index) => widget.onWeekChanged(index + 1),
    itemBuilder: (context, index) => widget.itemBuilder(context, index + 1),
  );
}
