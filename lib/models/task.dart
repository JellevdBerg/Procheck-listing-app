import 'package:hive/hive.dart';

import 'attachment.dart';
import 'subtask.dart';
import 'task_priority.dart';

part 'task.g.dart';

@HiveType(typeId: 1)
class Task extends HiveObject {
  Task({
    required this.id,
    required this.title,
    required this.createdAt,
    this.isChecked = false,
    this.notes,
    List<Subtask>? subtasks,
    this.projectId,
    this.templateId,
    this.dueDate,
    double? sortOrder,
    this.priorityIndex = 0,
    List<Attachment>? attachments,
    this.workspaceId,
  }) : subtasks = subtasks ?? [],
       attachments = attachments ?? [],
       sortOrder = sortOrder ?? createdAt.millisecondsSinceEpoch.toDouble();

  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  bool isChecked;

  @HiveField(3)
  String? notes;

  @HiveField(4)
  List<Subtask> subtasks;

  /// Null when the task isn't filed under any project.
  @HiveField(5)
  String? projectId;

  @HiveField(6)
  DateTime createdAt;

  /// The template this task was instantiated from, if any.
  @HiveField(7)
  String? templateId;

  /// When set, a local notification is scheduled for this moment (see
  /// NotificationService) — cancelled/rescheduled whenever this changes,
  /// and cancelled outright once the task is checked off or deleted.
  @HiveField(8)
  DateTime? dueDate;

  /// Controls this task's position within whichever list it's shown in (a
  /// project's task list, or the home screen's unfiled tasks) — higher
  /// sorts first. Defaults to its creation time so new tasks land at the
  /// top like before; dragging a task to reorder it re-assigns this to a
  /// small integer instead (see TasksNotifier.reorderTasks), which — being
  /// far smaller than any real timestamp — always sorts below any
  /// not-yet-manually-ordered task without disturbing the others' relative
  /// order. Tasks saved before this field existed default to 0, i.e. below
  /// everything else, falling back to createdAt to order amongst themselves.
  @HiveField(9, defaultValue: 0.0)
  double sortOrder;

  /// [TaskPriority.index] — stored as a plain int rather than a Hive enum
  /// type, since it's just a small fixed set of values.
  @HiveField(10, defaultValue: 0)
  int priorityIndex;

  @HiveField(11, defaultValue: [])
  List<Attachment> attachments;

  /// Which workspace this task belongs to (see AppSettings.workspaceIds in
  /// settings_provider.dart) — set even for tasks filed under a project,
  /// since unfiled tasks have no project to inherit it from. Null on tasks
  /// saved before workspaces had real data isolation, backfilled to the
  /// first workspace's id at startup (see TasksNotifier).
  @HiveField(12)
  String? workspaceId;

  TaskPriority get priority => TaskPriority.fromIndex(priorityIndex);
  set priority(TaskPriority value) => priorityIndex = value.index;

  bool get hasSubtasks => subtasks.isNotEmpty;

  int get completedSubtaskCount =>
      subtasks.where((subtask) => subtask.isChecked).length;

  double get subtaskProgress =>
      subtasks.isEmpty ? 0 : completedSubtaskCount / subtasks.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isChecked': isChecked,
    'notes': notes,
    'subtasks': subtasks.map((s) => s.toJson()).toList(),
    'projectId': projectId,
    'createdAt': createdAt.toIso8601String(),
    'templateId': templateId,
    'dueDate': dueDate?.toIso8601String(),
    'sortOrder': sortOrder,
    'priorityIndex': priorityIndex,
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'workspaceId': workspaceId,
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as String,
    title: json['title'] as String,
    isChecked: json['isChecked'] as bool? ?? false,
    notes: json['notes'] as String?,
    subtasks: (json['subtasks'] as List<dynamic>? ?? [])
        .map((s) => Subtask.fromJson(s as Map<String, dynamic>))
        .toList(),
    projectId: json['projectId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    templateId: json['templateId'] as String?,
    dueDate: json['dueDate'] == null
        ? null
        : DateTime.parse(json['dueDate'] as String),
    sortOrder: (json['sortOrder'] as num?)?.toDouble(),
    priorityIndex: json['priorityIndex'] as int? ?? 0,
    attachments: (json['attachments'] as List<dynamic>? ?? [])
        .map((a) => Attachment.fromJson(a as Map<String, dynamic>))
        .toList(),
    workspaceId: json['workspaceId'] as String?,
  );
}
