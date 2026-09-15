import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project.dart';
import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../widgets/create_task_sheet.dart';
import '../widgets/pop_out_removal.dart';
import '../widgets/project_card.dart';
import '../widgets/task_tile.dart';
import '../widgets/text_prompt_dialog.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final matches = projects.where((p) => p.id == projectId);
    final project = matches.isEmpty ? null : matches.first;

    if (project == null) {
      // The project was deleted (e.g. from another view); pop back.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final tasks = ref
        .watch(tasksProvider)
        .where((t) => t.projectId == projectId)
        .toList();
    final reduceMotion = ref.watch(settingsProvider).reduceMotion;

    // The project's own color becomes the accent for everything in this
    // screen (checkboxes, the FAB, ...) — scoped to this subtree only, so
    // the app's global theme is untouched. Forcing primary/secondary to the
    // exact accent (rather than re-deriving a Material tonal palette from
    // it) keeps it visually identical to the color swatch the user picked.
    final accentColor = accentPalette[project.colorIndex];
    final onAccent = accentColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
    final baseTheme = Theme.of(context);
    final projectTheme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: accentColor,
        onPrimary: onAccent,
        secondary: accentColor,
        onSecondary: onAccent,
      ),
    );

    return Theme(
      data: projectTheme,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit project',
              onPressed: () async {
                final result = await showProjectPromptDialog(
                  context,
                  title: 'Edit project',
                  initialValue: project.name,
                  initialColorIndex: project.colorIndex,
                );
                if (result != null) {
                  final (name, colorIndex) = result;
                  final notifier = ref.read(projectsProvider.notifier);
                  notifier.renameProject(projectId, name);
                  notifier.setProjectColor(projectId, colorIndex);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete project',
              onPressed: () async {
                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Delete project?',
                  message:
                      'Tasks and subtasks inside "${project.name}" will be deleted too. This cannot be undone.',
                );
                if (confirmed) {
                  ref.read(projectsProvider.notifier).deleteProject(projectId);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProjectHeroSidebar(project: project, accentColor: accentColor),
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Text(
                        'No tasks in this project yet.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                  : ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return PopOutRemoval(
                          key: ValueKey(task.id),
                          reduceMotion: reduceMotion,
                          shrinkWidth: false,
                          onRemoved: () => ref
                              .read(tasksProvider.notifier)
                              .deleteTask(task.id),
                          builder: (context, triggerRemoval) =>
                              TaskTile(task: task, onDelete: triggerRemoval),
                        );
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: accentColor,
          foregroundColor: onAccent,
          onPressed: () =>
              showCreateTaskSheet(context, initialProjectId: projectId),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

/// The opened project's identity, shown as a slim vertical strip on the left
/// instead of a horizontal title banner: the folder icon at the top, and the
/// project name running vertically below it. Shares a [Hero] tag with the
/// project card it was opened from, so it morphs in from wherever that card
/// was on the previous screen.
class _ProjectHeroSidebar extends StatelessWidget {
  const _ProjectHeroSidebar({required this.project, required this.accentColor});

  final Project project;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 88,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.10),
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Hero(
        tag: projectHeaderHeroTag(project.id),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              const SizedBox(height: 20),
              Icon(Icons.folder, color: accentColor, size: 28),
              const SizedBox(height: 16),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      project.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
