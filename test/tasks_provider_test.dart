import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:procheck/data/hive_setup.dart';
import 'package:procheck/providers/tasks_provider.dart';

void main() {
  // TasksNotifier.toggleTask plays a checkoff chime via SoundService, whose
  // AudioPlayer construction reaches for a platform channel. With no real
  // platform implementation registered under this plain test() (not
  // testWidgets()) binding, the audioplayers package's own global-scope
  // init runs as a detached, un-awaitable Future internally — its
  // MissingPluginException surfaces as a late Zone error that
  // SoundService's own try/catch never gets a chance to see, rather than
  // a normal Future rejection. Mocking these two channels to resolve
  // cleanly avoids that failure mode entirely, rather than trying to catch
  // an error that never reaches our code.
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final channel in [
    const MethodChannel('xyz.luan/audioplayers.global'),
    const MethodChannel('xyz.luan/audioplayers'),
  ]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  }

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
