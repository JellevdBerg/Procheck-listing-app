import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task_template.dart';
import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/task_templates_provider.dart';
import '../providers/tasks_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/blurred_dialog.dart';
import '../widgets/create_task_sheet.dart';
import '../widgets/page_transitions.dart';
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
    _tabController = TabController(length: 2, vsync: this);
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
          title: const Text('ProCheck'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 16, left: 4),
              child: AppLogo(size: 32),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Projects'),
              Tab(text: 'Templates'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [_ProjectsTab(), _TemplatesTab()],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _tabController.index == 0
            ? FloatingActionButton(
                onPressed: () => _showProjectsTabActions(context),
                child: const Icon(Icons.add),
              )
            : FloatingActionButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TaskTemplateEditorScreen(),
                  ),
                ),
                child: const Icon(Icons.add),
              ),
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

  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allProjects = ref.watch(projectsProvider);
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
        // How many featured cards fit in one row is what "on full display"
        // means here: it grows with the window instead of a fixed count.
        final availableWidth = outerConstraints.maxWidth - _gridPadding * 2;
        final crossAxisCount = projects.isEmpty
            ? 1
            : (availableWidth / _featuredCardMinWidth).floor().clamp(
                1,
                projects.length,
              );
        final featuredProjects = projects.take(crossAxisCount).toList();
        final otherProjects = projects.skip(crossAxisCount).toList();

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
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisExtent: _featuredCardHeight,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: featuredProjects.length,
                  itemBuilder: (context, index) {
                    final project = featuredProjects[index];
                    return ProjectCard(
                      project: project,
                      featured: true,
                      tasks: tasks
                          .where((t) => t.projectId == project.id)
                          .toList(),
                      onTap: () => openProject(project.id),
                      onDelete: () => ref
                          .read(projectsProvider.notifier)
                          .deleteProject(project.id),
                    );
                  },
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
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final project in otherProjects)
                      ProjectCard(
                        project: project,
                        tasks: tasks
                            .where((t) => t.projectId == project.id)
                            .toList(),
                        onTap: () => openProject(project.id),
                        onDelete: () => ref
                            .read(projectsProvider.notifier)
                            .deleteProject(project.id),
                      ),
                  ],
                ),
              ),
            ],
            if (unfiledTasks.isNotEmpty) ...[
              const _SectionHeader('Tasks'),
              for (final task in unfiledTasks)
                TaskTile(key: ValueKey(task.id), task: task),
            ],
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
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
