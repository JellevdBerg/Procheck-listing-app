/// A task's priority. Stored on [Task] as this enum's [index] (a plain
/// `int` field) rather than as its own Hive type, since it's just a small
/// fixed set of values — matches how [ThemeMode] is stored in
/// AppSettings.
enum TaskPriority {
  none,
  low,
  med,
  high;

  static TaskPriority fromIndex(int? index) {
    if (index == null || index < 0 || index >= TaskPriority.values.length) {
      return TaskPriority.none;
    }
    return TaskPriority.values[index];
  }

  String get label => switch (this) {
    TaskPriority.none => 'None',
    TaskPriority.low => 'Low',
    TaskPriority.med => 'Med',
    TaskPriority.high => 'High',
  };
}
