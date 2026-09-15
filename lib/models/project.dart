import 'package:hive/hive.dart';

part 'project.g.dart';

@HiveType(typeId: 2)
class Project extends HiveObject {
  Project({
    required this.id,
    required this.name,
    required this.createdAt,
    this.lastOpenedAt,
    this.colorIndex = 0,
    this.archived = false,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  DateTime createdAt;

  /// Null until the project has been opened at least once.
  @HiveField(3)
  DateTime? lastOpenedAt;

  /// Index into [accentPalette] (see settings_provider.dart). Projects saved
  /// before this field existed have no value for it on disk, so a
  /// [defaultValue] is required — without it, the generated adapter casts
  /// the missing field straight to `int` and crashes on startup.
  @HiveField(4, defaultValue: 0)
  int colorIndex;

  /// Archived projects drop out of the main grid (and its search) without
  /// being destroyed — their tasks, color, and history are untouched, and
  /// they're still browsable/searchable from the Archived tab.
  @HiveField(5, defaultValue: false)
  bool archived;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'lastOpenedAt': lastOpenedAt?.toIso8601String(),
    'colorIndex': colorIndex,
    'archived': archived,
  };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastOpenedAt: json['lastOpenedAt'] == null
        ? null
        : DateTime.parse(json['lastOpenedAt'] as String),
    colorIndex: json['colorIndex'] as int? ?? 0,
    archived: json['archived'] as bool? ?? false,
  );
}
