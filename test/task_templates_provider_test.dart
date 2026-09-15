import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:procheck/data/hive_setup.dart';
import 'package:procheck/models/attachment.dart';
import 'package:procheck/providers/task_templates_provider.dart';
import 'package:procheck/providers/tasks_provider.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'procheck_templates_test_',
    );
    await setUpHive(testDirectoryPath: tempDir.path);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test(
    'a task created from a template with notes and an attachment gets both',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final template = container
          .read(taskTemplatesProvider.notifier)
          .addTemplate(
            'Onboard a client',
            ['Send welcome email'],
            notes: 'Remember to CC the account manager.',
            attachments: [
              Attachment(name: 'checklist.pdf', size: 2048, path: '/tmp/checklist.pdf'),
            ],
          );

      final task = container
          .read(tasksProvider.notifier)
          .addFromTemplate(template: template);

      expect(task.notes, 'Remember to CC the account manager.');
      expect(task.attachments, hasLength(1));
      expect(task.attachments.single.name, 'checklist.pdf');

      // The task's attachment is its own copy, not the template's instance.
      expect(
        identical(task.attachments.single, template.attachments.single),
        isFalse,
      );
    },
  );
}
