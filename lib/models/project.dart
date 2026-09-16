import 'package:hive/hive.dart';

import 'activity_entry.dart';
import 'project_comment.dart';

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
    this.favorite = false,
    List<ActivityEntry>? activityLog,
    List<ProjectComment>? comments,
    this.workspaceId,
  }) : activityLog = activityLog ?? [],
       comments = comments ?? [];

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

  /// Shown, pinned, in the sidebar's Favorites section.
  @HiveField(6, defaultValue: false)
  bool favorite;

  /// A chronological log of notable events for this project (created, task
  /// added/completed/edited), newest last — shown in the project detail
  /// screen's Activity panel.
  @HiveField(7, defaultValue: [])
  List<ActivityEntry> activityLog;

  @HiveField(8, defaultValue: [])
  List<ProjectComment> comments;

  /// Which workspace this project belongs to (see AppSettings.workspaceIds
  /// in settings_provider.dart) — null on projects saved before workspaces
  /// had real data isolation, backfilled to the first workspace's id at
  /// startup (see ProjectsNotifier).
  @HiveField(9)
  String? workspaceId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'lastOpenedAt': lastOpenedAt?.toIso8601String(),
    'colorIndex': colorIndex,
    'archived': archived,
    'favorite': favorite,
    'activityLog': activityLog.map((a) => a.toJson()).toList(),
    'comments': comments.map((c) => c.toJson()).toList(),
    'workspaceId': workspaceId,
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
    favorite: json['favorite'] as bool? ?? false,
    activityLog: (json['activityLog'] as List<dynamic>? ?? [])
        .map((a) => ActivityEntry.fromJson(a as Map<String, dynamic>))
        .toList(),
    comments: (json['comments'] as List<dynamic>? ?? [])
        .map((c) => ProjectComment.fromJson(c as Map<String, dynamic>))
        .toList(),
    workspaceId: json['workspaceId'] as String?,
  );
}
