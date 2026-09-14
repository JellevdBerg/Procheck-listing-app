import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_setup.dart';
import '../models/folder.dart';
import 'checklists_provider.dart';

final foldersProvider = StateNotifierProvider<FoldersNotifier, List<Folder>>((
  ref,
) {
  return FoldersNotifier(ref);
});

/// Persistence to Hive is fire-and-forget: [state] is the source of truth
/// for the UI and is updated synchronously, while the on-disk copy catches
/// up in the background.
class FoldersNotifier extends StateNotifier<List<Folder>> {
  FoldersNotifier(this._ref) : super(_box.values.toList()) {
    _sortState();
  }

  final Ref _ref;

  static Box<Folder> get _box => Hive.box<Folder>(folderBoxName);

  void _sortState() {
    final sorted = [...state]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    state = sorted;
  }

  Folder addFolder(String name) {
    final folder = Folder(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now(),
    );
    unawaited(_box.put(folder.id, folder));
    state = [...state, folder];
    _sortState();
    return folder;
  }

  void renameFolder(String id, String name) {
    final folder = _box.get(id);
    if (folder == null) return;
    folder.name = name;
    unawaited(folder.save());
    state = [
      for (final f in state)
        if (f.id == id) folder else f,
    ];
    _sortState();
  }

  void deleteFolder(String id) {
    // Unfile any checklists that live in this folder before deleting it.
    _ref.read(checklistsProvider.notifier).unfileChecklistsInFolder(id);
    unawaited(_box.delete(id));
    state = state.where((f) => f.id != id).toList();
  }
}
