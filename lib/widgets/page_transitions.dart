import 'package:flutter/material.dart';

/// Pushes [page] with a slide-in-from-the-right transition, and lets the
/// screen underneath react via [DropAwayOnPush] (fading/shrinking away
/// while this one slides in).
Future<T?> pushSlideIn<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
