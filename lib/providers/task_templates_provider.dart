import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_setup.dart';
import '../models/attachment.dart';
import '../models/task_template.dart';
import '../models/template_subtask.dart';

final taskTemplatesProvider =
    StateNotifierProvider<TaskTemplatesNotifier, List<TaskTemplate>>((ref) {
      return TaskTemplatesNotifier();
    });

/// Persistence to Hive is fire-and-forget: [state] is the source of truth
/// for the UI and is updated synchronously, while the on-disk copy catches
/// up in the background.
class TaskTemplatesNotifier extends StateNotifier<List<TaskTemplate>> {
  TaskTemplatesNotifier() : super(_box.values.toList()) {
    _sortState();
  }

  static Box<TaskTemplate> get _box =>
      Hive.box<TaskTemplate>(taskTemplateBoxName);

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

  /// Wipes every template. Used by Settings > Wipe All Data.
  void clearAll() {
    unawaited(_box.clear());
    state = [];
  }

  /// Replaces every template with [templates]. Used when restoring from a
  /// backup — anything currently stored is discarded first.
  void restoreAll(List<TaskTemplate> templates) {
    unawaited(_box.clear());
    unawaited(_box.putAll({for (final t in templates) t.id: t}));
    state = templates;
    _sortState();
  }
}
