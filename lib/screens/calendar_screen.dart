import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
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
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// A full month grid — every task with a due date shows as a bar spanning
/// the day(s) it's due, the way the sidebar's mini calendar used to (see
/// [MiniCalendar]) but with room to actually read what's on each day. A
/// multi-day task draws one continuous bar across its span (rounded caps
/// only at its true start/end), and several tasks landing on the same days
/// stack into their own lanes rather than overlapping.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, required this.onDaySelected});

  final ValueChanged<DateTime> onDaySelected;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _visibleMonth = _dateOnly(
    DateTime(DateTime.now().year, DateTime.now().month, 1),
  );

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
      );
    });
  }

  void _goToToday() {
    setState(() {
      _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    final tasks = ref.watch(tasksProvider);
    final today = DateTime.now();

    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final gridStart = firstOfMonth.subtract(
      Duration(days: firstOfMonth.weekday % 7),
    );

    return Padding(
      padding: const EdgeInsets.all(16.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                visualDensity: VisualDensity.compact,
                onPressed: () => _changeMonth(-1),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                visualDensity: VisualDensity.compact,
                onPressed: () => _changeMonth(1),
              ),
              const Spacer(),
              NocturneButton(
                label: 'Today',
                icon: Icons.today_outlined,
                dense: true,
                onPressed: _goToToday,
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
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var week = 0; week < 6; week++)
                    _WeekRow(
                      rowStart: gridStart.add(Duration(days: week * 7)),
                      month: _visibleMonth,
                      today: today,
                      tasks: tasks,
                      onDayTap: widget.onDaySelected,
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

/// One week's worth of the grid: a strip of day numbers, then every lane of
/// task bars active that week, stacked below it.
class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.rowStart,
    required this.month,
    required this.today,
    required this.tasks,
    required this.onDayTap,
  });

  final DateTime rowStart;
  final DateTime month;
  final DateTime today;
  final List<Task> tasks;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    final rowEnd = rowStart.add(const Duration(days: 6));
    final lanes = _computeLanes(tasks, rowStart, rowEnd);

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.divider)),
      ),
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
                    inCurrentMonth: rowStart.add(Duration(days: i)).month ==
                        month.month,
                    isToday: _isSameDay(
                      rowStart.add(Duration(days: i)),
                      today,
                    ),
                    onTap: () => onDayTap(rowStart.add(Duration(days: i))),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          for (final lane in lanes) ...[
            _LaneRow(lane: lane, today: today, onDayTap: onDayTap),
            const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }
}

class _DayNumber extends StatelessWidget {
  const _DayNumber({
    required this.date,
    required this.inCurrentMonth,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final bool inCurrentMonth;
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
                    : (inCurrentMonth ? tokens.neutral200 : tokens.neutral600),
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
    required this.onDayTap,
  });

  final List<_BarPlacement> lane;
  final DateTime today;
  final ValueChanged<DateTime> onDayTap;

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
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: _TaskBar(
              placement: placement,
              today: today,
              onTap: () => onDayTap(placement.task.dueDate!),
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
    required this.onTap,
  });

  final _BarPlacement placement;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    final accent = context.nocturneAccent;
    final task = placement.task;

    final overallEnd = task.dueDateEnd ?? task.dueDate!;
    final isOverdue =
        !task.isChecked && _dateOnly(overallEnd).isBefore(_dateOnly(today));
    final isMultiDay = task.dueDateEnd != null &&
        !_isSameDay(task.dueDate!, task.dueDateEnd!);

    late final Color bg;
    late final Color fg;
    late final Color? border;
    final icon = task.isChecked ? Icons.check_circle : Icons.circle_outlined;

    if (task.isChecked) {
      bg = tokens.neutral800;
      fg = tokens.neutral500;
      border = null;
    } else if (isOverdue) {
      bg = NocturnePriority.high.withValues(alpha: 0.85);
      fg = Colors.white;
      border = null;
    } else if (isMultiDay) {
      bg = accent;
      fg = Colors.white;
      border = null;
    } else {
      bg = accent.withValues(alpha: 0.14);
      fg = accent;
      border = accent.withValues(alpha: 0.5);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.horizontal(
        left: placement.isRangeStart
            ? const Radius.circular(4)
            : Radius.zero,
        right: placement.isRangeEnd ? const Radius.circular(4) : Radius.zero,
      ),
      child: Container(
        height: 20,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          border: border != null ? Border.all(color: border) : null,
          borderRadius: BorderRadius.horizontal(
            left: placement.isRangeStart
                ? const Radius.circular(4)
                : Radius.zero,
            right: placement.isRangeEnd
                ? const Radius.circular(4)
                : Radius.zero,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: fg,
                  decoration: task.isChecked
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
          ],
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
