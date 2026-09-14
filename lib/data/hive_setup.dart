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

  Hive.registerAdapter(ChecklistItemAdapter());
  Hive.registerAdapter(TemplateItemAdapter());
  Hive.registerAdapter(ChecklistTemplateAdapter());
  Hive.registerAdapter(FolderAdapter());
  Hive.registerAdapter(ChecklistAdapter());

  await Future.wait([
    Hive.openBox<Folder>(folderBoxName),
    Hive.openBox<Checklist>(checklistBoxName),
    Hive.openBox<ChecklistTemplate>(templateBoxName),
  ]);
}
