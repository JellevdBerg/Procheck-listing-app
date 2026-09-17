import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_setup.dart';
import '../models/activity_entry.dart';
import '../models/project.dart';
import '../models/project_comment.dart';
import 'settings_provider.dart';
import 'tasks_provider.dart';
import 'undo_provider.dart';

final projectsProvider = StateNotifierProvider<ProjectsNotifier, List<Project>>(
  (ref) {
    return ProjectsNotifier(ref);
  },
);

/// Persistence to Hive is fire-and-forget: [state] is the source of truth
/// for the UI and is updated synchronously, while the on-disk copy catches
/// up in the background.
///
/// [state] only ever holds the *current workspace's* projects — see
/// [AppSettings.currentWorkspaceId] — so every screen that reads this
/// provider gets workspace isolation for free, without filtering it
/// itself. [_box] remains the full, unfiltered on-disk store; anything
/// that must reach across workspaces (backup export, wipe-all, removing a
/// workspace) goes through [allValues] or the `*ForWorkspace` methods
/// instead of [state].
class ProjectsNotifier extends StateNotifier<List<Project>> {
  ProjectsNotifier(Ref ref)
    : _ref = ref,
      super(_initialState(ref)) {
    _sortState();
    _ref.listen<String>(
      settingsProvider.select((s) => s.currentWorkspaceId),
      (previous, next) {
        if (previous == next) return;
        state = _box.values.where((p) => p.workspaceId == next).toList();
        _sortState();
      },
    );
  }

  final Ref _ref;

  static Box<Project> get _box => Hive.box<Project>(projectBoxName);
  static final _neverOpened = DateTime.fromMillisecondsSinceEpoch(0);

  /// Every project regardless of workspace — used only where that's
  /// explicitly correct (backup export, Settings > Wipe All Data already
  /// clearing the whole box).
  List<Project> get allValues => _box.values.toList();

  static List<Project> _initialState(Ref ref) {
    final settings = ref.read(settingsProvider);
    _migrateLegacyWorkspaceIds(settings.workspaceIds.first);
    return _box.values
        .where((p) => p.workspaceId == settings.currentWorkspaceId)
        .toList();
  }

  /// Projects saved before workspaces had real data isolation have no
  /// [Project.workspaceId] — a one-time backfill onto the first workspace,
  /// so filtering by id can rely on it always being set from here on.
  static void _migrateLegacyWorkspaceIds(String defaultWorkspaceId) {
    for (final project in _box.values) {
      if (project.workspaceId == null) {
        project.workspaceId = defaultWorkspaceId;
        unawaited(project.save());
      }
    }
  }

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
      workspaceId: _ref.read(settingsProvider).currentWorkspaceId,
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
    final project = _box.get(id);
    if (project == null) return;
    // Captured before the cascade below removes them from state, so the
    // undo entry can bring them back along with the project itself.
    final cascadedTasks = _ref
        .read(tasksProvider)
        .where((t) => t.projectId == id)
        .toList();
    // Deleting a project takes its tasks (and their subtasks) with it.
    _ref.read(tasksProvider.notifier).deleteTasksInProject(id);
    unawaited(_box.delete(id));
    state = state.where((p) => p.id != id).toList();
    _ref
        .read(undoStackProvider.notifier)
        .push(ProjectDeletionEntry(project, cascadedTasks));
  }

  /// Re-adds a previously-deleted [project] exactly as it was — used by the
  /// undo stack to reverse [deleteProject]. Its cascade-deleted tasks are
  /// restored separately, by the same undo entry.
  void restoreProject(Project project) {
    unawaited(_box.put(project.id, project));
    state = [...state, project];
    _sortState();
  }

  /// How many projects belong to [workspaceId] — shown in the "remove
  /// workspace" confirmation before [deleteAllForWorkspace] runs.
  int countForWorkspace(String workspaceId) =>
      _box.values.where((p) => p.workspaceId == workspaceId).length;

  /// Deletes every project (and, via [ProjectsNotifier.deleteProject]'s own
  /// cascade, every task filed under one) that belongs to [workspaceId].
  /// Used when the workspace itself is removed — see the sidebar's
  /// workspace context menu, which confirms this with the user first via
  /// [countForWorkspace].
  void deleteAllForWorkspace(String workspaceId) {
    final ids = _box.values
        .where((p) => p.workspaceId == workspaceId)
        .map((p) => p.id)
        .toList();
    for (final id in ids) {
      deleteProject(id);
    }
  }

  /// Wipes every project. Used by Settings > Wipe All Data.
  void clearAll() {
    unawaited(_box.clear());
    state = [];
  }

  /// Replaces every project with [projects]. Used when restoring from a
  /// backup — anything currently stored is discarded first. [projects] may
  /// span every workspace (a full backup), so [state] is narrowed back down
  /// to the current one afterward, same as normal operation.
  void restoreAll(List<Project> projects) {
    unawaited(_box.clear());
    unawaited(_box.putAll({for (final p in projects) p.id: p}));
    final settings = _ref.read(settingsProvider);
    _migrateLegacyWorkspaceIds(settings.workspaceIds.first);
    state = _box.values
        .where((p) => p.workspaceId == settings.currentWorkspaceId)
        .toList();
    _sortState();
  }
}
