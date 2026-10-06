import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_setup.dart';
import '../data/notification_service.dart';
import '../data/sound_service.dart';
import '../models/activity_entry.dart';
import '../models/attachment.dart';
import '../models/recurrence_rule.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import '../models/task_template.dart';
import 'projects_provider.dart';
import 'settings_provider.dart';
import 'undo_provider.dart';

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>((ref) {
  return TasksNotifier(ref);
});

/// Persistence to Hive is fire-and-forget: [state] is the source of truth
/// for the UI and is updated synchronously, while the on-disk copy catches
/// up in the background.
///
/// [state] only ever holds the *current workspace's* tasks — see
/// [AppSettings.currentWorkspaceId] — so every screen that reads this
/// provider gets workspace isolation for free. [_box] remains the full,
/// unfiltered on-disk store; backup export, wipe-all, and removing a
/// workspace go through [allValues]/`*ForWorkspace` instead of [state].
class TasksNotifier extends StateNotifier<List<Task>> {
  TasksNotifier(Ref ref) : _ref = ref, super(_initialState(ref)) {
    _sortState();
    _ref.listen<String>(
      settingsProvider.select((s) => s.currentWorkspaceId),
      (previous, next) {
        if (previous == next) return;
        state = _box.values.where((t) => t.workspaceId == next).toList();
        _sortState();
      },
    );
  }

  final Ref _ref;

  static Box<Task> get _box => Hive.box<Task>(taskBoxName);

  /// Every task regardless of workspace — used only where that's
  /// explicitly correct (backup export, Settings > Wipe All Data already
  /// clearing the whole box).
  List<Task> get allValues => _box.values.toList();

  static List<Task> _initialState(Ref ref) {
    final settings = ref.read(settingsProvider);
    _migrateLegacyWorkspaceIds(settings.workspaceIds.first);
    return _box.values
        .where((t) => t.workspaceId == settings.currentWorkspaceId)
        .toList();
  }

  /// Tasks saved before workspaces had real data isolation have no
  /// [Task.workspaceId] — a one-time backfill onto the first workspace, so
  /// filtering by id can rely on it always being set from here on.
  static void _migrateLegacyWorkspaceIds(String defaultWorkspaceId) {
    for (final task in _box.values) {
      if (task.workspaceId == null) {
        task.workspaceId = defaultWorkspaceId;
        unawaited(task.save());
      }
    }
  }

  /// Logs a task-level event to its parent project's Activity log — a
  /// no-op for unfiled tasks (no project to log against).
  void _logActivity(Task task, ActivityKind kind, String description) {
    final projectId = task.projectId;
    if (projectId == null) return;
    _ref.read(projectsProvider.notifier).logActivity(
      projectId,
      ActivityEntry(
        kindIndex: kind.index,
        description: description,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _sortState() {
    final sorted = [...state]
      ..sort((a, b) {
        final order = b.sortOrder.compareTo(a.sortOrder);
        if (order != 0) return order;
        return b.createdAt.compareTo(a.createdAt);
      });
    state = sorted;
  }

  void _replace(Task updated) {
    state = [
      for (final t in state)
        if (t.id == updated.id) updated else t,
    ];
  }

  /// Persists [task] — a freshly built [Task.copyWith] instance, never the
  /// same object already in [state] — and swaps it into [state] in place.
  /// Building a new instance rather than mutating the existing one in the
  /// box is what lets value-equality-based selectors (see [Task.operator
  /// ==]) detect the edit: mutating the box's cached instance in place
  /// would mean the "old" and "new" values a selector compares are the
  /// very same object, always equal regardless of what changed.
  void _persist(Task task) {
    unawaited(_box.put(task.id, task));
    _replace(task);
  }

  Task addBlankTask({
    required String title,
    String? projectId,
    TaskPriority priority = TaskPriority.none,
  }) {
    return _addTask(
      title: title,
      projectId: projectId,
      subtasks: const [],
      priority: priority,
    );
  }

  Task addFromTemplate({
    required TaskTemplate template,
    String? projectId,
    String? title,
    TaskPriority priority = TaskPriority.none,
  }) {
    final subtasks = template.subtasks
        .map(
          (templateSubtask) =>
              Subtask(id: const Uuid().v4(), title: templateSubtask.title),
        )
        .toList();
    // Fresh Attachment copies rather than the template's own instances —
    // each HiveObject should belong to one parent's list, not be shared
    // between the template and every task instantiated from it.
    final attachments = template.attachments
        .map((a) => Attachment(name: a.name, size: a.size, path: a.path))
        .toList();
    return _addTask(
      title: title ?? template.name,
      projectId: projectId,
      subtasks: subtasks,
      templateId: template.id,
      priority: priority,
      notes: template.notes,
      attachments: attachments,
    );
  }

  Task _addTask({
    required String title,
    String? projectId,
    required List<Subtask> subtasks,
    String? templateId,
    TaskPriority priority = TaskPriority.none,
    String? notes,
    List<Attachment>? attachments,
  }) {
    final task = Task(
      id: const Uuid().v4(),
      title: title,
      subtasks: subtasks,
      createdAt: DateTime.now(),
      projectId: projectId,
      templateId: templateId,
      priorityIndex: priority.index,
      notes: notes,
      attachments: attachments,
      workspaceId: _ref.read(settingsProvider).currentWorkspaceId,
    );
    unawaited(_box.put(task.id, task));
    state = [task, ...state];
    _logActivity(task, ActivityKind.taskAdded, 'You added "${task.title}"');
    return task;
  }

  void renameTask(String taskId, String title) {
    final task = _box.get(taskId);
    if (task == null) return;
    final updated = task.copyWith(title: title);
    _persist(updated);
    _logActivity(
      updated,
      ActivityKind.taskEdited,
      'You edited "${updated.title}"',
    );
  }

  /// Recurrence only applies to standalone tasks, so filing a recurring one
  /// under a project (projectId non-null) clears it rather than leaving a
  /// dormant setting the project task list has no UI to show or change.
  void moveToProject(String taskId, String? projectId) {
    final task = _box.get(taskId);
    if (task == null) return;
    _persist(
      task.copyWith(
        projectId: projectId,
        recurrenceIndex: projectId == null ? null : RecurrenceRule.none.index,
      ),
    );
  }

  void deleteTask(String taskId) {
    final task = _box.get(taskId);
    if (task != null) {
      unawaited(NotificationService.instance.cancelForTask(task));
    }
    unawaited(_box.delete(taskId));
    state = state.where((t) => t.id != taskId).toList();
    if (task != null) {
      _ref.read(undoStackProvider.notifier).push(TaskDeletionEntry(task));
    }
  }

  /// Re-adds a previously-deleted [task] exactly as it was — used to undo an
  /// accidental deletion. Reschedules its due-date notification if it had
  /// one and isn't checked off.
  void restoreTask(Task task) {
    unawaited(_box.put(task.id, task));
    state = [task, ...state];
    _sortState();
    if (task.dueDate != null && !task.isChecked) {
      unawaited(NotificationService.instance.scheduleForTask(task));
    }
  }

  /// Reassigns [orderedIds]' sortOrder to reflect the drag-and-drop order
  /// the caller wants for them — a project's task list, or the home
  /// screen's unfiled tasks, each reordered independently of the other.
  /// Every id in the list gets a fresh, small, strictly-decreasing
  /// sortOrder (simpler and more robust than fractional midpoint
  /// insertion), which — being far smaller than any timestamp-based
  /// sortOrder — always sorts below a task nobody has manually touched yet,
  /// without disturbing that task's position relative to others like it.
  void reorderTasks(List<String> orderedIds) {
    final n = orderedIds.length;
    final updatedById = <String, Task>{};
    for (var i = 0; i < n; i++) {
      final task = _box.get(orderedIds[i]);
      if (task == null) continue;
      final updated = task.copyWith(sortOrder: (n - i).toDouble());
      unawaited(_box.put(updated.id, updated));
      updatedById[updated.id] = updated;
    }
    if (updatedById.isEmpty) return;
    state = [for (final t in state) updatedById[t.id] ?? t];
    _sortState();
  }

  /// Toggling a task cascades the new value down to every subtask. To
  /// toggle a single subtask, use [toggleSubtask] instead: the task is
  /// then checked exactly when all of its subtasks are.
  void toggleTask(String taskId) {
    final task = _box.get(taskId);
    if (task == null) return;
    final newValue = !task.isChecked;
    if (newValue && task.recurrence != RecurrenceRule.none) {
      unawaited(SoundService.instance.playCheckoff());
      _completeRecurringTask(task);
      return;
    }
    final updated = task.copyWith(
      isChecked: newValue,
      subtasks: [
        for (final subtask in task.subtasks)
          subtask.copyWith(isChecked: newValue),
      ],
    );
    _persist(updated);
    _syncNotificationForCompletionChange(updated);
    if (newValue) {
      unawaited(SoundService.instance.playCheckoff());
      _logActivity(
        updated,
        ActivityKind.taskCompleted,
        'You completed "${updated.title}"',
      );
    }
  }

  void toggleSubtask(String taskId, String subtaskId) {
    final task = _box.get(taskId);
    if (task == null) return;
    final wasChecked = task.isChecked;
    final newSubtasks = [
      for (final subtask in task.subtasks)
        subtask.id == subtaskId
            ? subtask.copyWith(isChecked: !subtask.isChecked)
            : subtask,
    ];
    final completesTask = newSubtasks.every((s) => s.isChecked);
    if (completesTask && !wasChecked && task.recurrence != RecurrenceRule.none) {
      unawaited(SoundService.instance.playCheckoff());
      _completeRecurringTask(task);
      return;
    }
    final updated = task.copyWith(subtasks: newSubtasks, isChecked: completesTask);
    _persist(updated);
    _syncNotificationForCompletionChange(updated);
    if (updated.isChecked && !wasChecked) {
      unawaited(SoundService.instance.playCheckoff());
    }
  }

  /// A completed task has nothing left to remind about, so its due-date
  /// notification (if any) is cancelled; un-completing it (still possible
  /// via [toggleTask]/[toggleSubtask]) puts it back if the due date hasn't
  /// passed yet.
  void _syncNotificationForCompletionChange(Task task) {
    if (task.isChecked) {
      unawaited(NotificationService.instance.cancelForTask(task));
    } else if (task.dueDate != null) {
      unawaited(NotificationService.instance.scheduleForTask(task));
    }
  }

  /// A recurring task isn't "finished and kept around" the way an ordinary
  /// one is — completing it replaces it outright with its next occurrence,
  /// so the active lists only ever show one live instance rather than
  /// accumulating a trail of checked-off copies. [task] is still unchecked
  /// at this point (the completion that triggered this, not yet persisted).
  ///
  /// Recurrence doesn't depend on a due date: when [task] has one, the next
  /// occurrence's is advanced by [Task.recurrence]'s rule; when it doesn't,
  /// the next occurrence has none either (the rule still just governs "get
  /// a fresh unchecked copy on completion", no schedule to anchor).
  void _completeRecurringTask(Task task) {
    unawaited(NotificationService.instance.cancelForTask(task));
    unawaited(_box.delete(task.id));

    final dueDate = task.dueDate;
    final dueDateEnd = task.dueDateEnd;
    final nextDueDate = dueDate == null ? null : task.recurrence.next(dueDate);
    final next = Task(
      id: const Uuid().v4(),
      title: task.title,
      createdAt: DateTime.now(),
      notes: task.notes,
      subtasks: [
        for (final subtask in task.subtasks)
          Subtask(id: const Uuid().v4(), title: subtask.title),
      ],
      projectId: task.projectId,
      templateId: task.templateId,
      dueDate: nextDueDate,
      dueDateEnd: nextDueDate == null || dueDateEnd == null
          ? null
          : nextDueDate.add(dueDateEnd.difference(dueDate!)),
      priorityIndex: task.priorityIndex,
      attachments: [
        for (final a in task.attachments)
          Attachment(name: a.name, size: a.size, path: a.path),
      ],
      workspaceId: task.workspaceId,
      recurrenceIndex: task.recurrenceIndex,
    );
    state = [next, for (final t in state) if (t.id != task.id) t];
    unawaited(_box.put(next.id, next));
    _sortState();
    if (next.dueDate != null) {
      unawaited(NotificationService.instance.scheduleForTask(next));
    }
  }

  /// Recurrence only applies to standalone tasks — see [moveToProject],
  /// which clears it the moment a recurring task is filed under a project.
  void setTaskRecurrence(String taskId, RecurrenceRule recurrence) {
    final task = _box.get(taskId);
    if (task == null || task.projectId != null) return;
    _persist(task.copyWith(recurrenceIndex: recurrence.index));
  }

  void setTaskNotes(String taskId, String? notes) {
    final task = _box.get(taskId);
    if (task == null) return;
    _persist(task.copyWith(notes: notes));
  }

  void setTaskDueDate(String taskId, DateTime? dueDate, {DateTime? dueDateEnd}) {
    final task = _box.get(taskId);
    if (task == null) return;
    final updated = task.copyWith(
      dueDate: dueDate,
      dueDateEnd: dueDate == null ? null : dueDateEnd,
    );
    _persist(updated);
    unawaited(NotificationService.instance.scheduleForTask(updated));
  }

  void setTaskPriority(String taskId, TaskPriority priority) {
    final task = _box.get(taskId);
    if (task == null) return;
    _persist(task.copyWith(priorityIndex: priority.index));
  }

  void addAttachments(String taskId, List<Attachment> attachments) {
    if (attachments.isEmpty) return;
    final task = _box.get(taskId);
    if (task == null) return;
    _persist(task.copyWith(attachments: [...task.attachments, ...attachments]));
  }

  void removeAttachment(String taskId, int index) {
    final task = _box.get(taskId);
    if (task == null) return;
    if (index < 0 || index >= task.attachments.length) return;
    _persist(
      task.copyWith(attachments: [...task.attachments]..removeAt(index)),
    );
  }

  void addSubtask(String taskId, String title) {
    final task = _box.get(taskId);
    if (task == null) return;
    final newSubtasks = [
      ...task.subtasks,
      Subtask(id: const Uuid().v4(), title: title),
    ];
    // A freshly-added, unchecked subtask means the task can no longer be
    // considered done.
    _persist(
      task.copyWith(
        subtasks: newSubtasks,
        isChecked: newSubtasks.every((s) => s.isChecked),
      ),
    );
  }

  void removeSubtask(String taskId, String subtaskId) {
    final task = _box.get(taskId);
    if (task == null) return;
    final newSubtasks = task.subtasks.where((s) => s.id != subtaskId).toList();
    _persist(
      task.copyWith(
        subtasks: newSubtasks,
        isChecked: newSubtasks.isEmpty
            ? task.isChecked
            : newSubtasks.every((s) => s.isChecked),
      ),
    );
  }

  void resetProgress(String taskId) {
    final task = _box.get(taskId);
    if (task == null) return;
    _persist(
      task.copyWith(
        isChecked: false,
        subtasks: [
          for (final subtask in task.subtasks)
            subtask.copyWith(isChecked: false),
        ],
      ),
    );
  }

  /// Deletes every task that belongs to [projectId], along with their
  /// subtasks (which live embedded in each task, so nothing else to clean
  /// up). Used when the project itself is deleted.
  void deleteTasksInProject(String projectId) {
    final toDelete = state.where((t) => t.projectId == projectId).toList();
    if (toDelete.isEmpty) return;
    for (final task in toDelete) {
      unawaited(NotificationService.instance.cancelForTask(task));
      unawaited(_box.delete(task.id));
    }
    final idsToDelete = toDelete.map((t) => t.id).toSet();
    state = state.where((t) => !idsToDelete.contains(t.id)).toList();
  }

  /// How many tasks belong to [workspaceId] (filed or unfiled) — shown in
  /// the "remove workspace" confirmation before [deleteAllForWorkspace]
  /// runs.
  int countForWorkspace(String workspaceId) =>
      _box.values.where((t) => t.workspaceId == workspaceId).length;

  /// Deletes every task belonging to [workspaceId], filed or not. Used when
  /// the workspace itself is removed — see the sidebar's workspace context
  /// menu. Filed tasks are normally already gone by then (their project's
  /// own deletion cascades via [deleteTasksInProject]); this is what
  /// catches the unfiled ones, and acts as a backstop for the rest.
  void deleteAllForWorkspace(String workspaceId) {
    final toDelete = _box.values
        .where((t) => t.workspaceId == workspaceId)
        .toList();
    if (toDelete.isEmpty) return;
    for (final task in toDelete) {
      unawaited(NotificationService.instance.cancelForTask(task));
      unawaited(_box.delete(task.id));
    }
    final idsToDelete = toDelete.map((t) => t.id).toSet();
    state = state.where((t) => !idsToDelete.contains(t.id)).toList();
  }

  /// Wipes every task. Used by Settings > Wipe All Data.
  void clearAll() {
    unawaited(NotificationService.instance.cancelAll());
    unawaited(_box.clear());
    state = [];
  }

  /// Replaces every task with [tasks]. Used when restoring from a backup —
  /// anything currently stored is discarded first. [tasks] may span every
  /// workspace (a full backup), so [state] is narrowed back down to the
  /// current one afterward, same as normal operation.
  void restoreAll(List<Task> tasks) {
    unawaited(NotificationService.instance.cancelAll());
    unawaited(_box.clear());
    unawaited(_box.putAll({for (final t in tasks) t.id: t}));
    final settings = _ref.read(settingsProvider);
    _migrateLegacyWorkspaceIds(settings.workspaceIds.first);
    state = _box.values
        .where((t) => t.workspaceId == settings.currentWorkspaceId)
        .toList();
    _sortState();
    for (final task in tasks) {
      if (task.dueDate != null && !task.isChecked) {
        unawaited(NotificationService.instance.scheduleForTask(task));
      }
    }
  }
}
