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
const _weekdayLabels = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
DateTime _weekStartOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

enum _CalendarView { week, month }

/// A full calendar — Month for an overview of everything on the books,
/// Week to hyperfocus on the next 7 days. Every task with a due date shows
/// as a bar on its day(s): a multi-day task draws one continuous bar across
/// its span (rounded caps only at its true start/end), and tasks landing on
/// the same days stack into their own lanes rather than overlapping. The
/// grid always fills the screen's full height, even on a quiet week.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({
    super.key,
    required this.onDaySelected,
    required this.onOpenTask,
  });

  final ValueChanged<DateTime> onDaySelected;

  /// Opens a task's home project, scrolled to and highlighting that task —
  /// same destination as tapping it from the Dashboard's attention list.
  final void Function(String projectId, String taskId, BuildContext rowContext)
  onOpenTask;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _anchor = _dateOnly(DateTime.now());
  _CalendarView _view = _CalendarView.month;

  void _step(int delta) {
    setState(() {
      _anchor = _view == _CalendarView.month
          ? DateTime(_anchor.year, _anchor.month + delta, 1)
          : _anchor.add(Duration(days: 7 * delta));
    });
  }

  void _goToToday() => setState(() => _anchor = _dateOnly(DateTime.now()));

  /// A task filed under a project opens that project, scrolled to it; an
  /// unfiled task has no project to open, so it falls back to the Day view
  /// instead — same as tapping its due date used to do.
  void _handleTaskTap(Task task, BuildContext rowContext) {
    final projectId = task.projectId;
    if (projectId != null) {
      widget.onOpenTask(projectId, task.id, rowContext);
    } else if (task.dueDate != null) {
      widget.onDaySelected(task.dueDate!);
    }
  }

  String get _headerLabel {
    if (_view == _CalendarView.month) {
      return '${_monthNames[_anchor.month - 1]} ${_anchor.year}';
    }
    final start = _weekStartOf(_anchor);
    final end = start.add(const Duration(days: 6));
    final startLabel =
        '${_monthNames[start.month - 1].substring(0, 3)} ${start.day}';
    final endLabel = start.month == end.month
        ? '${end.day}'
        : '${_monthNames[end.month - 1].substring(0, 3)} ${end.day}';
    return '$startLabel – $endLabel, ${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    final tasks = ref.watch(tasksProvider);
    final projects = ref.watch(projectsProvider);
    final projectsById = {for (final p in projects) p.id: p};
    final today = DateTime.now();

    final firstOfMonth = DateTime(_anchor.year, _anchor.month, 1);
    final gridStart = firstOfMonth.subtract(
      Duration(days: firstOfMonth.weekday - 1),
    );

    return Padding(
      padding: const EdgeInsets.all(16.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              NocturneButton(
                label: 'Today',
                icon: Icons.today_outlined,
                dense: true,
                onPressed: _goToToday,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                visualDensity: VisualDensity.compact,
                onPressed: () => _step(-1),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                visualDensity: VisualDensity.compact,
                onPressed: () => _step(1),
              ),
              const SizedBox(width: 4),
              Text(_headerLabel, style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              NocturneSegmented<_CalendarView>(
                options: _CalendarView.values,
                value: _view,
                labelBuilder: (v) => v == _CalendarView.week ? 'Week' : 'Month',
                onChanged: (v) => setState(() => _view = v),
              ),
            ],
          ),
          const SizedBox(height: 16.8),
          Row(
            children: [
              for (final label in _weekdayLabels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: tokens.neutral500),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.neutral800),
              ),
              clipBehavior: Clip.antiAlias,
              child: _view == _CalendarView.month
                  ? Column(
                      children: [
                        for (var week = 0; week < 6; week++)
                          Expanded(
                            child: _WeekRow(
                              rowStart: gridStart.add(Duration(days: week * 7)),
                              month: _anchor,
                              today: today,
                              tasks: tasks,
                              projectsById: projectsById,
                              onDayTap: widget.onDaySelected,
                              onTaskTap: _handleTaskTap,
                              showTopBorder: week != 0,
                            ),
                          ),
                      ],
                    )
                  : _WeekRow(
                      rowStart: _weekStartOf(_anchor),
                      month: _anchor,
                      today: today,
                      tasks: tasks,
                      projectsById: projectsById,
                      onDayTap: widget.onDaySelected,
                      onTaskTap: _handleTaskTap,
                      dimOutOfRangeDays: false,
                      showTopBorder: false,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One week's worth of the grid: a strip of day numbers, then every lane of
/// task bars active that week, stacked below it and scrolling locally if
/// there isn't room for all of them within the row's share of the screen.
class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.rowStart,
    required this.month,
    required this.today,
    required this.tasks,
    required this.projectsById,
    required this.onDayTap,
    required this.onTaskTap,
    this.dimOutOfRangeDays = true,
    this.showTopBorder = true,
  });

  final DateTime rowStart;
  final DateTime month;
  final DateTime today;
  final List<Task> tasks;
  final Map<String, Project> projectsById;
  final ValueChanged<DateTime> onDayTap;
  final void Function(Task task, BuildContext rowContext) onTaskTap;
  final bool dimOutOfRangeDays;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    final rowEnd = rowStart.add(const Duration(days: 6));
    final lanes = _computeLanes(tasks, rowStart, rowEnd);

    return Container(
      decoration: BoxDecoration(
        border: showTopBorder
            ? Border(top: BorderSide(color: tokens.divider))
            : null,
      ),
      child: Stack(
        children: [
          // A background+divider layer sized to the full row, independent
          // of the day-number/lane content layered on top — so weekend and
          // next-month shading, and the lines between days, run the row's
          // whole height rather than just behind the day numbers.
          Positioned.fill(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _DayCellBackground(
                      inCurrentMonth: !dimOutOfRangeDays ||
                          rowStart.add(Duration(days: i)).month ==
                              month.month,
                      isWeekend: i == 5 || i == 6,
                      showDivider: i < 6,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: _DayNumber(
                          date: rowStart.add(Duration(days: i)),
                          active: !dimOutOfRangeDays ||
                              rowStart.add(Duration(days: i)).month ==
                                  month.month,
                          isToday: _isSameDay(
                            rowStart.add(Duration(days: i)),
                            today,
                          ),
                          onTap: () =>
                              onDayTap(rowStart.add(Duration(days: i))),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final lane in lanes) ...[
                          _LaneRow(
                            lane: lane,
                            today: today,
                            projectsById: projectsById,
                            onTaskTap: onTaskTap,
                          ),
                          const SizedBox(height: 3),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One day column's full-height backdrop: shades weekends and days outside
/// the month being viewed, and draws the dividing line to its right.
class _DayCellBackground extends StatelessWidget {
  const _DayCellBackground({
    required this.inCurrentMonth,
    required this.isWeekend,
    required this.showDivider,
  });

  final bool inCurrentMonth;
  final bool isWeekend;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    final Color? bg = !inCurrentMonth
        ? Colors.black.withValues(alpha: 0.18)
        : (isWeekend ? tokens.neutral700.withValues(alpha: 0.32) : null);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: showDivider
            ? Border(right: BorderSide(color: tokens.divider))
            : null,
      ),
    );
  }
}

class _DayNumber extends StatelessWidget {
  const _DayNumber({
    required this.date,
    required this.active,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final bool active;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    final accent = context.nocturneAccent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Center(
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? accent : null,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                color: isToday
                    ? Colors.white
                    : (active ? tokens.neutral200 : tokens.neutral600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One stacking lane's worth of columns: bars that fall in this lane,
/// spanning the week's columns they cover, with equal-width empty slots
/// filling the rest so every lane lines up with the day-number row above.
class _LaneRow extends StatelessWidget {
  const _LaneRow({
    required this.lane,
    required this.today,
    required this.projectsById,
    required this.onTaskTap,
  });

  final List<_BarPlacement> lane;
  final DateTime today;
  final Map<String, Project> projectsById;
  final void Function(Task task, BuildContext rowContext) onTaskTap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    var col = 0;
    for (final placement in lane) {
      if (placement.colStart > col) {
        children.add(
          Expanded(flex: placement.colStart - col, child: const SizedBox()),
        );
      }
      final span = placement.colEnd - placement.colStart + 1;
      children.add(
        Expanded(
          flex: span,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            child: _TaskBar(
              placement: placement,
              today: today,
              project: projectsById[placement.task.projectId],
              onTap: (ctx) => onTaskTap(placement.task, ctx),
            ),
          ),
        ),
      );
      col = placement.colEnd + 1;
    }
    if (col < 7) {
      children.add(Expanded(flex: 7 - col, child: const SizedBox()));
    }
    return Row(children: children);
  }
}

class _TaskBar extends StatelessWidget {
  const _TaskBar({
    required this.placement,
    required this.today,
    required this.project,
    required this.onTap,
  });

  final _BarPlacement placement;
  final DateTime today;
  final Project? project;
  final void Function(BuildContext rowContext) onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    final accent = context.nocturneAccent;
    final task = placement.task;

    final overallEnd = task.dueDateEnd ?? task.dueDate!;
    final isOverdue =
        !task.isChecked && _dateOnly(overallEnd).isBefore(_dateOnly(today));

    // Matches the app's own buttons (see NocturneButton's primary variant):
    // a tinted, outlined pill rather than a flat color swatch — just with
    // the status color swapped in for the usual accent.
    final statusColor = task.isChecked
        ? tokens.neutral500
        : (isOverdue ? NocturnePriority.high : accent);
    // Blended onto the opaque surface color (rather than left translucent)
    // so the grid lines and shading behind a bar never show through it.
    final bg = Color.alphaBlend(statusColor.withValues(alpha: 0.12), tokens.surface);
    final fg = statusColor;
    final border = statusColor.withValues(alpha: 0.6);

    final priorityColor = switch (task.priority) {
      TaskPriority.high => NocturnePriority.high,
      TaskPriority.med => NocturnePriority.med,
      TaskPriority.low => NocturnePriority.low,
      TaskPriority.none => null,
    };
    final originColor =
        project != null ? accentPalette[project!.colorIndex] : tokens.neutral500;
    final originLabel = project != null ? project!.name : 'Unfiled';

    final radius = BorderRadius.horizontal(
      left: placement.isRangeStart ? const Radius.circular(11) : Radius.zero,
      right: placement.isRangeEnd ? const Radius.circular(11) : Radius.zero,
    );

    return SizedBox(
      height: 22,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Row(
              children: [
                if (isOverdue) ...[
                  const Text(
                    '!',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFF3B30),
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 3),
                ],
                if (priorityColor != null) ...[
                  Icon(Icons.flag, size: 10, color: priorityColor),
                  const SizedBox(width: 3),
                ],
                Icon(Icons.folder, size: 11, color: originColor),
                const SizedBox(width: 3),
                Expanded(
                  flex: 2,
                  child: Text(
                    originLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: originColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: fg,
                      decoration:
                          task.isChecked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (task.hasSubtasks) ...[
                  const SizedBox(width: 3),
                  Icon(
                    Icons.checklist,
                    size: 11,
                    color: fg.withValues(alpha: 0.85),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Where one task's bar lands within a single week row: which columns
/// (0-6) it spans in *this* row, and whether those ends are the task's
/// true start/end (vs. just this row's edge, because the task continues
/// into the next or previous week) — only a true end gets a rounded cap.
class _BarPlacement {
  _BarPlacement({
    required this.task,
    required this.colStart,
    required this.colEnd,
    required this.isRangeStart,
    required this.isRangeEnd,
  });

  final Task task;
  final int colStart;
  final int colEnd;
  final bool isRangeStart;
  final bool isRangeEnd;
}

/// Greedily assigns each task active during [rowStart]..[rowEnd] to the
/// first lane whose existing bars don't overlap its column span — longer
/// bars are placed first so a multi-day task claims a stable lane rather
/// than getting split around single-day tasks placed ahead of it.
List<List<_BarPlacement>> _computeLanes(
  List<Task> tasks,
  DateTime rowStart,
  DateTime rowEnd,
) {
  final items = <_BarPlacement>[];
  for (final task in tasks) {
    if (task.dueDate == null) continue;
    final start = _dateOnly(task.dueDate!);
    final end = task.dueDateEnd == null ? start : _dateOnly(task.dueDateEnd!);
    if (end.isBefore(rowStart) || start.isAfter(rowEnd)) continue;

    final segStart = start.isBefore(rowStart) ? rowStart : start;
    final segEnd = end.isAfter(rowEnd) ? rowEnd : end;
    items.add(
      _BarPlacement(
        task: task,
        colStart: segStart.difference(rowStart).inDays,
        colEnd: segEnd.difference(rowStart).inDays,
        isRangeStart: _isSameDay(segStart, start),
        isRangeEnd: _isSameDay(segEnd, end),
      ),
    );
  }

  items.sort((a, b) {
    final spanDiff = (b.colEnd - b.colStart) - (a.colEnd - a.colStart);
    if (spanDiff != 0) return spanDiff;
    if (a.colStart != b.colStart) return a.colStart.compareTo(b.colStart);
    return a.task.title.compareTo(b.task.title);
  });

  final lanes = <List<_BarPlacement>>[];
  for (final item in items) {
    var placed = false;
    for (final lane in lanes) {
      final overlaps = lane.any(
        (p) => item.colStart <= p.colEnd && item.colEnd >= p.colStart,
      );
      if (!overlaps) {
        lane.add(item);
        placed = true;
        break;
      }
    }
    if (!placed) lanes.add([item]);
  }
  for (final lane in lanes) {
    lane.sort((a, b) => a.colStart.compareTo(b.colStart));
  }
  return lanes;
}
