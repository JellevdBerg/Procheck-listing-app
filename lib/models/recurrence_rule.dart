/// How often a completed [Task] should recur. Stored on [Task] as this
/// enum's [index] (a plain `int` field) rather than its own Hive type,
/// matching [TaskPriority]'s pattern.
enum RecurrenceRule {
  none,
  daily,
  weekly,
  biweekly,
  monthly;

  static RecurrenceRule fromIndex(int? index) {
    if (index == null || index < 0 || index >= RecurrenceRule.values.length) {
      return RecurrenceRule.none;
    }
    return RecurrenceRule.values[index];
  }

  String get label => switch (this) {
    RecurrenceRule.none => 'Never',
    RecurrenceRule.daily => 'Daily',
    RecurrenceRule.weekly => 'Weekly',
    RecurrenceRule.biweekly => 'Every 2 weeks',
    RecurrenceRule.monthly => 'Monthly',
  };

  /// The next occurrence of [date] under this rule. Months add calendar
  /// months (via [DateTime]'s own month-overflow rollover) rather than a
  /// fixed day count, so "monthly" tracks the same day-of-month instead of
  /// drifting with month length.
  DateTime next(DateTime date) => switch (this) {
    RecurrenceRule.none => date,
    RecurrenceRule.daily => date.add(const Duration(days: 1)),
    RecurrenceRule.weekly => date.add(const Duration(days: 7)),
    RecurrenceRule.biweekly => date.add(const Duration(days: 14)),
    RecurrenceRule.monthly => DateTime(
      date.year,
      date.month + 1,
      date.day,
      date.hour,
      date.minute,
    ),
  };
}
