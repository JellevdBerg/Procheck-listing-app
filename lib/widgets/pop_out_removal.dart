import 'package:flutter/material.dart';

/// Wraps a removable item (a project card, a task tile) so deleting it plays
/// a playful shrink-and-pop-out animation instead of vanishing instantly.
///
/// The wrapped item's actual layout footprint shrinks along with the
/// animation (via [Align]'s width/height factors, not just a paint-time
/// transform), so sibling items in a `Wrap`, `Column`, or list reflow
/// smoothly into the freed space as it plays, rather than jumping the
/// instant the item is actually removed from the data.
///
/// [builder] receives a `triggerRemoval` callback to wire up to whatever
/// delete affordance the wrapped widget provides. Calling it starts the
/// animation; [onRemoved] — expected to actually remove the item from the
/// underlying data/provider — fires once the animation completes.
class PopOutRemoval extends StatefulWidget {
  const PopOutRemoval({
    super.key,
    required this.builder,
    required this.onRemoved,
    this.reduceMotion = false,
    this.shrinkWidth = true,
  });

  final Widget Function(BuildContext context, VoidCallback triggerRemoval)
  builder;
  final VoidCallback onRemoved;
  final bool reduceMotion;

  /// Full-width rows (task tiles) usually only need to collapse vertically;
  /// grid cells (project cards) collapse in both dimensions.
  final bool shrinkWidth;

  @override
  State<PopOutRemoval> createState() => _PopOutRemovalState();
}

class _PopOutRemovalState extends State<PopOutRemoval>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  // A quick outward pop before the shrink, rather than a flat linear
  // collapse — the bit that makes this read as playful.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 25),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.15,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeInBack)),
      weight: 75,
    ),
  ]).animate(_controller);

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.35, 1.0, curve: Curves.easeIn),
  );

  // Drives the widget's real layout size — must stay within [0, 1] (unlike
  // the bouncier _scale/_opacity above) since Align's width/heightFactor
  // reject negative values.
  late final Animation<double> _sizeFactor = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInCubic,
  );

  bool _removing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _remove() async {
    if (_removing) return;
    if (widget.reduceMotion) {
      widget.onRemoved();
      return;
    }
    setState(() => _removing = true);
    await _controller.forward();
    if (mounted) widget.onRemoved();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.builder(context, _remove);
    if (!_removing) return child;

    return AnimatedBuilder(
      animation: _controller,
      child: child,
      builder: (context, child) {
        final collapse = 1 - _sizeFactor.value;
        return Align(
          widthFactor: widget.shrinkWidth ? collapse : 1,
          heightFactor: collapse,
          child: Opacity(
            opacity: (1 - _opacity.value).clamp(0.0, 1.0),
            child: Transform.scale(scale: _scale.value, child: child),
          ),
        );
      },
    );
  }
}
