import 'package:flutter/material.dart' show ThemeExtension;
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Homework status tokens. Light mode preserves the original yellow and green;
/// dark mode uses their lighter counterparts for legibility.
class HomeworkPalette extends ThemeExtension<HomeworkPalette> {
  const HomeworkPalette({required this.yellow, required this.green});

  factory HomeworkPalette.forBrightness(Brightness brightness) =>
      brightness == Brightness.dark
      ? const HomeworkPalette(
          yellow: Color(0xFFFACC15),
          green: Color(0xFF4ADE80),
        )
      : const HomeworkPalette(
          yellow: Color(0xFFA16207),
          green: Color(0xFF15803D),
        );

  final Color yellow;
  final Color green;

  @override
  HomeworkPalette copyWith({Color? yellow, Color? green}) => HomeworkPalette(
    yellow: yellow ?? this.yellow,
    green: green ?? this.green,
  );

  @override
  HomeworkPalette lerp(covariant HomeworkPalette? other, double t) =>
      other == null
      ? this
      : HomeworkPalette(
          yellow: Color.lerp(yellow, other.yellow, t)!,
          green: Color.lerp(green, other.green, t)!,
        );
}

FThemeData withHomeworkTheme(FThemeData theme) => theme.copyWith(
  extensions: {
    ...theme.extensions.where((extension) => extension is! HomeworkPalette),
    HomeworkPalette.forBrightness(theme.colors.brightness),
  },
);
