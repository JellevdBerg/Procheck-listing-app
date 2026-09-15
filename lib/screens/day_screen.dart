import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../widgets/create_task_sheet.dart';
import '../widgets/nocturne/nocturne_widgets.dart';
import '../widgets/project_name_lookup.dart';
import '../widgets/smart_view_task_row.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Tasks due on [date] — reached by clicking a day in the sidebar's mini
/// calendar.
class DayScreen extends ConsumerWidget {
  const DayScreen({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final projects = ref.watch(projectsProvider);
    final reduceMotion = ref.watch(settingsProvider).reduceMotion;

    final dayTasks = tasks
        .where(
          (t) =>
              t.dueDate != null &&
              t.dueDate!.year == date.year &&
              t.dueDate!.month == date.month &&
              t.dueDate!.day == date.day,
        )
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    final projectNames = buildProjectNameLookup(projects);
    final label = '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

    return ListView(
      padding: const EdgeInsets.all(16.8),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tasks for $label',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            NocturneButton(
              label: 'New task',
              icon: Icons.add,
              dense: true,
              onPressed: () => showCreateTaskSheet(context),
            ),
          ],
        ),
        const SizedBox(height: 16.8),
        if (dayTasks.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(22.4),
              child: Center(
                child: Text(
                  'No tasks due this day.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11.2),
              child: Column(
                children: [
                  for (final task in dayTasks)
                    SmartViewTaskRow(
                      task: task,
                      reduceMotion: reduceMotion,
                      projectName: projectNameFor(
                        projectNames,
                        task.projectId,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
