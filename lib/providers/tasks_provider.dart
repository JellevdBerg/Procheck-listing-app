import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_setup.dart';
import '../data/notification_service.dart';
import '../models/activity_entry.dart';
import '../models/attachment.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import '../models/task_template.dart';
import 'projects_provider.dart';

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>((ref) {
  return TasksNotifier(ref);
});

/// Persistence to Hive is fire-and-forget: [state] is the source of truth
/// for the UI and is updated synchronously, while the on-disk copy catches
/// up in the background.
class TasksNotifier extends StateNotifier<List<Task>> {
  TasksNotifier(this._ref) : super(_box.values.toList()) {
    _sortState();
  }

  final Ref _ref;

  static Box<Task> get _box => Hive.box<Task>(taskBoxName);

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

  void _persist(Task task) {
    unawaited(task.save());
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
    );
    unawaited(_box.put(task.id, task));
    state = [task, ...state];
    _logActivity(task, ActivityKind.taskAdded, 'You added "${task.title}"');
    return task;
  }

  void renameTask(String taskId, String title) {
    final task = _box.get(taskId);
    if (task == null) return;
    task.title = title;
    _persist(task);
    _logActivity(task, ActivityKind.taskEdited, 'You edited "${task.title}"');
  }

  void moveToProject(String taskId, String? projectId) {
    final task = _box.get(taskId);
    if (task == null) return;
    task.projectId = projectId;
    _persist(task);
  }

  void deleteTask(String taskId) {
    final task = _box.get(taskId);
    if (task != null) {
      unawaited(NotificationService.instance.cancelForTask(task));
    }
    unawaited(_box.delete(taskId));
    state = state.where((t) => t.id != taskId).toList();
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
    var changed = false;
    for (var i = 0; i < n; i++) {
      final task = _box.get(orderedIds[i]);
      if (task == null) continue;
      task.sortOrder = (n - i).toDouble();
      unawaited(task.save());
      changed = true;
    }
    if (!changed) return;
    state = [...state];
    _sortState();
  }

  /// Toggling a task cascades the new value down to every subtask. To
  /// toggle a single subtask, use [toggleSubtask] instead: the task is
  /// then checked exactly when all of its subtasks are.
  void toggleTask(String taskId) {
    final task = _box.get(taskId);
    if (task == null) return;
    final newValue = !task.isChecked;
    task.isChecked = newValue;
    for (final subtask in task.subtasks) {
      subtask.isChecked = newValue;
    }
    _persist(task);
    _syncNotificationForCompletionChange(task);
    if (newValue) {
      _logActivity(
        task,
        ActivityKind.taskCompleted,
        'You completed "${task.title}"',
      );
    }
  }

  void toggleSubtask(String taskId, String subtaskId) {
    final task = _box.get(taskId);
    if (task == null) return;
    for (final subtask in task.subtasks) {
      if (subtask.id == subtaskId) {
        subtask.isChecked = !subtask.isChecked;
        break;
      }
    }
    task.isChecked = task.subtasks.every((s) => s.isChecked);
    _persist(task);
    _syncNotificationForCompletionChange(task);
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

  void setTaskNotes(String taskId, String? notes) {
    final task = _box.get(taskId);
    if (task == null) return;
    task.notes = notes;
    _persist(task);
  }

  void setTaskDueDate(String taskId, DateTime? dueDate) {
    final task = _box.get(taskId);
    if (task == null) return;
    task.dueDate = dueDate;
    _persist(task);
    unawaited(NotificationService.instance.scheduleForTask(task));
  }

  void setTaskPriority(String taskId, TaskPriority priority) {
    final task = _box.get(taskId);
    if (task == null) return;
    task.priority = priority;
    _persist(task);
  }

  void addAttachments(String taskId, List<Attachment> attachments) {
    if (attachments.isEmpty) return;
    final task = _box.get(taskId);
    if (task == null) return;
    task.attachments = [...task.attachments, ...attachments];
    _persist(task);
  }

  void removeAttachment(String taskId, int index) {
    final task = _box.get(taskId);
    if (task == null) return;
    if (index < 0 || index >= task.attachments.length) return;
    task.attachments = [...task.attachments]..removeAt(index);
    _persist(task);
  }

  void addSubtask(String taskId, String title) {
    final task = _box.get(taskId);
    if (task == null) return;
    task.subtasks = [
      ...task.subtasks,
      Subtask(id: const Uuid().v4(), title: title),
    ];
    // A freshly-added, unchecked subtask means the task can no longer be
    // considered done.
    task.isChecked = task.subtasks.every((s) => s.isChecked);
    _persist(task);
  }

  void removeSubtask(String taskId, String subtaskId) {
    final task = _box.get(taskId);
    if (task == null) return;
    task.subtasks = task.subtasks.where((s) => s.id != subtaskId).toList();
    if (task.subtasks.isNotEmpty) {
      task.isChecked = task.subtasks.every((s) => s.isChecked);
    }
    _persist(task);
  }

  void resetProgress(String taskId) {
    final task = _box.get(taskId);
    if (task == null) return;
    task.isChecked = false;
    for (final subtask in task.subtasks) {
      subtask.isChecked = false;
    }
    _persist(task);
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

  /// Wipes every task. Used by Settings > Wipe All Data.
  void clearAll() {
    unawaited(NotificationService.instance.cancelAll());
    unawaited(_box.clear());
    state = [];
  }

  /// Replaces every task with [tasks]. Used when restoring from a backup —
  /// anything currently stored is discarded first.
  void restoreAll(List<Task> tasks) {
    unawaited(NotificationService.instance.cancelAll());
    unawaited(_box.clear());
    unawaited(_box.putAll({for (final t in tasks) t.id: t}));
    state = tasks;
    _sortState();
    for (final task in tasks) {
      if (task.dueDate != null && !task.isChecked) {
        unawaited(NotificationService.instance.scheduleForTask(task));
      }
    }
  }
}
