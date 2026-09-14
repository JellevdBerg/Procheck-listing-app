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

/// Wrap a screen's root widget with this so it fades and shrinks away
/// while a screen pushed on top of it (via [pushSlideIn]) slides in, and
/// reverses that when the screen on top is popped.
class DropAwayOnPush extends StatelessWidget {
  const DropAwayOnPush({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final secondaryAnimation = ModalRoute.of(context)?.secondaryAnimation;
    if (secondaryAnimation == null) return child;

    return AnimatedBuilder(
      animation: secondaryAnimation,
      child: child,
      builder: (context, child) {
        final t = secondaryAnimation.value;
        return Opacity(
          opacity: 1 - t,
          child: Transform.scale(scale: 1 - (t * 0.08), child: child),
        );
      },
    );
  }
}
