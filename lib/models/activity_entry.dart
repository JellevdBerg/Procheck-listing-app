import 'package:hive/hive.dart';

part 'activity_entry.g.dart';

/// What kind of event a project's [ActivityEntry] records — drives which
/// icon/color the Activity panel renders it with.
enum ActivityKind {
  projectCreated,
  taskAdded,
  taskCompleted,
  taskEdited;

  static ActivityKind fromIndex(int? index) {
    if (index == null || index < 0 || index >= ActivityKind.values.length) {
      return ActivityKind.taskEdited;
    }
    return ActivityKind.values[index];
  }
}

/// A single entry in a project's Activity log (see [Project.activityLog]).
/// [description] is pre-rendered text (e.g. `You completed "Buy milk"`)
/// rather than being reconstructed from structured fields — simpler, and
/// the log is display-only.
@HiveType(typeId: 6)
class ActivityEntry extends HiveObject {
  ActivityEntry({
    required this.kindIndex,
    required this.description,
    required this.timestamp,
  });

  @HiveField(0)
  int kindIndex;

  @HiveField(1)
  String description;

  @HiveField(2)
  DateTime timestamp;

  ActivityKind get kind => ActivityKind.fromIndex(kindIndex);

  Map<String, dynamic> toJson() => {
    'kindIndex': kindIndex,
    'description': description,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
    kindIndex: json['kindIndex'] as int? ?? ActivityKind.taskEdited.index,
    description: json['description'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
