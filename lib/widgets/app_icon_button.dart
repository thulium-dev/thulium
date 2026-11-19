import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// A quiet Forui action with a consistent target, tooltip, and accessible name.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.label,
    required this.icon,
    required this.onPress,
    this.size,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPress;
  final double? size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size ?? context.theme.style.sizes.tile,
    child: FTooltip(
      tipBuilder: (_, _) => Text(label),
      child: FButton.icon(
        variant: FButtonVariant.ghost,
        semanticsLabel: label,
        onPress: onPress,
        child: Icon(icon, size: 20),
      ),
    ),
  );
}
