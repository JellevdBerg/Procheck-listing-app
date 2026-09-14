import 'package:hive_flutter/hive_flutter.dart';

import '../models/project.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../models/task_template.dart';
import '../models/template_subtask.dart';

const projectBoxName = 'projects';
const taskBoxName = 'tasks';
const taskTemplateBoxName = 'task_templates';
const settingsBoxName = 'settings';

/// Initializes Hive and opens the app's boxes.
///
/// Pass [testDirectoryPath] in tests to store data on disk without going
/// through the `path_provider` platform channel (used by [Hive.initFlutter]).
Future<void> setUpHive({String? testDirectoryPath}) async {
  if (testDirectoryPath != null) {
    Hive.init(testDirectoryPath);
  } else {
    await Hive.initFlutter();
  }

  _registerAdapter(SubtaskAdapter());
  _registerAdapter(TaskAdapter());
  _registerAdapter(ProjectAdapter());
  _registerAdapter(TemplateSubtaskAdapter());
  _registerAdapter(TaskTemplateAdapter());

  await Future.wait([
    Hive.openBox<Project>(projectBoxName),
    Hive.openBox<Task>(taskBoxName),
    Hive.openBox<TaskTemplate>(taskTemplateBoxName),
    Hive.openBox(settingsBoxName),
  ]);
}

/// Re-running [setUpHive] (e.g. once per widget test) must not re-register
/// an adapter for a typeId that's already registered.
void _registerAdapter<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter(adapter);
  }
}
