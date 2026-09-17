import 'package:flutter/material.dart';

import '../../models/task_priority.dart';
import '../../theme/nocturne_theme.dart';

/// The design system's three button voices: `.btn-primary` (accent
/// outline), `.btn-secondary` (neutral outline), `.btn-ghost` (no border,
/// accent text).
enum NocturneButtonVariant { primary, secondary, ghost }

/// An outlined icon+label button matching the Nocturne `.btn` classes —
/// primary actions are never solid-filled in this design system.
class NocturneButton extends StatelessWidget {
  const NocturneButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = NocturneButtonVariant.secondary,
    this.color,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final NocturneButtonVariant variant;

  /// Overrides the accent color this button uses (e.g. a project's own
  /// color for its "New task" button). Defaults to the theme's accent.
  final Color? color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    final accent = color ?? context.nocturneAccent;

    final (Color fg, Color? border, Color? bg) = switch (variant) {
      NocturneButtonVariant.primary => (
        accent,
        accent,
        accent.withValues(alpha: 0.12),
      ),
      NocturneButtonVariant.secondary => (tokens.text, tokens.divider, null),
      NocturneButtonVariant.ghost => (accent, null, null),
    };

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: dense ? 13 : 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    return Material(
      color: bg ?? Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NocturneRadius.md),
        side: border != null ? BorderSide(color: border) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(NocturneRadius.md),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 10 : 12,
            vertical: dense ? 6 : 8,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A small colored label — used for priority tags (`.tag` + priority
/// colors) and generic outline/neutral tags (due dates, etc).
class NocturneTag extends StatelessWidget {
  const NocturneTag({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.outline = false,
  });

  /// Builds the High/Med/Low priority tag with its fixed color, or null for
  /// [TaskPriority.none] (nothing to show).
  static Widget? forPriority(TaskPriority priority) {
    final color = switch (priority) {
      TaskPriority.high => NocturnePriority.high,
      TaskPriority.med => NocturnePriority.med,
      TaskPriority.low => NocturnePriority.low,
      TaskPriority.none => null,
    };
    if (color == null) return null;
    return NocturneTag(label: priority.label, color: color);
  }

  final String label;
  final IconData? icon;

  /// Fill/text color for a solid tag. Ignored when [outline] is true.
  final Color? color;

  /// An outlined tag (e.g. the due-date chip) instead of a filled one.
  final bool outline;

  @override
  Widget build(BuildContext context) {
    final accent = context.nocturneAccent;
    final tokens = context.nocturne;

    final Color fg;
    final Color? bg;
    final Color borderColor;
    if (outline) {
      fg = accent;
      bg = null;
      borderColor = accent;
    } else if (color != null) {
      fg = color!;
      bg = color!.withValues(alpha: 0.22);
      borderColor = Colors.transparent;
    } else {
      fg = tokens.neutral200;
      bg = tokens.neutral800;
      borderColor = Colors.transparent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        border: outline ? Border.all(color: borderColor) : null,
        borderRadius: BorderRadius.circular(NocturneRadius.md * 0.75),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: color != null ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.02,
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of mutually-exclusive options in one outlined pill — matches the
/// `.seg`/`.seg-opt` classes (view toggle, priority/date-format/landing
/// pickers).
class NocturneSegmented<T> extends StatelessWidget {
  const NocturneSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.labelBuilder,
    this.iconBuilder,
  });

  final List<T> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T)? labelBuilder;
  final IconData Function(T)? iconBuilder;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    final accent = context.nocturneAccent;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: tokens.divider),
        borderRadius: BorderRadius.circular(NocturneRadius.md),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NocturneRadius.md),
        // A SingleChildScrollView rather than a bare Row: with enough
        // options (or a narrow enough container — the Settings screen's
        // responsive columns can get quite tight), a fixed-width Row of
        // segments can ask for more space than it's given, which would
        // otherwise be a hard overflow error rather than something a user
        // ever notices.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < options.length; i++)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : Border(left: BorderSide(color: tokens.divider)),
                    boxShadow: value == options[i]
                        ? [
                            BoxShadow(
                              color: accent,
                              spreadRadius: -1,
                              blurRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: InkWell(
                    onTap: () => onChanged(options[i]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (iconBuilder != null)
                            Icon(
                              iconBuilder!(options[i]),
                              size: 15,
                              color: value == options[i] ? accent : tokens.text,
                            ),
                          if (labelBuilder != null)
                            Text(
                              labelBuilder!(options[i]),
                              style: TextStyle(
                                fontSize: 13,
                                color: value == options[i]
                                    ? accent
                                    : tokens.text,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An 11px uppercase section header, e.g. "PROJECTS" / "FAVORITES".
class NocturneSectionLabel extends StatelessWidget {
  const NocturneSectionLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(0, 0, 0, 12),
  });

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.06,
          color: context.nocturne.neutral400,
        ),
      ),
    );
  }
}
