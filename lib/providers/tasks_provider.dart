import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_setup.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../models/task_template.dart';

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>((ref) {
  return TasksNotifier();
});

/// Persistence to Hive is fire-and-forget: [state] is the source of truth
/// for the UI and is updated synchronously, while the on-disk copy catches
/// up in the background.
class TasksNotifier extends StateNotifier<List<Task>> {
  TasksNotifier() : super(_box.values.toList()) {
    _sortState();
  }

  static Box<Task> get _box => Hive.box<Task>(taskBoxName);

  void _sortState() {
    final sorted = [...state]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

  Task addBlankTask({required String title, String? projectId}) {
    return _addTask(title: title, projectId: projectId, subtasks: const []);
  }

  Task addFromTemplate({
    required TaskTemplate template,
    String? projectId,
    String? title,
  }) {
    final subtasks = template.subtasks
        .map(
          (templateSubtask) =>
              Subtask(id: const Uuid().v4(), title: templateSubtask.title),
        )
        .toList();
    return _addTask(
      title: title ?? template.name,
      projectId: projectId,
      subtasks: subtasks,
      templateId: template.id,
    );
  }

  Task _addTask({
    required String title,
    String? projectId,
    required List<Subtask> subtasks,
    String? templateId,
  }) {
    final task = Task(
      id: const Uuid().v4(),
      title: title,
      subtasks: subtasks,
      createdAt: DateTime.now(),
      projectId: projectId,
      templateId: templateId,
    );
    unawaited(_box.put(task.id, task));
    state = [task, ...state];
    return task;
  }

  void renameTask(String taskId, String title) {
    final task = _box.get(taskId);
    if (task == null) return;
    task.title = title;
    _persist(task);
  }

  void moveToProject(String taskId, String? projectId) {
    final task = _box.get(taskId);
    if (task == null) return;
    task.projectId = projectId;
    _persist(task);
  }

  void deleteTask(String taskId) {
    unawaited(_box.delete(taskId));
    state = state.where((t) => t.id != taskId).toList();
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
  }

  void setTaskNotes(String taskId, String? notes) {
    final task = _box.get(taskId);
    if (task == null) return;
    task.notes = notes;
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
    final idsToDelete = state
        .where((t) => t.projectId == projectId)
        .map((t) => t.id)
        .toSet();
    if (idsToDelete.isEmpty) return;
    for (final id in idsToDelete) {
      unawaited(_box.delete(id));
    }
    state = state.where((t) => !idsToDelete.contains(t.id)).toList();
  }

  /// Wipes every task. Used by Settings > Wipe All Data.
  void clearAll() {
    unawaited(_box.clear());
    state = [];
  }

  /// Replaces every task with [tasks]. Used when restoring from a backup —
  /// anything currently stored is discarded first.
  void restoreAll(List<Task> tasks) {
    unawaited(_box.clear());
    unawaited(_box.putAll({for (final t in tasks) t.id: t}));
    state = tasks;
    _sortState();
  }
}
