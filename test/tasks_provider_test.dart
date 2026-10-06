import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:procheck/data/hive_setup.dart';
import 'package:procheck/models/recurrence_rule.dart';
import 'package:procheck/providers/tasks_provider.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('procheck_provider_test_');
    await setUpHive(testDirectoryPath: tempDir.path);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test('setTaskDueDate stores and clears a due date', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(tasksProvider.notifier);
    final task = notifier.addBlankTask(title: 'Renew passport');
    final due = DateTime.now().add(const Duration(days: 3));

    notifier.setTaskDueDate(task.id, due);
    expect(
      container.read(tasksProvider).firstWhere((t) => t.id == task.id).dueDate,
      due,
    );

    notifier.setTaskDueDate(task.id, null);
    expect(
      container.read(tasksProvider).firstWhere((t) => t.id == task.id).dueDate,
      isNull,
    );
  });

  test('completing, un-completing, and deleting a task with a due date never '
      'throws even though NotificationService is not initialized in tests', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(tasksProvider.notifier);
    final task = notifier.addBlankTask(title: 'Pay invoice');
    final due = DateTime.now().add(const Duration(days: 1));

    expect(() => notifier.setTaskDueDate(task.id, due), returnsNormally);
    expect(() => notifier.toggleTask(task.id), returnsNormally); // complete
    expect(() => notifier.toggleTask(task.id), returnsNormally); // undo
    expect(() => notifier.deleteTask(task.id), returnsNormally);
  });

  test('reorderTasks reflects the given order the next time it is read', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(tasksProvider.notifier);
    final a = notifier.addBlankTask(title: 'A');
    final b = notifier.addBlankTask(title: 'B');
    final c = notifier.addBlankTask(title: 'C');

    // Drag A to the front, regardless of whatever order they started in.
    notifier.reorderTasks([a.id, c.id, b.id]);

    final reordered = container
        .read(tasksProvider)
        .where((t) => [a.id, b.id, c.id].contains(t.id))
        .map((t) => t.id)
        .toList();
    expect(reordered, [a.id, c.id, b.id]);
  });

  test(
    'completing a daily-recurring task with a due date replaces it with '
    'the next occurrence rather than leaving a checked-off copy behind',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(tasksProvider.notifier);
      final task = notifier.addBlankTask(title: 'Take vitamins');
      final due = DateTime(2026, 1, 1, 9, 0);
      notifier.setTaskDueDate(task.id, due);
      notifier.setTaskRecurrence(task.id, RecurrenceRule.daily);

      notifier.toggleTask(task.id);

      final matches = container
          .read(tasksProvider)
          .where((t) => t.title == 'Take vitamins');
      expect(matches, hasLength(1)); // the completed one is gone, not kept
      final next = matches.single;
      expect(next.id, isNot(task.id));
      expect(next.isChecked, isFalse);
      expect(next.dueDate, due.add(const Duration(days: 1)));
      expect(next.recurrence, RecurrenceRule.daily);
    },
  );

  test(
    'completing a recurring task with no due date still replaces it with '
    'a fresh unchecked occurrence (recurrence does not require a due date)',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(tasksProvider.notifier);
      final task = notifier.addBlankTask(title: 'Take out trash');
      notifier.setTaskRecurrence(task.id, RecurrenceRule.weekly);

      notifier.toggleTask(task.id);

      final matches = container
          .read(tasksProvider)
          .where((t) => t.title == 'Take out trash');
      expect(matches, hasLength(1));
      final next = matches.single;
      expect(next.id, isNot(task.id));
      expect(next.isChecked, isFalse);
      expect(next.dueDate, isNull);
      expect(next.recurrence, RecurrenceRule.weekly);
    },
  );

  test('completing a non-recurring task leaves it checked, nothing spawned', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(tasksProvider.notifier);
    final task = notifier.addBlankTask(title: 'One-off errand');
    notifier.setTaskDueDate(task.id, DateTime.now().add(const Duration(days: 1)));

    notifier.toggleTask(task.id);

    final matches = container
        .read(tasksProvider)
        .where((t) => t.title == 'One-off errand');
    expect(matches, hasLength(1));
    expect(matches.single.isChecked, isTrue);
  });

  test(
    'repeatedly completing a recurring task always leaves exactly one live '
    'occurrence, never an accumulating trail of finished ones',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(tasksProvider.notifier);
      final task = notifier.addBlankTask(title: 'Water the plants weekly');
      notifier.setTaskRecurrence(task.id, RecurrenceRule.weekly);
      const title = 'Water the plants weekly';

      var current = task;
      for (var i = 0; i < 3; i++) {
        notifier.toggleTask(current.id);
        final matches = container
            .read(tasksProvider)
            .where((t) => t.title == title);
        expect(matches, hasLength(1));
        current = matches.single;
        expect(current.isChecked, isFalse);
      }
    },
  );

  test('setTaskRecurrence is a no-op for a task filed under a project', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(tasksProvider.notifier);
    final task = notifier.addBlankTask(
      title: 'Project task',
      projectId: 'some-project',
    );

    notifier.setTaskRecurrence(task.id, RecurrenceRule.daily);

    expect(
      container.read(tasksProvider).firstWhere((t) => t.id == task.id).recurrence,
      RecurrenceRule.none,
    );
  });

  test('moveToProject clears recurrence when filing a recurring task', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(tasksProvider.notifier);
    final task = notifier.addBlankTask(title: 'Standalone, then filed');
    notifier.setTaskRecurrence(task.id, RecurrenceRule.monthly);

    notifier.moveToProject(task.id, 'some-project');

    expect(
      container.read(tasksProvider).firstWhere((t) => t.id == task.id).recurrence,
      RecurrenceRule.none,
    );
  });

  test('restoreTask brings a deleted standalone task back', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(tasksProvider.notifier);
    final task = notifier.addBlankTask(title: 'Water the plants');

    notifier.deleteTask(task.id);
    expect(container.read(tasksProvider).any((t) => t.id == task.id), isFalse);

    notifier.restoreTask(task);
    expect(container.read(tasksProvider).any((t) => t.id == task.id), isTrue);
  });
}
