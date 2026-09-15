import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import 'wobble_checkbox.dart';

/// A single task row: a checkbox + title that expands in place to reveal
/// its subtasks below and a notes panel beside them. Checking every
/// subtask automatically checks the task, and vice versa.
class TaskTile extends ConsumerStatefulWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onDelete,
    this.autoRemoveWhenChecked = false,
  });

  final Task task;

  /// Called when the delete button is pressed (or, with
  /// [autoRemoveWhenChecked], once checking the task off finishes). The
  /// caller is responsible for actually removing the task — typically
  /// after a removal animation.
  final VoidCallback onDelete;

  /// Standalone (no-project) tasks are meant to be quick one-offs: once
  /// checked off, they remove themselves — but only after the check-off
  /// bounce has had time to play, never instantly.
  final bool autoRemoveWhenChecked;

  @override
  ConsumerState<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends ConsumerState<TaskTile> {
  // Below this width there isn't room for subtasks and notes side by side,
  // so the notes panel stacks underneath instead.
  static const _sideBySideBreakpoint = 480.0;

  bool _expanded = false;
  late final TextEditingController _notesController;
  late final FocusNode _notesFocusNode;
  final _newSubtaskController = TextEditingController();
  Timer? _autoRemoveTimer;

  // Snapshotting the checked flag as a primitive rather than comparing
  // oldWidget.task.isChecked to widget.task.isChecked directly: Task is a
  // mutable Hive object fetched by reference, so toggling it mutates the
  // exact same instance already held by the currently-mounted widget. By
  // the time didUpdateWidget runs, oldWidget.task and widget.task are the
  // identical, already-mutated object — comparing a field on them can never
  // see a "before" value. A bool, being a value type, is copied at the
  // point it's read and stays put regardless of later mutation — but it
  // must be captured eagerly in initState, not via a `late` initializer,
  // since a `late` field would defer that same first read until it's used
  // inside didUpdateWidget, by which point the mutation has already landed.
  bool _lastIsChecked = false;

  @override
  void initState() {
    super.initState();
    _lastIsChecked = widget.task.isChecked;
    _notesController = TextEditingController(text: widget.task.notes ?? '');
    _notesFocusNode = FocusNode()..addListener(_onNotesFocusChange);
  }

  @override
  void didUpdateWidget(covariant TaskTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the field in sync with external changes (e.g. undo elsewhere)
    // without clobbering text the user is actively editing.
    if (!_notesFocusNode.hasFocus &&
        widget.task.notes != oldWidget.task.notes) {
      _notesController.text = widget.task.notes ?? '';
    }

    final wasChecked = _lastIsChecked;
    final isChecked = widget.task.isChecked;
    _lastIsChecked = isChecked;

    if (!widget.autoRemoveWhenChecked) return;
    if (isChecked && !wasChecked) {
      // Let the check-off bounce actually play before this tile is
      // removed out from under it — an instant removal would tear the
      // checkbox down mid-animation and the bounce would never be seen.
      final reduceMotion = ref.read(settingsProvider).reduceMotion;
      if (reduceMotion) {
        widget.onDelete();
      } else {
        _autoRemoveTimer?.cancel();
        _autoRemoveTimer = Timer(WobbleCheckbox.duration, widget.onDelete);
      }
    } else if (!isChecked && wasChecked) {
      _autoRemoveTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _autoRemoveTimer?.cancel();
    _notesFocusNode.removeListener(_onNotesFocusChange);
    _notesFocusNode.dispose();
    _notesController.dispose();
    _newSubtaskController.dispose();
    super.dispose();
  }

  void _onNotesFocusChange() {
    if (!_notesFocusNode.hasFocus) _saveNotes();
  }

  void _saveNotes() {
    final text = _notesController.text.trim();
    ref
        .read(tasksProvider.notifier)
        .setTaskNotes(widget.task.id, text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final notifier = ref.read(tasksProvider.notifier);
    final reduceMotion = ref.watch(settingsProvider).reduceMotion;

    // Once expanded, the notes panel already shows the full text, so the
    // collapsed preview line would just be a duplicate.
    final subtitleParts = <String>[
      if (!_expanded && (task.notes ?? '').trim().isNotEmpty)
        task.notes!.trim(),
      if (task.hasSubtasks)
        '${task.completedSubtaskCount}/${task.subtasks.length} subtasks',
    ];

    return Column(
      children: [
        ListTile(
          onTap: () => setState(() => _expanded = !_expanded),
          leading: WobbleCheckbox(
            value: task.isChecked,
            reduceMotion: reduceMotion,
            onChanged: (_) => notifier.toggleTask(task.id),
          ),
          title: Text(
            task.title,
            style: task.isChecked
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
          subtitle: subtitleParts.isEmpty
              ? null
              : Text(
                  subtitleParts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete task',
                onPressed: widget.onDelete,
              ),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? _ExpandedTaskDetail(
                  task: task,
                  notesController: _notesController,
                  notesFocusNode: _notesFocusNode,
                  newSubtaskController: _newSubtaskController,
                  onAddSubtask: () => _addSubtask(notifier),
                  breakpoint: _sideBySideBreakpoint,
                )
              : const SizedBox(width: double.infinity),
        ),
        const Divider(height: 1),
      ],
    );
  }

  void _addSubtask(TasksNotifier notifier) {
    final title = _newSubtaskController.text.trim();
    if (title.isEmpty) return;
    notifier.addSubtask(widget.task.id, title);
    _newSubtaskController.clear();
  }
}

/// The expanded region of a [TaskTile]: subtasks below the task, with a
/// notes panel that sits to the right when there's room for it and stacks
/// underneath otherwise.
class _ExpandedTaskDetail extends ConsumerWidget {
  const _ExpandedTaskDetail({
    required this.task,
    required this.notesController,
    required this.notesFocusNode,
    required this.newSubtaskController,
    required this.onAddSubtask,
    required this.breakpoint,
  });

  final Task task;
  final TextEditingController notesController;
  final FocusNode notesFocusNode;
  final TextEditingController newSubtaskController;
  final VoidCallback onAddSubtask;
  final double breakpoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final subtasks = _SubtasksSection(
            task: task,
            newSubtaskController: newSubtaskController,
            onAddSubtask: onAddSubtask,
          );
          final notes = _NotesField(
            controller: notesController,
            focusNode: notesFocusNode,
          );

          if (constraints.maxWidth >= breakpoint) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: subtasks),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: notes),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [notes, const SizedBox(height: 12), subtasks],
          );
        },
      ),
    );
  }
}

class _NotesField extends StatelessWidget {
  const _NotesField({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: const InputDecoration(
        labelText: 'Notes',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      minLines: 3,
      maxLines: 6,
    );
  }
}

class _SubtasksSection extends ConsumerWidget {
  const _SubtasksSection({
    required this.task,
    required this.newSubtaskController,
    required this.onAddSubtask,
  });

  final Task task;
  final TextEditingController newSubtaskController;
  final VoidCallback onAddSubtask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(tasksProvider.notifier);
    final reduceMotion = ref.watch(settingsProvider).reduceMotion;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (task.subtasks.isNotEmpty) ...[
          Text('Subtasks', style: theme.textTheme.labelLarge),
          for (final subtask in task.subtasks)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              onTap: () => notifier.toggleSubtask(task.id, subtask.id),
              leading: WobbleCheckbox(
                value: subtask.isChecked,
                reduceMotion: reduceMotion,
                onChanged: (_) => notifier.toggleSubtask(task.id, subtask.id),
              ),
              title: Text(
                subtask.title,
                style: subtask.isChecked
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Remove subtask',
                onPressed: () => notifier.removeSubtask(task.id, subtask.id),
              ),
            ),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: newSubtaskController,
                decoration: const InputDecoration(
                  hintText: 'Add a subtask',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onAddSubtask(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.add), onPressed: onAddSubtask),
          ],
        ),
      ],
    );
  }
}
