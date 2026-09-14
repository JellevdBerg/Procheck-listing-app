import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_setup.dart';
import '../models/checklist.dart';
import '../models/checklist_item.dart';
import '../models/checklist_template.dart';

final checklistsProvider =
    StateNotifierProvider<ChecklistsNotifier, List<Checklist>>((ref) {
      return ChecklistsNotifier();
    });

/// Persistence to Hive is fire-and-forget: [state] is the source of truth
/// for the UI and is updated synchronously, while the on-disk copy catches
/// up in the background.
class ChecklistsNotifier extends StateNotifier<List<Checklist>> {
  ChecklistsNotifier() : super(_box.values.toList()) {
    _sortState();
  }

  static Box<Checklist> get _box => Hive.box<Checklist>(checklistBoxName);

  void _sortState() {
    final sorted = [...state]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = sorted;
  }

  void _replace(Checklist updated) {
    state = [
      for (final c in state)
        if (c.id == updated.id) updated else c,
    ];
  }

  void _persist(Checklist checklist) {
    unawaited(checklist.save());
    _replace(checklist);
  }

  Checklist addBlankChecklist({required String name, String? folderId}) {
    return _addChecklist(name: name, folderId: folderId, items: const []);
  }

  Checklist addFromTemplate({
    required ChecklistTemplate template,
    String? folderId,
    String? name,
  }) {
    final items = template.items
        .map(
          (templateItem) =>
              ChecklistItem(id: const Uuid().v4(), title: templateItem.title),
        )
        .toList();
    return _addChecklist(
      name: name ?? template.name,
      folderId: folderId,
      items: items,
      templateId: template.id,
    );
  }

  Checklist _addChecklist({
    required String name,
    String? folderId,
    required List<ChecklistItem> items,
    String? templateId,
  }) {
    final checklist = Checklist(
      id: const Uuid().v4(),
      name: name,
      items: items,
      createdAt: DateTime.now(),
      folderId: folderId,
      templateId: templateId,
    );
    unawaited(_box.put(checklist.id, checklist));
    state = [checklist, ...state];
    return checklist;
  }

  void renameChecklist(String checklistId, String name) {
    final checklist = _box.get(checklistId);
    if (checklist == null) return;
    checklist.name = name;
    _persist(checklist);
  }

  void moveToFolder(String checklistId, String? folderId) {
    final checklist = _box.get(checklistId);
    if (checklist == null) return;
    checklist.folderId = folderId;
    _persist(checklist);
  }

  void deleteChecklist(String checklistId) {
    unawaited(_box.delete(checklistId));
    state = state.where((c) => c.id != checklistId).toList();
  }

  /// Toggling a top-level item with subtasks cascades the new value down to
  /// every subtask. Toggling a subtask instead recomputes its parent: the
  /// parent is checked exactly when all of its subtasks are.
  void toggleItem(String checklistId, String itemId) {
    final checklist = _box.get(checklistId);
    if (checklist == null) return;
    for (final item in checklist.items) {
      if (item.id == itemId) {
        final newValue = !item.isChecked;
        item.isChecked = newValue;
        for (final subtask in item.subtasks) {
          subtask.isChecked = newValue;
        }
        _persist(checklist);
        return;
      }
      for (final subtask in item.subtasks) {
        if (subtask.id == itemId) {
          subtask.isChecked = !subtask.isChecked;
          item.isChecked = item.subtasks.every((s) => s.isChecked);
          _persist(checklist);
          return;
        }
      }
    }
  }

  void addItem(String checklistId, String title) {
    final checklist = _box.get(checklistId);
    if (checklist == null) return;
    checklist.items = [
      ...checklist.items,
      ChecklistItem(id: const Uuid().v4(), title: title),
    ];
    _persist(checklist);
  }

  /// Works for both top-level items and subtasks.
  void renameItem(String checklistId, String itemId, String title) {
    final checklist = _box.get(checklistId);
    if (checklist == null) return;
    for (final item in checklist.items) {
      if (item.id == itemId) {
        item.title = title;
        _persist(checklist);
        return;
      }
      for (final subtask in item.subtasks) {
        if (subtask.id == itemId) {
          subtask.title = title;
          _persist(checklist);
          return;
        }
      }
    }
  }

  /// Works for both top-level items and subtasks.
  void setItemNotes(String checklistId, String itemId, String? notes) {
    final checklist = _box.get(checklistId);
    if (checklist == null) return;
    for (final item in checklist.items) {
      if (item.id == itemId) {
        item.notes = notes;
        _persist(checklist);
        return;
      }
      for (final subtask in item.subtasks) {
        if (subtask.id == itemId) {
          subtask.notes = notes;
          _persist(checklist);
          return;
        }
      }
    }
  }

  /// Removes a top-level item (and any subtasks it has).
  void removeItem(String checklistId, String itemId) {
    final checklist = _box.get(checklistId);
    if (checklist == null) return;
    checklist.items = checklist.items
        .where((item) => item.id != itemId)
        .toList();
    _persist(checklist);
  }

  void addSubtask(String checklistId, String parentItemId, String title) {
    final checklist = _box.get(checklistId);
    if (checklist == null) return;
    for (final item in checklist.items) {
      if (item.id == parentItemId) {
        item.subtasks = [
          ...item.subtasks,
          ChecklistItem(id: const Uuid().v4(), title: title),
        ];
        // A freshly-added, unchecked subtask means the parent can no longer
        // be considered done.
        item.isChecked = item.subtasks.every((s) => s.isChecked);
        _persist(checklist);
        return;
      }
    }
  }

  void removeSubtask(String checklistId, String subtaskId) {
    final checklist = _box.get(checklistId);
    if (checklist == null) return;
    for (final item in checklist.items) {
      if (item.subtasks.any((s) => s.id == subtaskId)) {
        item.subtasks = item.subtasks.where((s) => s.id != subtaskId).toList();
        if (item.subtasks.isNotEmpty) {
          item.isChecked = item.subtasks.every((s) => s.isChecked);
        }
        _persist(checklist);
        return;
      }
    }
  }

  void resetProgress(String checklistId) {
    final checklist = _box.get(checklistId);
    if (checklist == null) return;
    for (final item in checklist.items) {
      item.isChecked = false;
      for (final subtask in item.subtasks) {
        subtask.isChecked = false;
      }
    }
    _persist(checklist);
  }

  void unfileChecklistsInFolder(String folderId) {
    for (final checklist in state) {
      if (checklist.folderId == folderId) {
        checklist.folderId = null;
        unawaited(checklist.save());
      }
    }
    // New list instance so Riverpod notifies listeners of the mutation above.
    state = [...state];
  }
}
