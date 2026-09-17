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
  /// today is a no-op.
  void recordIfNeeded(String workspaceId, double percent) {
    final key = _keyFor(workspaceId, DateTime.now());
    if (_box.containsKey(key)) return;
    unawaited(_box.put(key, percent));
  }

  /// The most recently recorded percentage for [workspaceId] from a day
  /// before today, or null if none exists yet.
  double? previousDayPercent(String workspaceId) {
    final todayKey = _keyFor(workspaceId, DateTime.now());
    final prefix = '$workspaceId|';
    DateTime? bestDate;
    double? bestValue;
    for (final key in _box.keys) {
      if (key is! String || key == todayKey || !key.startsWith(prefix)) {
        continue;
      }
      final date = DateTime.tryParse(key.substring(prefix.length));
      if (date == null) continue;
      if (bestDate == null || date.isAfter(bestDate)) {
        bestDate = date;
        bestValue = _box.get(key);
      }
    }
    return bestValue;
  }
}
