import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../theme/nocturne_theme.dart';
import '../widgets/nocturne/nocturne_widgets.dart';
import '../widgets/project_name_lookup.dart';
import '../widgets/task_tile.dart' show formatDueDate;
import '../widgets/wobble_checkbox.dart';
import 'empty_state.dart';

/// App-wide task search by title or notes, across every project (and
/// unfiled tasks) in the current workspace — the Projects screen's search
/// box only matches project names, so this is the one place that reaches
/// into task content itself. Scans the in-memory task list directly rather
/// than through an index: fine at the thousands-of-tasks scale the app
/// targets (see PR #29), revisit only if that stops being true.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, required this.onOpenTask});

  /// Opens a matched task's project, scrolled to and highlighting that
  /// task. Unfiled tasks (no project) aren't navigable, so their row is
  /// shown without a tap target.
  final void Function(String projectId, String taskId, BuildContext rowContext)
  onOpenTask;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
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
    final projects = ref.watch(projectsProvider);
    final reduceMotion = ref.watch(settingsProvider).reduceMotion;
    final projectNames = buildProjectNameLookup(projects);
    final projectsById = {for (final p in projects) p.id: p};

    final query = _query.trim().toLowerCase();
    final results = query.isEmpty
        ? const <Task>[]
        : tasks
              .where(
                (t) =>
                    t.title.toLowerCase().contains(query) ||
                    (t.notes?.toLowerCase().contains(query) ?? false),
              )
              .toList();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16.8, 16.8, 16.8, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Search', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16.8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search tasks by title or notes',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(height: 16.8),
              ],
            ),
          ),
        ),
        if (query.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.search,
              message: 'Type to search tasks by title or notes.',
            ),
          )
        else if (results.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.search_off,
              message: 'No tasks match "${_query.trim()}".',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16.8, 0, 16.8, 16.8),
            sliver: DecoratedSliver(
              decoration: BoxDecoration(
                color: context.nocturne.surface,
                borderRadius: BorderRadius.circular(NocturneRadius.md),
                border: Border.all(color: context.nocturne.neutral800),
              ),
              sliver: SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 11.2),
                sliver: SliverList.separated(
                  itemCount: results.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: context.nocturne.neutral800),
                  itemBuilder: (context, index) {
                    final task = results[index];
                    return _SearchResultRow(
                      task: task,
                      project: task.projectId == null
                          ? null
                          : projectsById[task.projectId],
                      projectName: projectNameFor(projectNames, task.projectId),
                      reduceMotion: reduceMotion,
                      onOpenTask: widget.onOpenTask,
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchResultRow extends ConsumerWidget {
  const _SearchResultRow({
    required this.task,
    required this.project,
    required this.projectName,
    required this.reduceMotion,
    required this.onOpenTask,
  });

  final Task task;
  final Project? project;
  final String projectName;
  final bool reduceMotion;
  final void Function(String projectId, String taskId, BuildContext rowContext)
  onOpenTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.nocturne;
    final dateFormat = ref.watch(settingsProvider).dateFormat;
    final priorityTag = NocturneTag.forPriority(task.priority);

    final titleAndNotes = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          task.title,
          style: TextStyle(
            fontSize: 14,
            color: task.isChecked ? tokens.neutral500 : tokens.text,
            decoration: task.isChecked ? TextDecoration.lineThrough : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (task.notes != null && task.notes!.trim().isNotEmpty)
          Text(
            task.notes!.trim(),
            style: TextStyle(fontSize: 12, color: tokens.neutral400),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        Text(
          projectName,
          style: TextStyle(fontSize: 11, color: tokens.neutral500),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          WobbleCheckbox(
            value: task.isChecked,
            reduceMotion: reduceMotion,
            onChanged: (_) =>
                ref.read(tasksProvider.notifier).toggleTask(task.id),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: project == null
                ? titleAndNotes
                : Builder(
                    builder: (rowContext) => InkWell(
                      onTap: () => onOpenTask(project!.id, task.id, rowContext),
                      child: titleAndNotes,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          // ignore: use_null_aware_elements (hive_generator pins analyzer <7, which can't parse `?element`)
          if (priorityTag != null) priorityTag,
          if (task.priority != TaskPriority.none) const SizedBox(width: 6),
          if (task.dueDate != null)
            NocturneTag(
              label: formatDueDate(task.dueDate!, dateFormat),
              icon: Icons.access_time,
              outline: true,
            ),
        ],
      ),
    );
  }
}
