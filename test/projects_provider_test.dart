import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:procheck/data/hive_setup.dart';
import 'package:procheck/providers/projects_provider.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('procheck_projects_test_');
    await setUpHive(testDirectoryPath: tempDir.path);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test('archiveProject/unarchiveProject toggle the archived flag', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(projectsProvider.notifier);
    final project = notifier.addProject('Old renovation', colorIndex: 3);
    expect(
      container
          .read(projectsProvider)
          .firstWhere((p) => p.id == project.id)
          .archived,
      isFalse,
    );

    notifier.archiveProject(project.id);
    final archived = container
        .read(projectsProvider)
        .firstWhere((p) => p.id == project.id);
    expect(archived.archived, isTrue);
    // Archiving must never touch the project's assigned color.
    expect(archived.colorIndex, 3);

    notifier.unarchiveProject(project.id);
    expect(
      container
          .read(projectsProvider)
          .firstWhere((p) => p.id == project.id)
          .archived,
      isFalse,
    );
  });
}
