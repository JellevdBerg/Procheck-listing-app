import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:procheck/data/backup_service.dart';
import 'package:procheck/models/project.dart';
import 'package:procheck/models/subtask.dart';
import 'package:procheck/models/task.dart';
import 'package:procheck/models/task_template.dart';
import 'package:procheck/models/template_subtask.dart';
import 'package:procheck/providers/settings_provider.dart';

void main() {
  test('backup round-trip preserves every field', () {
    final project = Project(
      id: 'p1',
      name: 'Groceries',
      createdAt: DateTime(2026, 1, 1),
      lastOpenedAt: DateTime(2026, 1, 2),
      colorIndex: 4,
    );
    final task = Task(
      id: 't1',
      title: 'Buy milk',
      createdAt: DateTime(2026, 1, 1, 12),
      isChecked: true,
      notes: 'oat milk please',
      projectId: 'p1',
      templateId: 'tpl1',
      subtasks: [Subtask(id: 's1', title: 'Check expiry', isChecked: false)],
    );
    final template = TaskTemplate(
      id: 'tpl1',
      name: 'Shopping run',
      createdAt: DateTime(2026, 1, 1),
      subtasks: [TemplateSubtask(id: 'ts1', title: 'Bring bags')],
    );
    const settings = AppSettings(
      themeMode: ThemeMode.dark,
      accentIndex: 3,
      reduceMotion: true,
    );

    final json = buildBackupJson(
      projects: [project],
      tasks: [task],
      taskTemplates: [template],
      settings: settings,
    );

    final restored = parseBackupJson(json);

    expect(restored.projects, hasLength(1));
    expect(restored.projects.single.id, 'p1');
    expect(restored.projects.single.name, 'Groceries');
    expect(restored.projects.single.colorIndex, 4);
    expect(restored.projects.single.lastOpenedAt, DateTime(2026, 1, 2));

    expect(restored.tasks, hasLength(1));
    final restoredTask = restored.tasks.single;
    expect(restoredTask.id, 't1');
    expect(restoredTask.isChecked, isTrue);
    expect(restoredTask.notes, 'oat milk please');
    expect(restoredTask.projectId, 'p1');
    expect(restoredTask.templateId, 'tpl1');
    expect(restoredTask.subtasks, hasLength(1));
    expect(restoredTask.subtasks.single.title, 'Check expiry');

    expect(restored.taskTemplates, hasLength(1));
    expect(restored.taskTemplates.single.name, 'Shopping run');
    expect(restored.taskTemplates.single.subtasks.single.title, 'Bring bags');

    expect(restored.settings.themeMode, ThemeMode.dark);
    expect(restored.settings.accentIndex, 3);
    expect(restored.settings.reduceMotion, isTrue);
  });

  test('rejects a backup from a newer, unknown schema version', () {
    expect(
      () => parseBackupJson({
        'schemaVersion': backupSchemaVersion + 1,
        'projects': [],
        'tasks': [],
        'taskTemplates': [],
        'settings': {},
      }),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('rejects a file that is not a ProCheck backup at all', () {
    expect(
      () => parseBackupJson({'hello': 'world'}),
      throwsA(isA<BackupFormatException>()),
    );
  });
}
