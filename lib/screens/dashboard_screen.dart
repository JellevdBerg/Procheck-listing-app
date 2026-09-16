import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../theme/nocturne_theme.dart';
import '../widgets/nocturne/nocturne_widgets.dart';

/// True for an unchecked task with no due date, or one overdue — it needs
/// attention now rather than being scheduled for later.
bool isOpenTask(Task task, DateTime now) =>
    !task.isChecked && (task.dueDate == null || !task.dueDate!.isAfter(now));

/// True for an unchecked task with a due date still ahead of it — scheduled,
/// but not due yet.
bool isPendingTask(Task task, DateTime now) =>
    !task.isChecked && task.dueDate != null && task.dueDate!.isAfter(now);

/// An overview of every active (non-archived) project and its unfiled
/// tasks: top-line counts of open vs. pending tasks, plus a per-project
/// breakdown so it's clear where the outstanding work actually is.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.onOpenProject});

  final void Function(String projectId, BuildContext rowContext) onOpenProject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final tasks = ref.watch(tasksProvider);
    final now = DateTime.now();

    final activeProjects = projects.where((p) => !p.archived).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final activeProjectIds = activeProjects.map((p) => p.id).toSet();
    final relevantTasks = tasks
        .where((t) => t.projectId == null || activeProjectIds.contains(t.projectId))
        .toList();

    final openCount = relevantTasks.where((t) => isOpenTask(t, now)).length;
    final pendingCount = relevantTasks.where((t) => isPendingTask(t, now)).length;

    final rows = [
      for (final project in activeProjects)
        _ProjectRow(
          project: project,
          openCount: relevantTasks
              .where((t) => t.projectId == project.id && isOpenTask(t, now))
              .length,
          pendingCount: relevantTasks
              .where((t) => t.projectId == project.id && isPendingTask(t, now))
              .length,
        ),
    ];
    final unfiledOpen = relevantTasks
        .where((t) => t.projectId == null && isOpenTask(t, now))
        .length;
    final unfiledPending = relevantTasks
        .where((t) => t.projectId == null && isPendingTask(t, now))
        .length;
    if (unfiledOpen > 0 || unfiledPending > 0) {
      rows.add(
        _ProjectRow(
          project: null,
          openCount: unfiledOpen,
          pendingCount: unfiledPending,
        ),
      );
    }
    // Busiest first — that's the point of a dashboard.
    rows.sort(
      (a, b) => (b.openCount + b.pendingCount).compareTo(a.openCount + a.pendingCount),
    );

    return Padding(
      padding: const EdgeInsets.all(16.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16.8),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 11.2;
              final columns = (constraints.maxWidth / 200).floor().clamp(1, 3);
              final cardWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _StatCard(
                      icon: Icons.folder_outlined,
                      label: 'Active projects',
                      value: activeProjects.length,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _StatCard(
                      icon: Icons.error_outline,
                      label: 'Open tasks',
                      value: openCount,
                      color: NocturnePriority.high,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _StatCard(
                      icon: Icons.schedule,
                      label: 'Pending tasks',
                      value: pendingCount,
                      color: context.nocturneAccent,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22.4),
          const NocturneSectionLabel('BY PROJECT'),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No active projects or unfiled tasks yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 11.2),
                  itemCount: rows.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) => rows[index].build(
                    context,
                    onOpenProject: onOpenProject,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color ?? tokens.neutral400),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$value',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: tokens.neutral400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A precomputed row so the list can be sorted by activity before it's
/// built — [project] is null for the "Unfiled" pseudo-project row.
class _ProjectRow {
  _ProjectRow({required this.project, required this.openCount, required this.pendingCount});

  final Project? project;
  final int openCount;
  final int pendingCount;

  Widget build(
    BuildContext context, {
    required void Function(String projectId, BuildContext rowContext) onOpenProject,
  }) {
    final project = this.project;
    final tokens = context.nocturne;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: project == null
                  ? tokens.neutral500
                  : accentPalette[project.colorIndex],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              project?.name ?? 'Unfiled',
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (openCount > 0) ...[
            NocturneTag(label: '$openCount open', color: NocturnePriority.high),
            const SizedBox(width: 6),
          ],
          if (pendingCount > 0)
            NocturneTag(
              label: '$pendingCount pending',
              color: context.nocturneAccent,
              outline: true,
            ),
          if (openCount == 0 && pendingCount == 0)
            Text(
              'All clear',
              style: TextStyle(fontSize: 12, color: tokens.neutral500),
            ),
        ],
      ),
    );

    if (project == null) return content;
    return Builder(
      builder: (rowContext) => InkWell(
        onTap: () => onOpenProject(project.id, rowContext),
        child: content,
      ),
    );
  }
}
