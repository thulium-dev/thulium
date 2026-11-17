import 'package:flutter/widgets.dart';

/// A short, directional response to navigation, shared by all pushed pages.
/// Reduced motion removes both the transition and the loading crossfade.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required BuildContext context,
    required WidgetBuilder builder,
    super.settings,
  }) : super(
         transitionDuration: MediaQuery.disableAnimationsOf(context)
             ? Duration.zero
             : const Duration(milliseconds: 200),
         reverseTransitionDuration: MediaQuery.disableAnimationsOf(context)
             ? Duration.zero
             : const Duration(milliseconds: 160),
         pageBuilder: (context, _, _) => builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final direction = Directionality.of(context) == TextDirection.rtl
               ? -1.0
               : 1.0;
           final curve = animation.drive(
             CurveTween(curve: Curves.easeOutCubic),
           );
           return FadeTransition(
             opacity: curve,
             child: SlideTransition(
               position: curve.drive(
                 Tween(begin: Offset(0.025 * direction, 0), end: Offset.zero),
               ),
               child: child,
             ),
           );
         },
       );
}
