import 'package:hive_flutter/hive_flutter.dart';

import '../models/checklist.dart';
import '../models/checklist_item.dart';
import '../models/checklist_template.dart';
import '../models/folder.dart';
import '../models/template_item.dart';

const folderBoxName = 'folders';
const checklistBoxName = 'checklists';
const templateBoxName = 'templates';

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

  _registerAdapter(ChecklistItemAdapter());
  _registerAdapter(TemplateItemAdapter());
  _registerAdapter(ChecklistTemplateAdapter());
  _registerAdapter(FolderAdapter());
  _registerAdapter(ChecklistAdapter());

  await Future.wait([
    Hive.openBox<Folder>(folderBoxName),
    Hive.openBox<Checklist>(checklistBoxName),
    Hive.openBox<ChecklistTemplate>(templateBoxName),
  ]);
}

/// Re-running [setUpHive] (e.g. once per widget test) must not re-register
/// an adapter for a typeId that's already registered.
void _registerAdapter<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter(adapter);
  }
}
