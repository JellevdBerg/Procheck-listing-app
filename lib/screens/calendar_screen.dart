import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../theme/nocturne_theme.dart';
import '../widgets/create_task_sheet.dart';
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

  bool _taskmasterOn = false;
  DateTime? _dragAnchor;
  DateTime? _dragCursor;
  Timer? _edgeAdvanceTimer;
  DateTime? _edgeAdvanceTarget;

  @override
  void dispose() {
    _edgeAdvanceTimer?.cancel();
    super.dispose();
  }

  void _step(int delta) {
    setState(() {
      _anchor = _view == _CalendarView.month
          ? DateTime(_anchor.year, _anchor.month + delta, 1)
          : _anchor.add(Duration(days: 7 * delta));
    });
  }

  void _goToToday() => setState(() => _anchor = _dateOnly(DateTime.now()));

  void _handleDragStart(DateTime day) {
    setState(() {
      _dragAnchor = day;
      _dragCursor = day;
    });
  }

  /// Tracks the drag cursor, and — only in Month view, only once the pointer
  /// has settled on a dimmed leading/trailing day for a moment — auto-steps
  /// the month so a drag can extend a task across a month boundary without
  /// the user having to let go and start over.
  void _handleDragUpdate(DateTime hovered) {
    setState(() => _dragCursor = hovered);
    if (_view != _CalendarView.month) return;

    final firstOfMonth = DateTime(_anchor.year, _anchor.month, 1);
    final isNext = hovered.isAfter(
      DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0),
    );
    final isPrev = hovered.isBefore(firstOfMonth);

    if (!isNext && !isPrev) {
      _edgeAdvanceTimer?.cancel();
      _edgeAdvanceTarget = null;
      return;
    }
    if (_edgeAdvanceTarget != null && _isSameDay(_edgeAdvanceTarget!, hovered)) {
      return;
    }
    _edgeAdvanceTimer?.cancel();
    _edgeAdvanceTarget = hovered;
    _edgeAdvanceTimer = Timer(const Duration(milliseconds: 650), () {
      setState(() {
        _anchor = DateTime(_anchor.year, _anchor.month + (isNext ? 1 : -1), 1);
        _dragCursor = hovered;
      });
    });
  }

  Future<void> _handleDragEnd() async {
    _edgeAdvanceTimer?.cancel();
    _edgeAdvanceTarget = null;
    final anchor = _dragAnchor;
    final cursor = _dragCursor;
    setState(() {
      _dragAnchor = null;
      _dragCursor = null;
    });
    if (anchor == null || cursor == null) return;
    final start = anchor.isBefore(cursor) ? anchor : cursor;
    final end = anchor.isBefore(cursor) ? cursor : anchor;
    await _createTaskForRange(start, end);
  }

  void _cancelDrag() {
    _edgeAdvanceTimer?.cancel();
    _edgeAdvanceTarget = null;
    setState(() {
      _dragAnchor = null;
      _dragCursor = null;
    });
  }

  /// Opens the normal new-task sheet (title/project only — it never asks
  /// about a due date) and, once a task comes back, sets its due date to
  /// the range just drawn on the calendar.
  Future<void> _createTaskForRange(DateTime start, DateTime end) async {
    final task = await showCreateTaskSheet(context);
    if (task == null || !mounted) return;
    ref
        .read(tasksProvider.notifier)
        .setTaskDueDate(
          task.id,
          start,
          dueDateEnd: _isSameDay(start, end) ? null : end,
        );
  }

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

    final dragRange = (_dragAnchor != null && _dragCursor != null)
        ? (
            _dragAnchor!.isBefore(_dragCursor!) ? _dragAnchor! : _dragCursor!,
            _dragAnchor!.isBefore(_dragCursor!) ? _dragCursor! : _dragAnchor!,
          )
        : null;
    void onTaskDelete(Task task) =>
        ref.read(tasksProvider.notifier).deleteTask(task.id);

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
                variant: NocturneButtonVariant.primary,
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
              Tooltip(
                message: _taskmasterOn
                    ? 'Click or drag a day to add a task there'
                    : 'Turn on to click or drag on the calendar to add tasks',
                child: NocturneButton(
                  label: 'Taskmaster',
                  icon: Icons.touch_app_outlined,
                  dense: true,
                  variant: _taskmasterOn
                      ? NocturneButtonVariant.primary
                      : NocturneButtonVariant.secondary,
                  onPressed: () {
                    _cancelDrag();
                    setState(() => _taskmasterOn = !_taskmasterOn);
                  },
                ),
              ),
              const SizedBox(width: 8),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gridSize = constraints.biggest;
                final rowsCount = _view == _CalendarView.month ? 6 : 1;
                final weekStart = _view == _CalendarView.month
                    ? gridStart
                    : _weekStartOf(_anchor);

                DateTime dateAt(Offset local) {
                  final col = (local.dx / gridSize.width * 7)
                      .floor()
                      .clamp(0, 6);
                  final row = (local.dy / gridSize.height * rowsCount)
                      .floor()
                      .clamp(0, rowsCount - 1);
                  return weekStart.add(Duration(days: row * 7 + col));
                }

                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: _taskmasterOn
                      ? (d) => _handleDragStart(dateAt(d.localPosition))
                      : null,
                  onPanUpdate: _taskmasterOn
                      ? (d) => _handleDragUpdate(dateAt(d.localPosition))
                      : null,
                  onPanEnd: _taskmasterOn ? (_) => _handleDragEnd() : null,
                  onPanCancel: _taskmasterOn ? _cancelDrag : null,
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
                                    rowStart: gridStart.add(
                                      Duration(days: week * 7),
                                    ),
                                    month: _anchor,
                                    today: today,
                                    tasks: tasks,
                                    projectsById: projectsById,
                                    onDayTap: _taskmasterOn
                                        ? (day) =>
                                            _createTaskForRange(day, day)
                                        : widget.onDaySelected,
                                    onTaskTap: _handleTaskTap,
                                    showTopBorder: week != 0,
                                    maxVisibleLanes: 3,
                                    taskmasterOn: _taskmasterOn,
                                    onTaskDelete: onTaskDelete,
                                    dragRange: dragRange,
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
                            onDayTap: _taskmasterOn
                                ? (day) => _createTaskForRange(day, day)
                                : widget.onDaySelected,
                            onTaskTap: _handleTaskTap,
                            dimOutOfRangeDays: false,
                            showTopBorder: false,
                            taskmasterOn: _taskmasterOn,
                            onTaskDelete: onTaskDelete,
                            dragRange: dragRange,
                          ),
                  ),
                );
              },
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
    this.maxVisibleLanes,
    this.taskmasterOn = false,
    required this.onTaskDelete,
    this.dragRange,
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

  /// Caps how many lanes of bars this row draws before the rest collapse
  /// into a per-day "+N" overflow chip — null means show every lane
  /// (scrolling locally if they don't fit), used by the Week view.
  final int? maxVisibleLanes;

  final bool taskmasterOn;
  final void Function(Task task) onTaskDelete;

  /// The inclusive [start, end] of a Taskmaster drag-in-progress, if any —
  /// days within it get a highlight tint.
  final (DateTime, DateTime)? dragRange;

  /// The row's own slice of an in-progress Taskmaster drag — null if the
  /// drag (if any) doesn't touch this week at all. Mirrors how a real
  /// multi-week task gets clipped to each row in [_computeLanes]: a true
  /// cap only at the actual drag start/end, square where it continues past
  /// this row's edge.
  ({int colStart, int colEnd, bool roundLeft, bool roundRight})?
  _dragSpanForRow() {
    final range = dragRange;
    if (range == null) return null;
    final rowEnd = rowStart.add(const Duration(days: 6));
    final start = range.$1;
    final end = range.$2;
    if (end.isBefore(rowStart) || start.isAfter(rowEnd)) return null;
    final segStart = start.isBefore(rowStart) ? rowStart : start;
    final segEnd = end.isAfter(rowEnd) ? rowEnd : end;
    return (
      colStart: segStart.difference(rowStart).inDays,
      colEnd: segEnd.difference(rowStart).inDays,
      roundLeft: _isSameDay(segStart, start),
      roundRight: _isSameDay(segEnd, end),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    final rowEnd = rowStart.add(const Duration(days: 6));
    final lanes = _computeLanes(tasks, rowStart, rowEnd);

    final cap = maxVisibleLanes;
    final overflow = cap != null && lanes.length > cap;
    // When overflowing, one of the cap slots is spent on the "+N more"
    // chip instead of a lane, so the row's total height never grows past
    // what the non-overflowing (exactly-cap) case already needs.
    final visibleLanes = overflow ? lanes.sublist(0, cap - 1) : lanes;
    final hiddenLanes =
        overflow ? lanes.sublist(cap - 1) : const <List<_BarPlacement>>[];
    final overflowCounts = List<int>.generate(
      7,
      (day) => hiddenLanes
          .where((lane) => lane.any((p) => p.colStart <= day && p.colEnd >= day))
          .length,
    );
    final dragSpan = _dragSpanForRow();

    return Container(
      decoration: BoxDecoration(
        border: showTopBorder
            ? Border(top: BorderSide(color: tokens.divider))
            : null,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final colWidth = constraints.maxWidth / 7;
          return Stack(
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
                          isDragSelected: dragRange != null &&
                              !rowStart
                                  .add(Duration(days: i))
                                  .isBefore(dragRange!.$1) &&
                              !rowStart
                                  .add(Duration(days: i))
                                  .isAfter(dragRange!.$2),
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
                            for (final lane in visibleLanes) ...[
                              _LaneRow(
                                lane: lane,
                                today: today,
                                projectsById: projectsById,
                                onTaskTap: onTaskTap,
                                taskmasterOn: taskmasterOn,
                                onTaskDelete: onTaskDelete,
                              ),
                              const SizedBox(height: 3),
                            ],
                            if (overflow)
                              _OverflowRow(
                                rowStart: rowStart,
                                counts: overflowCounts,
                                tasks: tasks,
                                projectsById: projectsById,
                                onTaskTap: onTaskTap,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (dragSpan != null)
                AnimatedPositioned(
                  key: const ValueKey('drag-ghost'),
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  left: dragSpan.colStart * colWidth + 2,
                  width:
                      (dragSpan.colEnd - dragSpan.colStart + 1) * colWidth -
                      4,
                  top: 35,
                  height: 27,
                  child: IgnorePointer(
                    child: _DragGhostBar(
                      roundLeft: dragSpan.roundLeft,
                      roundRight: dragSpan.roundRight,
                    ),
                  ),
                ),
            ],
          );
        },
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
    this.isDragSelected = false,
  });

  final bool inCurrentMonth;
  final bool isWeekend;
  final bool showDivider;
  final bool isDragSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    final accent = context.nocturneAccent;

    Widget fill;
    if (!inCurrentMonth) {
      fill = DecoratedBox(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18)),
      );
    } else if (isWeekend) {
      // neutral700 at 0.4 reads clearly against dark mode's near-black
      // surface, but in light mode it's a pale lavender on a near-white
      // one — nearly invisible — so light mode gets a darker, more opaque
      // line instead. neutral500 is the one step in the ramp defined
      // identically in both palettes, which keeps this a deliberate
      // one-off rather than a tweak to a token other widgets also read.
      final isLight = Theme.of(context).brightness == Brightness.light;
      // CustomPaint draws straight onto the ambient canvas with no clip of
      // its own, and the stripe lines intentionally run past this cell's
      // right edge — without ClipRect that tail paints straight over
      // whatever cell comes next instead of stopping at this one's border.
      fill = ClipRect(
        child: CustomPaint(
          painter: _DiagonalStripesPainter(
            color: isLight
                ? tokens.neutral500.withValues(alpha: 0.45)
                : tokens.neutral700.withValues(alpha: 0.4),
          ),
        ),
      );
    } else {
      fill = const SizedBox.expand();
    }

    // The divider is painted as a foreground decoration so it stays on
    // top of the weekend stripes instead of being drawn underneath them.
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(right: BorderSide(color: tokens.divider))
            : null,
      ),
      position: DecorationPosition.foreground,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            fill,
            if (isDragSelected)
              DecoratedBox(
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.22)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Paints evenly spaced 45° lines across its full size — used for the
/// weekend columns instead of a flat tint so they read as "blocked off"
/// rather than just a different shade.
class _DiagonalStripesPainter extends CustomPainter {
  _DiagonalStripesPainter({required this.color});

  final Color color;

  static const _spacing = 7.0;
  static const _strokeWidth = 1.2;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _strokeWidth;
    final span = size.width + size.height;
    for (double x = -size.height; x < span; x += _spacing) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DiagonalStripesPainter oldDelegate) =>
      oldDelegate.color != color;
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
    required this.taskmasterOn,
    required this.onTaskDelete,
  });

  final List<_BarPlacement> lane;
  final DateTime today;
  final Map<String, Project> projectsById;
  final void Function(Task task, BuildContext rowContext) onTaskTap;
  final bool taskmasterOn;
  final void Function(Task task) onTaskDelete;

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
      // Saturday/Sunday are always this row's last two columns (5, 6), so a
      // placement can cross at most once: a weekday run (<=4) followed by
      // its own weekend run — never the other way round within one row.
      final crossesWeekend = placement.colStart <= 4 && placement.colEnd >= 5;
      children.add(
        Expanded(
          flex: span,
          child: crossesWeekend
              ? _buildCrossingBar(placement)
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 1,
                  ),
                  child: _TaskBar(
                    placement: placement,
                    today: today,
                    project: projectsById[placement.task.projectId],
                    onTap: (ctx) => onTaskTap(placement.task, ctx),
                    taskmasterOn: taskmasterOn,
                    onDelete: () => onTaskDelete(placement.task),
                    roundLeft: placement.isRangeStart,
                    roundRight: placement.isRangeEnd,
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

  /// Splits a placement that runs from a weekday into its own weekend into
  /// two touching segments — a normal pill for the weekday run and a slim
  /// connector for the weekend run — so the bar visually continues through
  /// the weekend rather than reading as a separate, disconnected task.
  Widget _buildCrossingBar(_BarPlacement placement) {
    final weekdaySpan = 4 - placement.colStart + 1;
    final weekendSpan = placement.colEnd - 5 + 1;
    final project = projectsById[placement.task.projectId];
    return Row(
      children: [
        Expanded(
          flex: weekdaySpan,
          child: Padding(
            padding: const EdgeInsets.only(left: 2, top: 1, bottom: 1),
            child: _TaskBar(
              placement: placement,
              today: today,
              project: project,
              onTap: (ctx) => onTaskTap(placement.task, ctx),
              taskmasterOn: taskmasterOn,
              onDelete: () => onTaskDelete(placement.task),
              roundLeft: placement.isRangeStart,
              roundRight: false,
            ),
          ),
        ),
        Expanded(
          flex: weekendSpan,
          child: Padding(
            padding: const EdgeInsets.only(right: 2, top: 1, bottom: 1),
            child: _TaskBar(
              placement: placement,
              today: today,
              project: project,
              onTap: (ctx) => onTaskTap(placement.task, ctx),
              taskmasterOn: taskmasterOn,
              onDelete: () => onTaskDelete(placement.task),
              roundLeft: false,
              roundRight: placement.isRangeEnd,
              weekend: true,
            ),
          ),
        ),
      ],
    );
  }
}

/// The row below a capped set of lanes: one cell per day showing a "+N"
/// chip when that day has tasks hidden beyond the visible lanes — tapping
/// it opens the full list of that day's tasks.
class _OverflowRow extends StatelessWidget {
  const _OverflowRow({
    required this.rowStart,
    required this.counts,
    required this.tasks,
    required this.projectsById,
    required this.onTaskTap,
  });

  final DateTime rowStart;
  final List<int> counts;
  final List<Task> tasks;
  final Map<String, Project> projectsById;
  final void Function(Task task, BuildContext rowContext) onTaskTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: counts[i] <= 0
                  ? const SizedBox()
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            final day = rowStart.add(Duration(days: i));
                            _showDayTasksDialog(
                              context,
                              day,
                              _tasksOnDay(tasks, day),
                              projectsById,
                              onTaskTap,
                            );
                          },
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '+${counts[i]} more',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: tokens.neutral500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

/// Every task active on [day], unchecked first and then by title — the
/// order shown in the overflow popup.
List<Task> _tasksOnDay(List<Task> tasks, DateTime day) {
  final result = tasks.where((task) {
    if (task.dueDate == null) return false;
    final start = _dateOnly(task.dueDate!);
    final end = task.dueDateEnd == null ? start : _dateOnly(task.dueDateEnd!);
    return !day.isBefore(start) && !day.isAfter(end);
  }).toList();
  result.sort((a, b) {
    if (a.isChecked != b.isChecked) return a.isChecked ? 1 : -1;
    return a.title.compareTo(b.title);
  });
  return result;
}

void _showDayTasksDialog(
  BuildContext context,
  DateTime day,
  List<Task> dayTasks,
  Map<String, Project> projectsById,
  void Function(Task task, BuildContext rowContext) onTaskTap,
) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final tokens = dialogContext.nocturne;
      return Dialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_monthNames[day.month - 1]} ${day.day}, ${day.year}',
                        style: Theme.of(dialogContext).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: dayTasks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, index) {
                      final task = dayTasks[index];
                      final placement = _BarPlacement(
                        task: task,
                        colStart: 0,
                        colEnd: 0,
                        isRangeStart: true,
                        isRangeEnd: true,
                      );
                      return _TaskBar(
                        placement: placement,
                        today: DateTime.now(),
                        project: projectsById[task.projectId],
                        onTap: (_) {
                          Navigator.of(dialogContext).pop();
                          // Hands back the calling page's context, not the
                          // dialog's — that one unmounts the moment it pops.
                          onTaskTap(task, context);
                        },
                        taskmasterOn: false,
                        onDelete: () {},
                        roundLeft: true,
                        roundRight: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _TaskBar extends StatefulWidget {
  const _TaskBar({
    required this.placement,
    required this.today,
    required this.project,
    required this.onTap,
    required this.taskmasterOn,
    required this.onDelete,
    required this.roundLeft,
    required this.roundRight,
    this.weekend = false,
  });

  final _BarPlacement placement;
  final DateTime today;
  final Project? project;
  final void Function(BuildContext rowContext) onTap;
  final bool taskmasterOn;
  final VoidCallback onDelete;

  /// Whether this segment's left/right edge gets the pill's rounded cap —
  /// false at a seam where the bar continues into an adjoining segment
  /// (its own weekend run, in the same row) rather than truly starting or
  /// ending there.
  final bool roundLeft;
  final bool roundRight;

  /// Renders as a slim, text-free connector instead of the normal pill —
  /// the Saturday/Sunday portion of a bar that continues through the
  /// weekend from a weekday run earlier in the same row.
  final bool weekend;

  @override
  State<_TaskBar> createState() => _TaskBarState();
}

class _TaskBarState extends State<_TaskBar> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final placement = widget.placement;
    final project = widget.project;
    final tokens = context.nocturne;
    final accent = context.nocturneAccent;
    final task = placement.task;

    final overallEnd = task.dueDateEnd ?? task.dueDate!;
    final isOverdue = !task.isChecked &&
        _dateOnly(overallEnd).isBefore(_dateOnly(widget.today));

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
        project != null ? accentPalette[project.colorIndex] : tokens.neutral500;
    final originLabel = project != null ? project.name : 'Unfiled';

    final radius = BorderRadius.horizontal(
      left: widget.roundLeft ? const Radius.circular(13) : Radius.zero,
      right: widget.roundRight ? const Radius.circular(13) : Radius.zero,
    );

    if (widget.weekend) {
      // A minimal connector rather than the full pill: just enough to read
      // as "this task keeps going" through the weekend, without trying to
      // cram the full label into two narrow columns. No Center/Align here
      // — the surrounding Padding already hands this tight width (the
      // column's full width), and the lane Row centers it vertically
      // against the full-height weekday segment beside it.
      return SizedBox(
        height: 8,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: () => widget.onTap(context)),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: SizedBox(
      height: 27,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onTap(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Row(
              children: [
                if (isOverdue) ...[
                  const Text(
                    '!',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFF3B30),
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (priorityColor != null) ...[
                  Icon(Icons.flag, size: 12, color: priorityColor),
                  const SizedBox(width: 4),
                ],
                Icon(Icons.folder, size: 13, color: originColor),
                const SizedBox(width: 4),
                Expanded(
                  flex: 2,
                  child: Text(
                    originLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: originColor,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  flex: 3,
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: fg,
                      decoration:
                          task.isChecked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (task.hasSubtasks) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.checklist,
                    size: 13,
                    color: fg.withValues(alpha: 0.85),
                  ),
                ],
                if (widget.taskmasterOn && _hovering) ...[
                  const SizedBox(width: 4),
                  _DeleteDot(onTap: widget.onDelete),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

/// The small "x" that appears at a bar's trailing edge, in Taskmaster
/// mode, once the pointer hovers it — a quick way to delete the task
/// without opening it first.
class _DeleteDot extends StatelessWidget {
  const _DeleteDot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFF3B30).withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(2),
          child: Icon(Icons.close, size: 12, color: Color(0xFFFF3B30)),
        ),
      ),
    );
  }
}

/// A live preview of the task being drawn by a Taskmaster drag — its
/// position/size track the pointer via [_WeekRow]'s own rebuilds (animated
/// by the `AnimatedPositioned` that places it), while this widget adds a
/// quick fade/scale-in of its own so the very first appearance also reads
/// as "growing in", not just a pop.
class _DragGhostBar extends StatelessWidget {
  const _DragGhostBar({required this.roundLeft, required this.roundRight});

  final bool roundLeft;
  final bool roundRight;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    final accent = context.nocturneAccent;
    final radius = BorderRadius.horizontal(
      left: roundLeft ? const Radius.circular(13) : Radius.zero,
      right: roundRight ? const Radius.circular(13) : Radius.zero,
    );
    final bg = Color.alphaBlend(accent.withValues(alpha: 0.18), tokens.surface);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      builder: (context, scale, child) =>
          Opacity(opacity: scale, child: child),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: Border.all(color: accent.withValues(alpha: 0.8), width: 1.4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Row(
            children: [
              Icon(Icons.add, size: 13, color: accent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'New task',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ],
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
