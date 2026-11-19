import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// A single-line badge. Overflowing labels loop continuously right to left.
/// Reduced-motion users can scroll the label manually instead.
class ScrollingBadge extends StatelessWidget {
  const ScrollingBadge({required this.label, required this.style, super.key});
  final String label;
  final FBadgeStyle style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final padding = style.contentStyle.padding.resolve(
        Directionality.of(context),
      );
      final textStyle = style.contentStyle.labelTextStyle;
      final painter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final textWidth = painter.width.ceilToDouble();
      final height = painter.height.ceilToDouble();
      painter.dispose();
      final width = math.min(
        textWidth + padding.horizontal,
        constraints.maxWidth,
      );
      final viewport = math.max(0.0, width - padding.horizontal);
      return Align(
        alignment: AlignmentDirectional.topEnd,
        child: SizedBox(
          width: width,
          height: height + padding.vertical,
          child: FBadge.raw(
            style: style,
            builder: (_, _) => SizedBox(
              width: width,
              height: height + padding.vertical,
              child: Padding(
                padding: padding,
                child: Semantics(
                  label: label,
                  child: ExcludeSemantics(
                    child: _ScrollingLabel(
                      label: label,
                      style: textStyle,
                      width: textWidth,
                      height: height,
                      gap: context.theme.style.pagePadding.horizontal,
                      distance: math.max(0.0, textWidth - viewport),
                      reduceMotion: MediaQuery.disableAnimationsOf(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ScrollingLabel extends StatefulWidget {
  const _ScrollingLabel({
    required this.label,
    required this.style,
    required this.width,
    required this.height,
    required this.gap,
    required this.distance,
    required this.reduceMotion,
  });
  final String label;
  final TextStyle style;
  final double width;
  final double height;
  final double gap;
  final double distance;
  final bool reduceMotion;
  @override
  State<_ScrollingLabel> createState() => _ScrollingLabelState();
}

class _ScrollingLabelState extends State<_ScrollingLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant _ScrollingLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label ||
        oldWidget.distance != widget.distance ||
        oldWidget.gap != widget.gap ||
        oldWidget.reduceMotion != widget.reduceMotion) {
      _restart();
    }
  }

  void _restart() {
    _controller.stop();
    _controller.value = 0;
    // Keep the same reading speed when text scaling changes the label width.
    _controller.duration = Duration(
      milliseconds: ((widget.width + widget.gap) * 35).round(),
    );
    if (widget.distance > 0 && !widget.reduceMotion) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = SizedBox(
      width: widget.width,
      height: widget.height,
      child: Text(
        widget.label,
        style: widget.style,
        maxLines: 1,
        softWrap: false,
      ),
    );
    if (widget.distance <= 0) return text;
    if (widget.reduceMotion) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: text,
      );
    }
    final period = widget.width + widget.gap;
    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        child: OverflowBox(
          alignment: AlignmentDirectional.centerStart,
          minWidth: period + widget.width,
          maxWidth: period + widget.width,
          child: SizedBox(
            width: period + widget.width,
            height: widget.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(left: 0, top: 0, child: text),
                Positioned(
                  left: period,
                  top: 0,
                  child: SizedBox(
                    width: widget.width,
                    height: widget.height,
                    child: RichText(
                      text: TextSpan(
                        text: widget.label,
                        style: DefaultTextStyle.of(
                          context,
                        ).style.merge(widget.style),
                      ),
                      textScaler: MediaQuery.textScalerOf(context),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        builder: (_, child) => Transform.translate(
          offset: Offset(-period * _controller.value, 0),
          child: child,
        ),
      ),
    );
  }
}
