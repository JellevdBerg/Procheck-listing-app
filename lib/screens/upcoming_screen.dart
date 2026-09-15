import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../widgets/project_name_lookup.dart';
import '../widgets/smart_view_task_row.dart';
import 'empty_state.dart';

/// Every unchecked task with a due date strictly after today, soonest
/// first.
class UpcomingScreen extends ConsumerWidget {
  const UpcomingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final projects = ref.watch(projectsProvider);
    final reduceMotion = ref.watch(settingsProvider).reduceMotion;
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final upcomingTasks =
        tasks
            .where(
              (t) =>
                  !t.isChecked &&
                  t.dueDate != null &&
                  t.dueDate!.isAfter(endOfToday),
            )
            .toList()
          ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    if (upcomingTasks.isEmpty) {
      return const EmptyState(
        icon: Icons.calendar_month_outlined,
        message: 'Nothing coming up.',
      );
    }

    final projectNames = buildProjectNameLookup(projects);

    return ListView(
      padding: const EdgeInsets.all(16.8),
      children: [
        Text('Upcoming', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16.8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11.2),
            child: Column(
              children: [
                for (final task in upcomingTasks)
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
