import 'package:flutter/material.dart';

/// The ProCheck logo: a checklist mark on a rounded, gradient-filled tile.
///
/// Used both in the [HomeScreen] app bar (small) and on the splash screen
/// (large) — just at different sizes.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.65)],
        ),
      ),
      child: Icon(
        Icons.checklist_rtl_rounded,
        color: scheme.onPrimary,
        size: size * 0.62,
      ),
    );
  }
}
