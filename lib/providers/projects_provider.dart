import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_setup.dart';
import '../models/activity_entry.dart';
import '../models/project.dart';
import '../models/project_comment.dart';
import 'tasks_provider.dart';

final projectsProvider = StateNotifierProvider<ProjectsNotifier, List<Project>>(
  (ref) {
    return ProjectsNotifier(ref);
  },
);

/// Persistence to Hive is fire-and-forget: [state] is the source of truth
/// for the UI and is updated synchronously, while the on-disk copy catches
/// up in the background.
class ProjectsNotifier extends StateNotifier<List<Project>> {
  ProjectsNotifier(this._ref) : super(_box.values.toList()) {
    _sortState();
  }

  final Ref _ref;

  static Box<Project> get _box => Hive.box<Project>(projectBoxName);
  static final _neverOpened = DateTime.fromMillisecondsSinceEpoch(0);

  void _sortState() {
    final sorted = [...state]
      ..sort((a, b) {
        final recency = (b.lastOpenedAt ?? _neverOpened).compareTo(
          a.lastOpenedAt ?? _neverOpened,
        );
        if (recency != 0) return recency;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    state = sorted;
  }

  Project addProject(String name, {int colorIndex = 0}) {
    final project = Project(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now(),
      colorIndex: colorIndex,
    );
    project.activityLog.add(
      ActivityEntry(
        kindIndex: ActivityKind.projectCreated.index,
        description: 'You created this project',
        timestamp: DateTime.now(),
      ),
    );
    unawaited(_box.put(project.id, project));
    state = [...state, project];
    _sortState();
    return project;
  }

  void renameProject(String id, String name) {
    final project = _box.get(id);
    if (project == null) return;
    project.name = name;
    unawaited(project.save());
    state = [
      for (final p in state)
        if (p.id == id) project else p,
    ];
    _sortState();
  }

  void setProjectColor(String id, int colorIndex) {
    final project = _box.get(id);
    if (project == null) return;
    project.colorIndex = colorIndex;
    unawaited(project.save());
    state = [
      for (final p in state)
        if (p.id == id) project else p,
    ];
  }

  /// Marks a project as just opened, so it sorts to the front.
  void touchProject(String id) {
    final project = _box.get(id);
    if (project == null) return;
    project.lastOpenedAt = DateTime.now();
    unawaited(project.save());
    _sortState();
  }

  /// Archives [id]: it drops out of the main grid/search without deleting
  /// anything, and stays reachable from the Archived tab.
  void archiveProject(String id) {
    final project = _box.get(id);
    if (project == null) return;
    project.archived = true;
    unawaited(project.save());
    state = [
      for (final p in state)
        if (p.id == id) project else p,
    ];
  }

  void toggleFavorite(String id) {
    final project = _box.get(id);
    if (project == null) return;
    project.favorite = !project.favorite;
    unawaited(project.save());
    state = [
      for (final p in state)
        if (p.id == id) project else p,
    ];
  }

  /// Appends an entry to [id]'s Activity log — called by [TasksNotifier] for
  /// task-level events (added/completed/edited) on tasks filed under a
  /// project, in addition to [addProject]'s own "created" entry.
  void logActivity(String id, ActivityEntry entry) {
    final project = _box.get(id);
    if (project == null) return;
    project.activityLog = [...project.activityLog, entry];
    unawaited(project.save());
    state = [
      for (final p in state)
        if (p.id == id) project else p,
    ];
  }

  void addComment(String id, String author, String text) {
    final project = _box.get(id);
    if (project == null) return;
    project.comments = [
      ...project.comments,
      ProjectComment(
        id: const Uuid().v4(),
        author: author,
        text: text,
        timestamp: DateTime.now(),
      ),
    ];
    unawaited(project.save());
    state = [
      for (final p in state)
        if (p.id == id) project else p,
    ];
  }

  /// Puts an archived project back in the main grid.
  void unarchiveProject(String id) {
    final project = _box.get(id);
    if (project == null) return;
    project.archived = false;
    unawaited(project.save());
    state = [
      for (final p in state)
        if (p.id == id) project else p,
    ];
    _sortState();
  }

  void deleteProject(String id) {
    // Deleting a project takes its tasks (and their subtasks) with it.
    _ref.read(tasksProvider.notifier).deleteTasksInProject(id);
    unawaited(_box.delete(id));
    state = state.where((p) => p.id != id).toList();
  }

  /// Wipes every project. Used by Settings > Wipe All Data.
  void clearAll() {
    unawaited(_box.clear());
    state = [];
  }

  /// Replaces every project with [projects]. Used when restoring from a
  /// backup — anything currently stored is discarded first.
  void restoreAll(List<Project> projects) {
    unawaited(_box.clear());
    unawaited(_box.putAll({for (final p in projects) p.id: p}));
    state = projects;
    _sortState();
  }
}
