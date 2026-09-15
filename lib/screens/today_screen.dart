import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../widgets/project_name_lookup.dart';
import '../widgets/smart_view_task_row.dart';
import 'empty_state.dart';

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Every unchecked task due today, across every project (and unfiled).
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final projects = ref.watch(projectsProvider);
    final reduceMotion = ref.watch(settingsProvider).reduceMotion;
    final now = DateTime.now();

    final todayTasks = tasks
        .where((t) => t.dueDate != null && _isSameDay(t.dueDate!, now))
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    if (todayTasks.isEmpty) {
      return const EmptyState(
        icon: Icons.wb_sunny_outlined,
        message: 'Nothing due today.',
      );
    }

    final projectNames = buildProjectNameLookup(projects);

    return ListView(
      padding: const EdgeInsets.all(16.8),
      children: [
        Text('Today', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16.8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11.2),
            child: Column(
              children: [
                for (final task in todayTasks)
                  SmartViewTaskRow(
                    task: task,
                    reduceMotion: reduceMotion,
                    projectName: projectNameFor(projectNames, task.projectId),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
