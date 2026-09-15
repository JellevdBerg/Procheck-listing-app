import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/settings_provider.dart';
import 'text_prompt_dialog.dart';

/// The Hero tags a [ProjectCard]'s header shares with the thin bar header of
/// the project's detail screen, so tapping the card morphs it into that bar.
///
/// The icon and the name are split into two independent Hero flights rather
/// than one covering both: the icon's rect-tween looks fine under Flutter's
/// default flight (it's a single glyph), but the name goes from a short
/// horizontal line on the card to a large vertical line in the detail
/// screen's sidebar, and stretching one of those across the animated rect —
/// which is what a single shared Hero does — reads as the text warping or
/// floating mid-flight. See [projectNameHeroFlightShuttleBuilder].
String projectIconHeroTag(String projectId) => 'project-icon-$projectId';

String projectNameHeroTag(String projectId) => 'project-name-$projectId';

/// Crossfades between the two label widgets instead of letting Flutter's
/// default Hero flight stretch one of them across the whole animated rect.
/// Each label is drawn at its own natural orientation/size and simply faded
/// in or out, so neither ever gets distorted mid-flight.
///
/// [reduceMotion] skips the crossfade entirely and jumps straight to the
/// destination label, matching how the rest of the app treats that setting.
HeroFlightShuttleBuilder projectNameHeroFlightShuttleBuilder(
  bool reduceMotion,
) {
  return (
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final fromHero = fromHeroContext.widget as Hero;
    final toHero = toHeroContext.widget as Hero;

    if (reduceMotion) return toHero.child;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value.clamp(0.0, 1.0);
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 1 - t,
              child: Center(child: fromHero.child),
            ),
            Opacity(
              opacity: t,
              child: Center(child: toHero.child),
            ),
          ],
        );
      },
    );
  };
}

/// A project tile for the home screen grid. [featured] gives the tall card
/// with a preview of up to 4 tasks; otherwise it's a compact, name-only
/// chip. Both reveal a delete button on hover.
class ProjectCard extends StatefulWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.tasks,
    required this.onTap,
    required this.onDelete,
    this.featured = false,
    this.reduceMotion = false,
  });

  final Project project;
  final List<Task> tasks;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool featured;
  final bool reduceMotion;

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: widget.featured ? _buildFeatured(context) : _buildCompact(context),
    );
  }

  Widget _header(BuildContext context, {required bool showDelete}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Hero(
          tag: projectIconHeroTag(widget.project.id),
          child: Material(
            type: MaterialType.transparency,
            child: Icon(
              Icons.folder,
              color: accentPalette[widget.project.colorIndex],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Hero(
            tag: projectNameHeroTag(widget.project.id),
            flightShuttleBuilder: projectNameHeroFlightShuttleBuilder(
              widget.reduceMotion,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Text(
                widget.project.name,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        if (showDelete)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Delete project',
            visualDensity: VisualDensity.compact,
            onPressed: () => _confirmDelete(context),
          ),
      ],
    );
  }

  Widget _buildFeatured(BuildContext context) {
    final theme = Theme.of(context);
    final preview = widget.tasks.take(4).toList();
    final extra = widget.tasks.length - preview.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, showDelete: _hovering),
              const SizedBox(height: 4),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Expanded(
                child: preview.isEmpty
                    ? Center(
                        child: Text(
                          'No tasks yet',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final task in preview)
                            _TaskPreviewRow(task: task),
                          if (extra > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '+$extra more',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: projectIconHeroTag(widget.project.id),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Icon(
                        Icons.folder_outlined,
                        size: 18,
                        color: accentPalette[widget.project.colorIndex],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Hero(
                    tag: projectNameHeroTag(widget.project.id),
                    flightShuttleBuilder: projectNameHeroFlightShuttleBuilder(
                      widget.reduceMotion,
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Text(widget.project.name),
                    ),
                  ),
                ],
              ),
              if (_hovering) ...[
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Delete project',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmDelete(context),
                ),
              ] else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete project?',
      message:
          'Tasks and subtasks inside "${widget.project.name}" will be deleted too. This cannot be undone.',
    );
    if (confirmed) widget.onDelete();
  }
}

class _TaskPreviewRow extends StatelessWidget {
  const _TaskPreviewRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            task.isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: task.isChecked ? Colors.green : theme.colorScheme.outline,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              task.title,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (task.hasSubtasks)
            Text(
              '${task.completedSubtaskCount}/${task.subtasks.length}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
        ],
      ),
    );
  }
}
