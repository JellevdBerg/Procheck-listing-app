import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:procheck/data/hive_setup.dart';
import 'package:procheck/data/progress_history_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'procheck_progress_history_test_',
    );
    await setUpHive(testDirectoryPath: tempDir.path);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  Box<double> box() => Hive.box<double>(progressHistoryBoxName);

  String keyFor(String workspaceId, DateTime date) =>
      '$workspaceId|${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  test('previousDayPercent returns null when there is no history', () {
    expect(
      ProgressHistoryService.instance.previousDayPercent('empty-workspace'),
      isNull,
    );
  });

  test('previousDayPercent finds the most recent prior day', () async {
    const workspaceId = 'ws-recent';
    final today = DateTime.now();
    await box().put(keyFor(workspaceId, today.subtract(const Duration(days: 5))), 10);
    await box().put(keyFor(workspaceId, today.subtract(const Duration(days: 2))), 55);

    expect(
      ProgressHistoryService.instance.previousDayPercent(workspaceId),
      55,
    );
  });

  test('previousDayPercent ignores entries from other workspaces', () async {
    final today = DateTime.now();
    await box().put(
      keyFor('ws-other', today.subtract(const Duration(days: 1))),
      99,
    );

    expect(
      ProgressHistoryService.instance.previousDayPercent('ws-isolated'),
      isNull,
    );
  });

  test('recordIfNeeded prunes entries older than the retention window',
      () async {
    const workspaceId = 'ws-prune';
    final today = DateTime.now();
    final staleKey = keyFor(workspaceId, today.subtract(const Duration(days: 40)));
    await box().put(staleKey, 20);

    ProgressHistoryService.instance.recordIfNeeded(workspaceId, 80);
    // recordIfNeeded fires the prune without awaiting it.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(box().containsKey(staleKey), isFalse);
    expect(box().containsKey(keyFor(workspaceId, today)), isTrue);
  });

  test('recordIfNeeded is a no-op if today was already recorded', () async {
    const workspaceId = 'ws-idempotent';
    final todayKey = keyFor(workspaceId, DateTime.now());

    ProgressHistoryService.instance.recordIfNeeded(workspaceId, 10);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    ProgressHistoryService.instance.recordIfNeeded(workspaceId, 90);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(box().get(todayKey), 10);
  });
}
