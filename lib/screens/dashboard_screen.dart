import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../theme/nocturne_theme.dart';
import '../widgets/nocturne/nocturne_widgets.dart';
import '../widgets/task_tile.dart' show formatDueDate;

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

    // The ring chart partitions every relevant task into exactly one of
    // three buckets (unlike open/pending above, which only cover unchecked
    // tasks): done, overdue-and-not-done, or still-active.
    final completedCount = relevantTasks.where((t) => t.isChecked).length;
    final overdueCount = relevantTasks
        .where((t) => !t.isChecked && t.dueDate != null && !t.dueDate!.isAfter(now))
        .length;
    final activeCount = relevantTasks.length - completedCount - overdueCount;

    final dateFormat = ref.watch(settingsProvider).dateFormat;
    final projectById = {for (final project in activeProjects) project.id: project};
    final overdueTasks =
        relevantTasks
            .where((t) => !t.isChecked && t.dueDate != null && !t.dueDate!.isAfter(now))
            .toList()
          ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

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
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TaskStatusRing(
                    active: activeCount,
                    overdue: overdueCount,
                    completed: completedCount,
                  ),
                  const SizedBox(height: 22.4),
                  const NocturneSectionLabel('OVERDUE'),
                  const SizedBox(height: 8),
                  if (overdueTasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No overdue tasks.',
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
                            for (var i = 0; i < overdueTasks.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              _OverdueTaskRow(
                                task: overdueTasks[i],
                                project: projectById[overdueTasks[i].projectId],
                                dateFormat: dateFormat,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 22.4),
                  const NocturneSectionLabel('BY PROJECT'),
                  const SizedBox(height: 8),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No active projects or unfiled tasks yet.',
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
                            for (var i = 0; i < rows.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              rows[i].build(context, onOpenProject: onOpenProject),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
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

/// A hand-rolled donut chart (no charting package in this app) splitting
/// every relevant task into active/overdue/completed, with a count legend.
class _TaskStatusRing extends StatelessWidget {
  const _TaskStatusRing({
    required this.active,
    required this.overdue,
    required this.completed,
  });

  final int active;
  final int overdue;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    final total = active + overdue + completed;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.8),
        child: Row(
          children: [
            SizedBox(
              width: 88,
              height: 88,
              child: CustomPaint(
                painter: _RingPainter(
                  trackColor: tokens.neutral200,
                  segments: total == 0
                      ? const []
                      : [
                          _RingSegment(active.toDouble(), context.nocturneAccent),
                          _RingSegment(overdue.toDouble(), NocturnePriority.high),
                          _RingSegment(completed.toDouble(), NocturneStatus.done),
                        ],
                ),
                child: Center(
                  child: Text('$total', style: Theme.of(context).textTheme.titleLarge),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RingLegendRow(color: context.nocturneAccent, label: 'Active', value: active),
                  const SizedBox(height: 10),
                  _RingLegendRow(color: NocturnePriority.high, label: 'Overdue', value: overdue),
                  const SizedBox(height: 10),
                  _RingLegendRow(
                    color: NocturneStatus.done,
                    label: 'Completed',
                    value: completed,
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

class _RingLegendRow extends StatelessWidget {
  const _RingLegendRow({required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 13, color: tokens.neutral400)),
        ),
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _RingSegment {
  const _RingSegment(this.value, this.color);

  final double value;
  final Color color;
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.segments, required this.trackColor});

  final List<_RingSegment> segments;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.shortestSide * 0.16;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    final total = segments.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return;

    var startAngle = -math.pi / 2;
    for (final segment in segments) {
      if (segment.value <= 0) continue;
      final sweep = (segment.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  // Segment values are recomputed fresh on every build, so a cheap
  // always-repaint is simpler than deep-comparing the list.
  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => true;
}

/// A single overdue task's row in the Dashboard's OVERDUE list, showing
/// which project (or "Unfiled") it belongs to — via the same colored dot
/// the BY PROJECT list uses, so it reads as a project tag rather than
/// looking like a second line of plain description — and how it's overdue.
class _OverdueTaskRow extends StatelessWidget {
  const _OverdueTaskRow({
    required this.task,
    required this.project,
    required this.dateFormat,
  });

  final Task task;
  final Project? project;
  final DateFormatOption dateFormat;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: NocturnePriority.high),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: project == null
                            ? tokens.neutral500
                            : accentPalette[project!.colorIndex],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      project?.name ?? 'Unfiled',
                      style: TextStyle(fontSize: 12, color: tokens.neutral400),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatDueDate(task.dueDate!, dateFormat),
            style: const TextStyle(fontSize: 12, color: NocturnePriority.high),
          ),
        ],
      ),
    );
  }
}
