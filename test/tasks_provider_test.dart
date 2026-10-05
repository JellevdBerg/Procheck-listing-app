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

  test('completing a daily-recurring task spawns the next occurrence', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(tasksProvider.notifier);
    final task = notifier.addBlankTask(title: 'Take vitamins');
    final due = DateTime(2026, 1, 1, 9, 0);
    notifier.setTaskDueDate(task.id, due);
    notifier.setTaskRecurrence(task.id, RecurrenceRule.daily);

    notifier.toggleTask(task.id);

    final tasks = container.read(tasksProvider);
    final completed = tasks.firstWhere((t) => t.id == task.id);
    expect(completed.isChecked, isTrue);

    final next = tasks.firstWhere(
      (t) => t.title == 'Take vitamins' && t.id != task.id,
    );
    expect(next.isChecked, isFalse);
    expect(next.dueDate, due.add(const Duration(days: 1)));
    expect(next.recurrence, RecurrenceRule.daily);
  });

  test('completing a non-recurring task spawns nothing', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(tasksProvider.notifier);
    final task = notifier.addBlankTask(title: 'One-off errand');
    notifier.setTaskDueDate(task.id, DateTime.now().add(const Duration(days: 1)));

    notifier.toggleTask(task.id);

    expect(
      container.read(tasksProvider).where((t) => t.title == 'One-off errand'),
      hasLength(1),
    );
  });

  test('un-completing a recurring task does not spawn another occurrence', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(tasksProvider.notifier);
    final task = notifier.addBlankTask(title: 'Water the plants weekly');
    notifier.setTaskDueDate(task.id, DateTime.now().add(const Duration(days: 1)));
    notifier.setTaskRecurrence(task.id, RecurrenceRule.weekly);
    const title = 'Water the plants weekly';

    notifier.toggleTask(task.id); // complete -> spawns next occurrence
    expect(
      container.read(tasksProvider).where((t) => t.title == title),
      hasLength(2),
    );

    notifier.toggleTask(task.id); // un-complete the original
    expect(
      container.read(tasksProvider).where((t) => t.title == title),
      hasLength(2),
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
