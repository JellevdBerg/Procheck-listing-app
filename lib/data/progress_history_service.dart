import 'dart:async';

import 'package:hive/hive.dart';

import 'hive_setup.dart';

/// Persists a daily snapshot of each workspace's overall task-completion
/// percentage, so the Dashboard's "Overall progress" stat can show a trend
/// against an earlier day rather than just the current number. There's
/// nothing to compare against on the very first day this runs for a given
/// workspace — [previousDayPercent] returns null then, and the Dashboard
/// simply omits the trend arrow.
class ProgressHistoryService {
  ProgressHistoryService._();

  static final ProgressHistoryService instance = ProgressHistoryService._();

  /// [previousDayPercent] only ever needs the most recent prior day, so
  /// anything older than this is pruned on write rather than kept forever.
  static const _retentionDays = 30;

  Box<double> get _box => Hive.box<double>(progressHistoryBoxName);

  String _keyFor(String workspaceId, DateTime date) =>
      '$workspaceId|${_isoDate(date)}';

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Records today's [percent] for [workspaceId] the first time this is
  /// called on a given day — safe to call from a build method on every
  /// rebuild without spamming writes, since every call after the first
  /// today is a no-op. Also prunes this workspace's entries older than
  /// [_retentionDays], so the box doesn't grow forever.
  void recordIfNeeded(String workspaceId, double percent) {
    final today = DateTime.now();
    final key = _keyFor(workspaceId, today);
    if (_box.containsKey(key)) return;
    unawaited(_box.put(key, percent));
    unawaited(_pruneOldEntries(workspaceId, today));
  }

  Future<void> _pruneOldEntries(String workspaceId, DateTime today) async {
    final cutoff = today.subtract(const Duration(days: _retentionDays));
    final prefix = '$workspaceId|';
    final staleKeys = _box.keys.where((key) {
      if (key is! String || !key.startsWith(prefix)) return false;
      final date = DateTime.tryParse(key.substring(prefix.length));
      return date != null && date.isBefore(cutoff);
    });
    if (staleKeys.isEmpty) return;
    await _box.deleteAll(staleKeys);
  }

  /// The most recently recorded percentage for [workspaceId] from a day
  /// before today, or null if none exists yet. Walks backward from
  /// yesterday looking up each day's key directly, instead of scanning
  /// every key in the box.
  double? previousDayPercent(String workspaceId) {
    final today = DateTime.now();
    for (var daysAgo = 1; daysAgo <= _retentionDays; daysAgo++) {
      final value = _box.get(
        _keyFor(workspaceId, today.subtract(Duration(days: daysAgo))),
      );
      if (value != null) return value;
    }
    return null;
  }
}
