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
    unawaited(checklist.save());
    _replace(checklist);
  }

  void moveToFolder(String checklistId, String? folderId) {
    final checklist = _box.get(checklistId);
    if (checklist == null) return;
    checklist.folderId = folderId;
    unawaited(checklist.save());
    _replace(checklist);
  }

  void deleteChecklist(String checklistId) {
    unawaited(_box.delete(checklistId));
    state = state.where((c) => c.id != checklistId).toList();
  }

  void toggleItem(String checklistId, String itemId) {
    final checklist = _box.get(checklistId);
    if (checklist == null) return;
    for (final item in checklist.items) {
      if (item.id == itemId) {
        item.isChecked = !item.isChecked;
        break;
      }
    }
    unawaited(checklist.save());
    _replace(checklist);
  }

  void addItem(String checklistId, String title) {
    final checklist = _box.get(checklistId);
    if (checklist == null) return;
    checklist.items = [
      ...checklist.items,
      ChecklistItem(id: const Uuid().v4(), title: title),
    ];
    unawaited(checklist.save());
    _replace(checklist);
  }

  void renameItem(String checklistId, String itemId, String title) {
    final checklist = _box.get(checklistId);
    if (checklist == null) return;
    for (final item in checklist.items) {
      if (item.id == itemId) {
        item.title = title;
        break;
      }
    }
    unawaited(checklist.save());
    _replace(checklist);
  }

  void removeItem(String checklistId, String itemId) {
    final checklist = _box.get(checklistId);
    if (checklist == null) return;
    checklist.items = checklist.items
        .where((item) => item.id != itemId)
        .toList();
    unawaited(checklist.save());
    _replace(checklist);
  }

  void resetProgress(String checklistId) {
    final checklist = _box.get(checklistId);
    if (checklist == null) return;
    for (final item in checklist.items) {
      item.isChecked = false;
    }
    unawaited(checklist.save());
    _replace(checklist);
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
