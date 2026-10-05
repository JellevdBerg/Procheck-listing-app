import 'package:collection/collection.dart';
import 'package:hive/hive.dart';

import 'activity_entry.dart';
import 'project_comment.dart';

part 'project.g.dart';

/// Distinguishes "leave this field as-is" from "set it to null" in
/// [Project.copyWith], since a bare `= null` default can't tell the two
/// apart.
const _unset = Object();

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

  /// Builds a new [Project] with the given fields replaced — used instead
  /// of mutating this instance's fields so that value-equality-based
  /// Riverpod selectors (see [operator ==]) can tell an edited project
  /// apart from the unedited one still referenced by whatever watched it
  /// before the edit. Pass `null` explicitly for [lastOpenedAt]/
  /// [workspaceId] to clear them; omit to leave them as-is.
  Project copyWith({
    String? name,
    Object? lastOpenedAt = _unset,
    int? colorIndex,
    bool? archived,
    bool? favorite,
    List<ActivityEntry>? activityLog,
    List<ProjectComment>? comments,
    Object? workspaceId = _unset,
  }) => Project(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt,
    lastOpenedAt: identical(lastOpenedAt, _unset)
        ? this.lastOpenedAt
        : lastOpenedAt as DateTime?,
    colorIndex: colorIndex ?? this.colorIndex,
    archived: archived ?? this.archived,
    favorite: favorite ?? this.favorite,
    activityLog: activityLog ?? [...this.activityLog],
    comments: comments ?? [...this.comments],
    workspaceId: identical(workspaceId, _unset)
        ? this.workspaceId
        : workspaceId as String?,
  );

  static const _activityLogEquality = ListEquality<ActivityEntry>();
  static const _commentsEquality = ListEquality<ProjectComment>();

  @override
  bool operator ==(Object other) =>
      other is Project &&
      other.id == id &&
      other.name == name &&
      other.createdAt == createdAt &&
      other.lastOpenedAt == lastOpenedAt &&
      other.colorIndex == colorIndex &&
      other.archived == archived &&
      other.favorite == favorite &&
      other.workspaceId == workspaceId &&
      _activityLogEquality.equals(other.activityLog, activityLog) &&
      _commentsEquality.equals(other.comments, comments);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    createdAt,
    lastOpenedAt,
    colorIndex,
    archived,
    favorite,
    workspaceId,
    _activityLogEquality.hash(activityLog),
    _commentsEquality.hash(comments),
  );

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
