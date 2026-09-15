import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../models/task_template.dart';
import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/task_templates_provider.dart';
import '../providers/tasks_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/blurred_dialog.dart';
import '../widgets/create_task_sheet.dart';
import '../widgets/page_transitions.dart';
import '../widgets/pop_out_removal.dart';
import '../widgets/project_card.dart';
import '../widgets/task_tile.dart';
import '../widgets/text_prompt_dialog.dart';
import 'project_detail_screen.dart';
import 'settings_screen.dart';
import 'task_template_editor_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DropAwayOnPush(
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogo(size: 32),
              SizedBox(width: 12),
              Text('ProCheck'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Projects'),
              Tab(text: 'Templates'),
              Tab(text: 'Archived'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [_ProjectsTab(), _TemplatesTab(), _ArchivedTab()],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: switch (_tabController.index) {
          0 => FloatingActionButton(
            onPressed: () => _showProjectsTabActions(context),
            child: const Icon(Icons.add),
          ),
          1 => FloatingActionButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TaskTemplateEditorScreen(),
              ),
            ),
            child: const Icon(Icons.add),
          ),
          // Archived tab: nothing to create here.
          _ => null,
        },
      ),
    );
  }

  void _showProjectsTabActions(BuildContext context) {
    showBlurredDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.checklist_rtl_rounded),
                  title: const Text('New task'),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    showCreateTaskSheet(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('New project'),
                  onTap: () async {
                    Navigator.of(dialogContext).pop();
                    final result = await showProjectPromptDialog(
                      context,
                      title: 'New project',
                      confirmLabel: 'Create',
                    );
                    if (result != null) {
                      final (name, colorIndex) = result;
                      ref
                          .read(projectsProvider.notifier)
                          .addProject(name, colorIndex: colorIndex);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectsTab extends ConsumerStatefulWidget {
  const _ProjectsTab();

  @override
  ConsumerState<_ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends ConsumerState<_ProjectsTab> {
  static const _featuredCardHeight = 280.0;
  static const _featuredCardMinWidth = 240.0;
  static const _gridPadding = 16.0;
  static const _gridSpacing = 16.0;

  final _searchController = TextEditingController();
  String _query = '';

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

    if (allProjects.isEmpty && unfiledTasks.isEmpty) {
      return const _EmptyState(
        icon: Icons.checklist_rtl_rounded,
        message: 'No tasks yet.\nTap + to create your first task or project.',
      );
    }

    final query = _query.trim().toLowerCase();
    final projects = query.isEmpty
        ? allProjects
        : allProjects
              .where((p) => p.name.toLowerCase().contains(query))
              .toList();

    void openProject(String projectId) {
      ref.read(projectsProvider.notifier).touchProject(projectId);
      pushSlideIn(
        context,
        ProjectDetailScreen(projectId: projectId),
        reduceMotion: reduceMotion,
      );
    }

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        // How many featured cards fit in one row — based purely on the
        // window width, not on how many projects actually exist, so a
        // single project gets a naturally-sized card instead of stretching
        // to fill the whole row.
        final availableWidth = outerConstraints.maxWidth - _gridPadding * 2;
        final columnCapacity = (availableWidth / _featuredCardMinWidth)
            .floor()
            .clamp(1, 1 << 30);
        final cardWidth =
            (availableWidth - _gridSpacing * (columnCapacity - 1)) /
            columnCapacity;
        final featuredProjects = projects.take(columnCapacity).toList();
        final otherProjects = projects.skip(columnCapacity).toList();

        return ListView(
          children: [
            if (allProjects.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Search projects',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear search',
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _query = '';
                            }),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (featuredProjects.isNotEmpty) ...[
              const _SectionHeader('Projects'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _gridPadding),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: _gridSpacing,
                  runSpacing: _gridSpacing,
                  children: [
                    for (final project in featuredProjects)
                      PopOutRemoval(
                        key: ValueKey(project.id),
                        reduceMotion: reduceMotion,
                        onRemoved: () => ref
                            .read(projectsProvider.notifier)
                            .deleteProject(project.id),
                        builder: (context, triggerRemoval) => SizedBox(
                          width: cardWidth,
                          height: _featuredCardHeight,
                          child: ProjectCard(
                            project: project,
                            featured: true,
                            reduceMotion: reduceMotion,
                            tasks: tasks
                                .where((t) => t.projectId == project.id)
                                .toList(),
                            onTap: () => openProject(project.id),
                            onDelete: triggerRemoval,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ] else if (query.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 24,
                ),
                child: Text(
                  'No projects match "${_query.trim()}".',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
            if (otherProjects.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _gridPadding),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final project in otherProjects)
                      PopOutRemoval(
                        key: ValueKey(project.id),
                        reduceMotion: reduceMotion,
                        onRemoved: () => ref
                            .read(projectsProvider.notifier)
                            .deleteProject(project.id),
                        builder: (context, triggerRemoval) => ProjectCard(
                          project: project,
                          reduceMotion: reduceMotion,
                          tasks: tasks
                              .where((t) => t.projectId == project.id)
                              .toList(),
                          onTap: () => openProject(project.id),
                          onDelete: triggerRemoval,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (unfiledTasks.isNotEmpty) ...[
              const _SectionHeader('Tasks'),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: unfiledTasks.length,
                onReorderItem: (oldIndex, newIndex) {
                  final reordered = [...unfiledTasks];
                  final moved = reordered.removeAt(oldIndex);
                  reordered.insert(newIndex, moved);
                  ref
                      .read(tasksProvider.notifier)
                      .reorderTasks(reordered.map((t) => t.id).toList());
                },
                itemBuilder: (context, index) {
                  final task = unfiledTasks[index];
                  return PopOutRemoval(
                    key: ValueKey(task.id),
                    reduceMotion: reduceMotion,
                    shrinkWidth: false,
                    onRemoved: () =>
                        _deleteUnfiledTaskWithUndo(context, ref, task),
                    builder: (context, triggerRemoval) => TaskTile(
                      task: task,
                      onDelete: triggerRemoval,
                      autoRemoveWhenChecked: true,
                      reorderIndex: index,
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}

/// Deletes an unfiled task (whether via the trash icon or auto-removal
/// after being checked off) but offers a few seconds to undo it — standalone
/// tasks have no project to recover them from, so an accidental removal
/// would otherwise be unrecoverable.
void _deleteUnfiledTaskWithUndo(
  BuildContext context,
  WidgetRef ref,
  Task task,
) {
  ref.read(tasksProvider.notifier).deleteTask(task.id);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('"${task.title}" deleted'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => ref.read(tasksProvider.notifier).restoreTask(task),
      ),
    ),
  );
}

class _TemplatesTab extends ConsumerWidget {
  const _TemplatesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(taskTemplatesProvider);

    if (templates.isEmpty) {
      return const _EmptyState(
        icon: Icons.copy_all_outlined,
        message: 'No templates yet.\nA template sets up a main task with its subtasks, ready to reuse.',
      );
    }

    return ListView(
      children: [
        for (final TaskTemplate template in templates)
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.copy_all_outlined)),
            title: Text(template.name),
            subtitle: Text('${template.subtasks.length} subtask(s)'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    TaskTemplateEditorScreen(templateId: template.id),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.playlist_add_check),
              tooltip: 'Use template',
              onPressed: () =>
                  showCreateTaskSheet(context, initialTemplate: template),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _ArchivedTab extends ConsumerStatefulWidget {
  const _ArchivedTab();

  @override
  ConsumerState<_ArchivedTab> createState() => _ArchivedTabState();
}

class _ArchivedTabState extends ConsumerState<_ArchivedTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final reduceMotion = ref.watch(settingsProvider).reduceMotion;
    final archived =
        ref.watch(projectsProvider).where((p) => p.archived).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    if (archived.isEmpty) {
      return const _EmptyState(
        icon: Icons.archive_outlined,
        message: 'No archived projects.\nArchive a project from its detail screen to see it here.',
      );
    }

    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? archived
        : archived.where((p) => p.name.toLowerCase().contains(query)).toList();

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search archived projects',
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear search',
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _query = '';
                      }),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Text(
              'No archived projects match "${_query.trim()}".',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          )
        else
          for (final project in visible)
            _ArchivedProjectRow(
              project: project,
              taskCount: tasks.where((t) => t.projectId == project.id).length,
              reduceMotion: reduceMotion,
            ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _ArchivedProjectRow extends ConsumerWidget {
  const _ArchivedProjectRow({
    required this.project,
    required this.taskCount,
    required this.reduceMotion,
  });

  final Project project;
  final int taskCount;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = accentPalette[project.colorIndex];
    return ListTile(
      leading: Icon(Icons.folder, color: color),
      title: Text(
        '${project.name} ($taskCount task${taskCount == 1 ? '' : 's'})',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.unarchive_outlined),
        tooltip: 'Unarchive',
        onPressed: () =>
            ref.read(projectsProvider.notifier).unarchiveProject(project.id),
      ),
      onTap: () {
        ref.read(projectsProvider.notifier).touchProject(project.id);
        pushSlideIn(
          context,
          ProjectDetailScreen(projectId: project.id),
          reduceMotion: reduceMotion,
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: Theme.of(context).hintColor),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).hintColor),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
