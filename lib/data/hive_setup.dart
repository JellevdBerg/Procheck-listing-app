import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/project.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../models/task_template.dart';
import '../models/template_subtask.dart';

const projectBoxName = 'projects';
const taskBoxName = 'tasks';
const taskTemplateBoxName = 'task_templates';
const settingsBoxName = 'settings';

/// Hive box files that live directly in the data directory (each has a
/// matching `.lock` file), used when migrating data to a new location.
const _boxFileNames = [
  projectBoxName,
  taskBoxName,
  taskTemplateBoxName,
  settingsBoxName,
];

/// Initializes Hive and opens the app's boxes.
///
/// Pass [testDirectoryPath] in tests to store data on disk without going
/// through the `path_provider` platform channel.
Future<void> setUpHive({String? testDirectoryPath}) async {
  if (testDirectoryPath != null) {
    Hive.init(testDirectoryPath);
  } else if (!kIsWeb && Platform.isWindows) {
    Hive.init((await _windowsDataDirectory()).path);
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

/// Older versions stored data loose in the user's Documents folder — Windows'
/// "application documents directory" has no app-specific subfolder of its
/// own, so that's just the user's actual Documents. Data now lives under
/// `%LocalAppData%\ProCheck` instead. Any box not yet present there is
/// copied over from the old location the first time this runs; the
/// originals are left in place rather than deleted.
Future<Directory> _windowsDataDirectory() async {
  final localAppData = Platform.environment['LOCALAPPDATA'];
  final dataDir = localAppData != null
      ? Directory('$localAppData${Platform.pathSeparator}ProCheck')
      : await getApplicationSupportDirectory();
  if (!dataDir.existsSync()) {
    dataDir.createSync(recursive: true);
  }

  final legacyDir = await getApplicationDocumentsDirectory();
  for (final name in _boxFileNames) {
    final newHiveFile = File(
      '${dataDir.path}${Platform.pathSeparator}$name.hive',
    );
    if (newHiveFile.existsSync()) continue;

    for (final suffix in ['.hive', '.lock']) {
      final legacyFile = File(
        '${legacyDir.path}${Platform.pathSeparator}$name$suffix',
      );
      if (legacyFile.existsSync()) {
        legacyFile.copySync(
          '${dataDir.path}${Platform.pathSeparator}$name$suffix',
        );
      }
    }
  }

  return dataDir;
}

/// Re-running [setUpHive] (e.g. once per widget test) must not re-register
/// an adapter for a typeId that's already registered.
void _registerAdapter<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter(adapter);
  }
}
