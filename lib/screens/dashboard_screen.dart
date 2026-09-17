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

/// One project's checked-off/total task ratio, for the "Project completion"
/// pane. [fraction] is null for a project with no tasks yet — there's
/// nothing to divide, so it's kept out of the percentage ranking entirely
/// (see [computeProjectCompletions]) rather than reported as a misleading
/// 0% or a vacuous 100%.
class ProjectCompletion {
  const ProjectCompletion({
    required this.project,
    required this.total,
    required this.done,
  });

  final Project project;
  final int total;
  final int done;

  double? get fraction => total == 0 ? null : done / total;
}

/// Builds one [ProjectCompletion] per project in [projects] from [tasks],
/// ranked most-complete to least-complete. Projects with at least one task
/// are sorted by completion fraction descending (ties broken by name);
/// projects with zero tasks have no fraction to rank by, so they're kept
/// out of that ordering and simply appended, alphabetically, after it.
List<ProjectCompletion> computeProjectCompletions(
  List<Project> projects,
  List<Task> tasks,
) {
  final completions = [
    for (final project in projects)
      ProjectCompletion(
        project: project,
        total: tasks.where((t) => t.projectId == project.id).length,
        done: tasks
            .where((t) => t.projectId == project.id && t.isChecked)
            .length,
      ),
  ];

  int byNameAsc(ProjectCompletion a, ProjectCompletion b) =>
      a.project.name.toLowerCase().compareTo(b.project.name.toLowerCase());

  final ranked = completions.where((c) => c.fraction != null).toList()
    ..sort((a, b) {
      final byCompletion = b.fraction!.compareTo(a.fraction!);
      return byCompletion != 0 ? byCompletion : byNameAsc(a, b);
    });
  final unranked = completions.where((c) => c.fraction == null).toList()
    ..sort(byNameAsc);

  return [...ranked, ...unranked];
}

/// An overview of every active (non-archived) project and its unfiled
/// tasks: a project count, the active/overdue/completed ring chart, a
/// per-project completion ranking, an overdue-tasks list, and a per-project
/// open/pending breakdown so it's clear where the outstanding work actually
/// is.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({
    super.key,
    required this.onOpenProject,
    required this.onOpenTask,
  });

  final void Function(String projectId, BuildContext rowContext) onOpenProject;

  /// Like [onOpenProject], but for navigating in from a specific overdue
  /// task rather than the project itself — see [_OverdueTaskRow].
  final void Function(String projectId, String taskId, BuildContext rowContext)
  onOpenTask;

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
          // One row — active-projects count, the ring chart, and the
          // project completion pane side by side — rather than stacking
          // them, which used up a lot of vertical space before reaching
          // OVERDUE/BY PROJECT below. Below a width threshold there isn't
          // room for that (the ring chart alone needs ~220px to avoid
          // squashing its legend to nothing), so it falls back to the
          // original stacked layout instead of overflowing.
          LayoutBuilder(
            builder: (context, constraints) {
              final statCard = _StatCard(
                icon: Icons.folder_outlined,
                label: 'Active projects',
                value: activeProjects.length,
              );
              final overview = TaskOverviewSection(
                projects: activeProjects,
                tasks: relevantTasks,
                now: now,
              );
              if (constraints.maxWidth < 720) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: statCard,
                    ),
                    const SizedBox(height: 22.4),
                    overview,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: statCard),
                  const SizedBox(width: 11.2),
                  Expanded(flex: 3, child: overview),
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
                                onOpenTask: onOpenTask,
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

/// The ring chart + project-completion pane shared between the Dashboard
/// and the Archive screen's own mini-dashboard — [projects] is whatever
/// scope the caller wants charted and ranked (active projects for the
/// Dashboard, archived ones for the Archive screen), and [tasks] should
/// already be filtered down to just those projects' tasks (plus unfiled
/// ones, if relevant to that scope).
class TaskOverviewSection extends StatelessWidget {
  const TaskOverviewSection({
    super.key,
    required this.projects,
    required this.tasks,
    required this.now,
  });

  final List<Project> projects;
  final List<Task> tasks;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    // The ring chart partitions every task into exactly one of three
    // buckets: done, overdue-and-not-done, or still-active.
    final completedCount = tasks.where((t) => t.isChecked).length;
    final overdueCount = tasks
        .where((t) => !t.isChecked && t.dueDate != null && !t.dueDate!.isAfter(now))
        .length;
    final activeCount = tasks.length - completedCount - overdueCount;
    final completions = computeProjectCompletions(projects, tasks);
    final ring = _TaskStatusRing(
      active: activeCount,
      overdue: overdueCount,
      completed: completedCount,
    );
    final pane = _ProjectCompletionPane(completions: completions);

    // The ring chart's own row (the ring graphic plus its legend) needs
    // ~220px minimum before the legend gets squashed to nothing, so below
    // that this falls back to stacking the two instead of overflowing.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [ring, const SizedBox(height: 22.4), pane],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: ring),
            const SizedBox(width: 11.2),
            Expanded(flex: 2, child: pane),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: tokens.neutral400),
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

/// A ranked list of every project's checked-off/total task ratio, most
/// complete first — kept in its own bounded, independently-scrollable list
/// so it doesn't have to grow (or shrink) the whole page around it.
class _ProjectCompletionPane extends StatelessWidget {
  const _ProjectCompletionPane({required this.completions});

  final List<ProjectCompletion> completions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NocturneSectionLabel('PROJECT COMPLETION'),
        const SizedBox(height: 8),
        if (completions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No active projects yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            // Sized to its content up to a cap, rather than always
            // reserving a fixed height — a couple of projects don't leave a
            // slab of dead space, and once there are enough to exceed the
            // cap this becomes a real, independent scroll view (its own
            // Scrollable, distinct from the page's) instead of growing the
            // page around it.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 11.2),
                itemCount: completions.length,
                itemBuilder: (context, i) =>
                    _ProjectCompletionRow(completion: completions[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProjectCompletionRow extends StatelessWidget {
  const _ProjectCompletionRow({required this.completion});

  final ProjectCompletion completion;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    final project = completion.project;
    final fraction = completion.fraction;
    final color = accentPalette[project.colorIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              project.name,
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          if (fraction == null)
            Text(
              'No tasks yet',
              style: TextStyle(fontSize: 12, color: tokens.neutral500),
            )
          else ...[
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 6,
                  backgroundColor: tokens.neutral800,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 36,
              child: Text(
                '${(fraction * 100).round()}%',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
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

    final ring = SizedBox(
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
    );
    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RingLegendRow(color: context.nocturneAccent, label: 'Active', value: active),
        const SizedBox(height: 10),
        _RingLegendRow(color: NocturnePriority.high, label: 'Overdue', value: overdue),
        const SizedBox(height: 10),
        _RingLegendRow(color: NocturneStatus.done, label: 'Completed', value: completed),
      ],
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.8),
        // The ring is a fixed 88px plus a 20px gap, so a Row needs
        // ~220px before the legend has enough room left to show its
        // values without overflowing — below that, stack instead.
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 220) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: ring),
                  const SizedBox(height: 16.8),
                  legend,
                ],
              );
            }
            return Row(
              children: [
                ring,
                const SizedBox(width: 20),
                Expanded(child: legend),
              ],
            );
          },
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
/// Tapping it (when it belongs to a project) opens that project with the
/// task scrolled to and highlighted — see [DashboardScreen.onOpenTask].
class _OverdueTaskRow extends StatelessWidget {
  const _OverdueTaskRow({
    required this.task,
    required this.project,
    required this.dateFormat,
    required this.onOpenTask,
  });

  final Task task;
  final Project? project;
  final DateFormatOption dateFormat;
  final void Function(String projectId, String taskId, BuildContext rowContext)
  onOpenTask;

  @override
  Widget build(BuildContext context) {
    final project = this.project;
    final tokens = context.nocturne;
    final content = Padding(
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
                            : accentPalette[project.colorIndex],
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

    if (project == null) return content;
    return Builder(
      builder: (rowContext) => InkWell(
        onTap: () => onOpenTask(project.id, task.id, rowContext),
        child: content,
      ),
    );
  }
}
