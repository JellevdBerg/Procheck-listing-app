import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:procheck/data/hive_setup.dart';
import 'package:procheck/models/project.dart';
import 'package:procheck/models/task.dart';
import 'package:procheck/providers/projects_provider.dart';
import 'package:procheck/providers/settings_provider.dart';
import 'package:procheck/providers/task_templates_provider.dart';
import 'package:procheck/providers/tasks_provider.dart';

void main() {
  late Directory tempDir;

  // Same shared-Hive-state convention as the rest of this test suite (see
  // widget_test.dart's note by pumpApp): setUpAll/tearDownAll once for the
  // group, tests ordered so an earlier one's data doesn't confuse a later
  // one's assertions.
  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'procheck_workspace_test_',
    );
    await setUpHive(testDirectoryPath: tempDir.path);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test('projects/tasks/templates in one workspace are invisible from another', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settingsNotifier = container.read(settingsProvider.notifier);
    final projectsNotifier = container.read(projectsProvider.notifier);
    final tasksNotifier = container.read(tasksProvider.notifier);
    final templatesNotifier = container.read(taskTemplatesProvider.notifier);

    // Starts in the default "Personal" workspace.
    final personalProject = projectsNotifier.addProject('Personal project');
    tasksNotifier.addBlankTask(title: 'Personal unfiled task');
    templatesNotifier.addTemplate('Personal template', const []);

    expect(
      container.read(projectsProvider).map((p) => p.id),
      contains(personalProject.id),
    );

    // Add and switch to a second, brand-new workspace.
    settingsNotifier.addWorkspace('Work');
    expect(container.read(settingsProvider).currentWorkspaceName, 'Work');

    // The new workspace starts completely empty — none of "Personal"'s data
    // leaks through.
    expect(container.read(projectsProvider), isEmpty);
    expect(container.read(tasksProvider), isEmpty);
    expect(container.read(taskTemplatesProvider), isEmpty);

    final workProject = projectsNotifier.addProject('Work project');
    tasksNotifier.addBlankTask(title: 'Work unfiled task');
    templatesNotifier.addTemplate('Work template', const []);

    expect(container.read(projectsProvider).single.id, workProject.id);
    expect(container.read(tasksProvider).single.title, 'Work unfiled task');
    expect(
      container.read(taskTemplatesProvider).single.name,
      'Work template',
    );

    // Switching back to "Personal" restores its data and hides "Work"'s.
    settingsNotifier.cycleWorkspace();
    expect(container.read(settingsProvider).currentWorkspaceName, 'Personal');
    expect(container.read(projectsProvider).single.id, personalProject.id);
    expect(
      container.read(tasksProvider).single.title,
      'Personal unfiled task',
    );
    expect(
      container.read(taskTemplatesProvider).single.name,
      'Personal template',
    );
  });

  test('removing a workspace cascade-deletes only its own data', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settingsNotifier = container.read(settingsProvider.notifier);
    final projectsNotifier = container.read(projectsProvider.notifier);
    final tasksNotifier = container.read(tasksProvider.notifier);
    final templatesNotifier = container.read(taskTemplatesProvider.notifier);

    // From the previous test: "Personal" (currently active) and "Work"
    // already exist, each with one project/task/template.
    final settingsBefore = container.read(settingsProvider);
    expect(settingsBefore.workspaceNames, ['Personal', 'Work']);
    final workIndex = settingsBefore.workspaceNames.indexOf('Work');
    final workId = settingsBefore.workspaceIds[workIndex];

    expect(projectsNotifier.countForWorkspace(workId), 1);
    expect(tasksNotifier.countForWorkspace(workId), 1);
    expect(templatesNotifier.countForWorkspace(workId), 1);

    // Cascade-delete "Work"'s data (what the sidebar's confirm dialog does
    // before calling removeWorkspace), then drop the workspace itself.
    projectsNotifier.deleteAllForWorkspace(workId);
    tasksNotifier.deleteAllForWorkspace(workId);
    templatesNotifier.deleteAllForWorkspace(workId);
    final removed = settingsNotifier.removeWorkspace(workIndex);

    expect(removed, isTrue);
    expect(container.read(settingsProvider).workspaceNames, ['Personal']);
    expect(projectsNotifier.countForWorkspace(workId), 0);
    expect(tasksNotifier.countForWorkspace(workId), 0);
    expect(templatesNotifier.countForWorkspace(workId), 0);

    // "Personal"'s own data (from the previous test) is untouched.
    expect(container.read(projectsProvider), isNotEmpty);
    expect(container.read(tasksProvider), isNotEmpty);
    expect(container.read(taskTemplatesProvider), isNotEmpty);
  });

  test('a project/task with no workspaceId is migrated onto the first workspace', () async {
    // Simulate data saved before this feature existed: put a Project and a
    // Task directly into the boxes with workspaceId left null, bypassing
    // the notifiers entirely.
    final projectBox = Hive.box<Project>(projectBoxName);
    final taskBox = Hive.box<Task>(taskBoxName);
    final legacyProject = Project(
      id: 'legacy-project',
      name: 'Legacy project',
      createdAt: DateTime.now(),
    );
    final legacyTask = Task(
      id: 'legacy-task',
      title: 'Legacy unfiled task',
      createdAt: DateTime.now(),
    );
    await projectBox.put(legacyProject.id, legacyProject);
    await taskBox.put(legacyTask.id, legacyTask);
    expect(legacyProject.workspaceId, isNull);
    expect(legacyTask.workspaceId, isNull);

    // A fresh container re-runs each notifier's constructor, which is where
    // the backfill happens — reading projectsProvider/tasksProvider is what
    // actually constructs them (they're lazy), so that has to come before
    // checking the backfill took effect.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final firstWorkspaceId = container.read(settingsProvider).workspaceIds.first;
    final projects = container.read(projectsProvider);
    final tasks = container.read(tasksProvider);

    expect(legacyProject.workspaceId, firstWorkspaceId);
    expect(legacyTask.workspaceId, firstWorkspaceId);
    expect(projects.map((p) => p.id), contains('legacy-project'));
    expect(tasks.map((t) => t.id), contains('legacy-task'));
  });
}
