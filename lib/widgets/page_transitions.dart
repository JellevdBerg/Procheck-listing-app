import 'package:flutter/material.dart';

/// Pushes [page] with a slide-in-from-the-right transition, and lets the
/// screen underneath react via [DropAwayOnPush] (fading/shrinking away
/// while this one slides in). Pass [reduceMotion] to swap in a quick fade
/// instead, for users who'd rather skip the movement.
Future<T?> pushSlideIn<T>(
  BuildContext context,
  Widget page, {
  bool reduceMotion = false,
}) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: Duration(milliseconds: reduceMotion ? 120 : 320),
      reverseTransitionDuration: Duration(
        milliseconds: reduceMotion ? 100 : 260,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (reduceMotion) {
          return FadeTransition(opacity: animation, child: child);
        }
        final offset = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);
        return SlideTransition(position: offset, child: child);
      },
    ),
  );
}

/// Wrap a screen's root widget with this so it fades and sinks downward,
/// out of view, while a screen pushed on top of it (via [pushSlideIn])
/// slides in from the right — and reverses that when the screen on top is
/// popped, so returning to this screen feels like it rises back into place.
class DropAwayOnPush extends StatelessWidget {
  const DropAwayOnPush({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final secondaryAnimation = ModalRoute.of(context)?.secondaryAnimation;
    if (secondaryAnimation == null) return child;

    final curved = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeInCubic,
      reverseCurve: Curves.easeOutCubic,
    );
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) {
        final t = curved.value;
        return Opacity(
          opacity: 1 - t,
          child: Transform.translate(offset: Offset(0, t * 72), child: child),
        );
      },
    );
  }
}
