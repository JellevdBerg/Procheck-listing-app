import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../models/task_priority.dart';
import '../providers/tasks_provider.dart';
import '../theme/nocturne_theme.dart';
import 'nocturne/nocturne_widgets.dart';
import 'task_tile.dart' show formatDueDate;
import 'wobble_checkbox.dart';

/// A read-mostly task row for the Today/Upcoming/Day smart views: checkbox,
/// title, its project's name, priority tag, due tag. No expand/subtasks —
/// those live on the task's actual home (a project, or Unfiled Tasks).
class SmartViewTaskRow extends ConsumerWidget {
  const SmartViewTaskRow({
    super.key,
    required this.task,
    required this.projectName,
    this.reduceMotion = false,
  });

  final Task task;
  final String projectName;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.nocturne;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    color: task.isChecked ? tokens.neutral500 : tokens.text,
                    decoration: task.isChecked
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                Text(
                  projectName,
                  style: TextStyle(fontSize: 12, color: tokens.neutral400),
                ),
              ],
            ),
          ),
          ?NocturneTag.forPriority(task.priority),
          if (task.priority != TaskPriority.none) const SizedBox(width: 6),
          if (task.dueDate != null)
            NocturneTag(
              label: formatDueDate(task.dueDate!),
              icon: Icons.access_time,
              outline: true,
            ),
        ],
      ),
    );
  }
}
