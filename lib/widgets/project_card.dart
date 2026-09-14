import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/settings_provider.dart';
import 'text_prompt_dialog.dart';

/// The Hero tag a [ProjectCard]'s header shares with the thin bar header of
/// the project's detail screen, so tapping the card morphs it into that bar.
String projectHeaderHeroTag(String projectId) => 'project-header-$projectId';

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
  });

  final Project project;
  final List<Task> tasks;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool featured;

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
    return Hero(
      tag: projectHeaderHeroTag(widget.project.id),
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          children: [
            Icon(Icons.folder, color: accentPalette[widget.project.colorIndex]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.project.name,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
        ),
      ),
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
              Hero(
                tag: projectHeaderHeroTag(widget.project.id),
                child: Material(
                  type: MaterialType.transparency,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 18,
                        color: accentPalette[widget.project.colorIndex],
                      ),
                      const SizedBox(width: 8),
                      Text(widget.project.name),
                    ],
                  ),
                ),
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
          'Tasks inside "${widget.project.name}" will move to Unfiled. This cannot be undone.',
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
