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

    // The top bar gets its own subtle tint derived from the project color —
    // just enough to feel connected to the (much stronger) hero sidebar,
    // without depending on the OS light/dark background or overpowering the
    // neutral task area. A fixed, computed foreground (rather than the
    // theme's default) keeps the back/edit/delete icons readable against it
    // regardless of how light or dark that tint ends up being.
    final appBarColor = Color.lerp(
      baseTheme.colorScheme.surface,
      accentColor,
      0.10,
    )!;
    final onAppBarColor = appBarColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return Theme(
      data: projectTheme,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: appBarColor,
          foregroundColor: onAppBarColor,
          elevation: 0,
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
            _ProjectHeroSidebar(
              project: project,
              accentColor: accentColor,
              reduceMotion: reduceMotion,
            ),
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
  const _ProjectHeroSidebar({
    required this.project,
    required this.accentColor,
    required this.reduceMotion,
  });

  final Project project;
  final Color accentColor;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 104,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.16),
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Open, since this is the currently-opened project; the main menu's
          // ProjectCard uses the closed variant instead, and the Hero flight
          // between the two is what carries the visual "opening" transition
          // (Flutter has no built-in animated icon pair for a folder morphing
          // open, so this is the closest natural transition available
          // without a bespoke icon asset).
          Hero(
            tag: projectIconHeroTag(project.id),
            child: Material(
              type: MaterialType.transparency,
              child: Icon(Icons.folder_open, color: accentColor, size: 28),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Hero(
              tag: projectNameHeroTag(project.id),
              flightShuttleBuilder: projectNameHeroFlightShuttleBuilder(
                reduceMotion,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Align(
                  alignment: Alignment.center,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        project.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
