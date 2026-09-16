import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_setup.dart';
import '../models/attachment.dart';
import '../models/task_template.dart';
import '../models/template_subtask.dart';
import 'settings_provider.dart';

final taskTemplatesProvider =
    StateNotifierProvider<TaskTemplatesNotifier, List<TaskTemplate>>((ref) {
      return TaskTemplatesNotifier(ref);
    });

/// Persistence to Hive is fire-and-forget: [state] is the source of truth
/// for the UI and is updated synchronously, while the on-disk copy catches
/// up in the background.
///
/// [state] only ever holds the *current workspace's* templates — see
/// [AppSettings.currentWorkspaceId] — so every screen that reads this
/// provider gets workspace isolation for free. [_box] remains the full,
/// unfiltered on-disk store; backup export, wipe-all, and removing a
/// workspace go through [allValues]/`*ForWorkspace` instead of [state].
class TaskTemplatesNotifier extends StateNotifier<List<TaskTemplate>> {
  TaskTemplatesNotifier(Ref ref) : _ref = ref, super(_initialState(ref)) {
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

  static Box<TaskTemplate> get _box =>
      Hive.box<TaskTemplate>(taskTemplateBoxName);

  /// Every template regardless of workspace — used only where that's
  /// explicitly correct (backup export, Settings > Wipe All Data already
  /// clearing the whole box).
  List<TaskTemplate> get allValues => _box.values.toList();

  static List<TaskTemplate> _initialState(Ref ref) {
    final settings = ref.read(settingsProvider);
    _migrateLegacyWorkspaceIds(settings.workspaceIds.first);
    return _box.values
        .where((t) => t.workspaceId == settings.currentWorkspaceId)
        .toList();
  }

  /// Templates saved before workspaces had real data isolation have no
  /// [TaskTemplate.workspaceId] — a one-time backfill onto the first
  /// workspace, so filtering by id can rely on it always being set from
  /// here on.
  static void _migrateLegacyWorkspaceIds(String defaultWorkspaceId) {
    for (final template in _box.values) {
      if (template.workspaceId == null) {
        template.workspaceId = defaultWorkspaceId;
        unawaited(template.save());
      }
    }
  }

  void _sortState() {
    final sorted = [...state]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    state = sorted;
  }

  TaskTemplate addTemplate(
    String name,
    List<String> subtaskTitles, {
    String? notes,
    List<Attachment>? attachments,
  }) {
    final template = TaskTemplate(
      id: const Uuid().v4(),
      name: name,
      subtasks: subtaskTitles
          .map((title) => TemplateSubtask(id: const Uuid().v4(), title: title))
          .toList(),
      createdAt: DateTime.now(),
      notes: notes,
      attachments: attachments,
      workspaceId: _ref.read(settingsProvider).currentWorkspaceId,
    );
    unawaited(_box.put(template.id, template));
    state = [...state, template];
    _sortState();
    return template;
  }

  void updateTemplate(
    String id,
    String name,
    List<TemplateSubtask> subtasks, {
    String? notes,
    List<Attachment>? attachments,
  }) {
    final template = _box.get(id);
    if (template == null) return;
    template.name = name;
    template.subtasks = subtasks;
    template.notes = notes;
    template.attachments = attachments ?? [];
    unawaited(template.save());
    state = [
      for (final t in state)
        if (t.id == id) template else t,
    ];
    _sortState();
  }

  void deleteTemplate(String id) {
    unawaited(_box.delete(id));
    state = state.where((t) => t.id != id).toList();
  }

  /// How many templates belong to [workspaceId] — shown in the "remove
  /// workspace" confirmation before [deleteAllForWorkspace] runs.
  int countForWorkspace(String workspaceId) =>
      _box.values.where((t) => t.workspaceId == workspaceId).length;

  /// Deletes every template belonging to [workspaceId]. Used when the
  /// workspace itself is removed — see the sidebar's workspace context
  /// menu.
  void deleteAllForWorkspace(String workspaceId) {
    final ids = _box.values
        .where((t) => t.workspaceId == workspaceId)
        .map((t) => t.id)
        .toList();
    if (ids.isEmpty) return;
    for (final id in ids) {
      unawaited(_box.delete(id));
    }
    final idsToDelete = ids.toSet();
    state = state.where((t) => !idsToDelete.contains(t.id)).toList();
  }

  /// Wipes every template. Used by Settings > Wipe All Data.
  void clearAll() {
    unawaited(_box.clear());
    state = [];
  }

  /// Replaces every template with [templates]. Used when restoring from a
  /// backup — anything currently stored is discarded first. [templates] may
  /// span every workspace (a full backup), so [state] is narrowed back down
  /// to the current one afterward, same as normal operation.
  void restoreAll(List<TaskTemplate> templates) {
    unawaited(_box.clear());
    unawaited(_box.putAll({for (final t in templates) t.id: t}));
    final settings = _ref.read(settingsProvider);
    _migrateLegacyWorkspaceIds(settings.workspaceIds.first);
    state = _box.values
        .where((t) => t.workspaceId == settings.currentWorkspaceId)
        .toList();
    _sortState();
  }
}
