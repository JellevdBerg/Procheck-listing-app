import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_setup.dart';
import '../models/project.dart';
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

  void _sortState() {
    final sorted = [...state]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    state = sorted;
  }

  Project addProject(String name) {
    final project = Project(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now(),
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

  void deleteProject(String id) {
    // Unfile any tasks that live in this project before deleting it.
    _ref.read(tasksProvider.notifier).unfileTasksInProject(id);
    unawaited(_box.delete(id));
    state = state.where((p) => p.id != id).toList();
  }
}
