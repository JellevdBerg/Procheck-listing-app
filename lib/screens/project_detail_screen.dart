import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../widgets/create_task_sheet.dart';
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

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        title: Hero(
          tag: projectHeaderHeroTag(project.id),
          child: Material(
            type: MaterialType.transparency,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder, color: accentPalette[project.colorIndex]),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    project.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
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
      body: tasks.isEmpty
          ? Center(
              child: Text(
                'No tasks in this project yet.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          : ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) =>
                  TaskTile(key: ValueKey(tasks[index].id), task: tasks[index]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            showCreateTaskSheet(context, initialProjectId: projectId),
        child: const Icon(Icons.add),
      ),
    );
  }
}
