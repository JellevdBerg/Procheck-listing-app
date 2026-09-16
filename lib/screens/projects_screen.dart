import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../widgets/create_task_sheet.dart';
import '../widgets/nocturne/nocturne_widgets.dart';
import '../widgets/pop_out_removal.dart';
import '../widgets/project_card.dart';
import '../widgets/task_tile.dart';
import '../widgets/text_prompt_dialog.dart';
import 'app_shell.dart';

enum _ProjectsView { grid, list }

/// The default/home screen: a search bar + view toggle, the project grid
/// (each card opens via the card-morph overlay), and a bordered list of
/// unfiled tasks below it.
class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.onShowUndo,
    required this.onOpenProject,
  });

  final ShowUndo onShowUndo;
  final void Function(String projectId, BuildContext cardContext) onOpenProject;

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  static const _featuredCardHeight = 280.0;
  static const _featuredCardMinWidth = 240.0;

  final _searchController = TextEditingController();
  String _query = '';
  _ProjectsView _view = _ProjectsView.grid;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allProjects = ref
        .watch(projectsProvider)
        .where((p) => !p.archived)
        .toList();
    final tasks = ref.watch(tasksProvider);
    final reduceMotion = ref.watch(settingsProvider).reduceMotion;
    final unfiledTasks = tasks.where((t) => t.projectId == null).toList();

    final query = _query.trim().toLowerCase();
    final projects = query.isEmpty
        ? allProjects
        : allProjects
              .where((p) => p.name.toLowerCase().contains(query))
              .toList();

    return ListView(
      key: const Key('projects-scroll'),
      padding: const EdgeInsets.fromLTRB(16.8, 16.8, 16.8, 22.4),
      children: [
        Row(
          children: [
            // A single Expanded — rather than a Flexible competing for flex
            // space with a separate Spacer — is what keeps the trailing
            // controls flush against the right edge as the window widens;
            // two same-priority flexible children split the leftover space
            // between them instead of handing it all to the Spacer.
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search projects',
                    ),
                  ),
                ),
              ),
            ),
            NocturneSegmented<_ProjectsView>(
              options: _ProjectsView.values,
              value: _view,
              iconBuilder: (v) => v == _ProjectsView.grid
                  ? Icons.grid_view
                  : Icons.view_list,
              onChanged: (v) => setState(() => _view = v),
            ),
            const SizedBox(width: 12),
            NocturneButton(
              label: 'New project',
              icon: Icons.add,
              variant: NocturneButtonVariant.primary,
              onPressed: () => _createProject(context),
            ),
          ],
        ),
        const SizedBox(height: 16.8),
        if (allProjects.isNotEmpty) ...[
          const NocturneSectionLabel('PROJECTS'),
          if (projects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No projects match "${_query.trim()}".',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else if (_view == _ProjectsView.grid)
            _buildGrid(context, projects, tasks, reduceMotion)
          else
            _buildList(context, projects, tasks, reduceMotion),
          const SizedBox(height: 16.8),
        ],
        Row(
          children: [
            const Expanded(child: NocturneSectionLabel('TASKS')),
            NocturneButton(
              label: 'New task',
              icon: Icons.add,
              variant: NocturneButtonVariant.primary,
              onPressed: () => showCreateTaskSheet(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (unfiledTasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No unfiled tasks. Use "New task" above, or "New project" to '
              'get organized.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11.2),
              child: Column(
                children: [
                  for (var i = 0; i < unfiledTasks.length; i++)
                    PopOutRemoval(
                      key: ValueKey(unfiledTasks[i].id),
                      reduceMotion: reduceMotion,
                      shrinkWidth: false,
                      onRemoved: () => ref
                          .read(tasksProvider.notifier)
                          .deleteTask(unfiledTasks[i].id),
                      builder: (context, triggerRemoval) => TaskTile(
                        task: unfiledTasks[i],
                        onDelete: triggerRemoval,
                        onExplicitDelete: () => widget.onShowUndo(
                          label: '"${unfiledTasks[i].title}" deleted',
                          onUndo: () => ref
                              .read(tasksProvider.notifier)
                              .restoreTask(unfiledTasks[i]),
                        ),
                        autoRemoveWhenChecked: true,
                        reorderIndex: i,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGrid(
    BuildContext context,
    List<Project> projects,
    List<Task> tasks,
    bool reduceMotion,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCapacity = (constraints.maxWidth / _featuredCardMinWidth)
            .floor()
            .clamp(1, 1 << 30);
        final spacing = 11.2 * (columnCapacity - 1);
        final cardWidth = (constraints.maxWidth - spacing) / columnCapacity;

        return Wrap(
          spacing: 11.2,
          runSpacing: 11.2,
          children: [
            for (final project in projects)
              PopOutRemoval(
                key: ValueKey(project.id),
                reduceMotion: reduceMotion,
                onRemoved: () =>
                    ref.read(projectsProvider.notifier).deleteProject(project.id),
                builder: (context, triggerRemoval) => SizedBox(
                  width: cardWidth,
                  height: _featuredCardHeight,
                  child: Builder(
                    builder: (cardContext) => ProjectCard(
                      project: project,
                      featured: true,
                      reduceMotion: reduceMotion,
                      tasks: tasks
                          .where((t) => t.projectId == project.id)
                          .toList(),
                      onTap: () => widget.onOpenProject(project.id, cardContext),
                      onDelete: triggerRemoval,
                      onArchive: () => _archiveProject(project),
                      onToggleFavorite: () => ref
                          .read(projectsProvider.notifier)
                          .toggleFavorite(project.id),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    List<Project> projects,
    List<Task> tasks,
    bool reduceMotion,
  ) {
    return Column(
      children: [
        for (final project in projects)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PopOutRemoval(
              key: ValueKey(project.id),
              reduceMotion: reduceMotion,
              onRemoved: () =>
                  ref.read(projectsProvider.notifier).deleteProject(project.id),
              builder: (context, triggerRemoval) => Builder(
                builder: (cardContext) => ProjectCard(
                  project: project,
                  reduceMotion: reduceMotion,
                  tasks: tasks
                      .where((t) => t.projectId == project.id)
                      .toList(),
                  onTap: () => widget.onOpenProject(project.id, cardContext),
                  onDelete: triggerRemoval,
                  onArchive: () => _archiveProject(project),
                  onToggleFavorite: () => ref
                      .read(projectsProvider.notifier)
                      .toggleFavorite(project.id),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _archiveProject(Project project) {
    ref.read(projectsProvider.notifier).archiveProject(project.id);
    widget.onShowUndo(
      label: '"${project.name}" archived',
      onUndo: () =>
          ref.read(projectsProvider.notifier).unarchiveProject(project.id),
    );
  }

  Future<void> _createProject(BuildContext context) async {
    final result = await showProjectPromptDialog(
      context,
      title: 'New project',
      confirmLabel: 'Create',
    );
    if (result == null) return;
    final (name, colorIndex) = result;
    ref.read(projectsProvider.notifier).addProject(name, colorIndex: colorIndex);
  }
}
