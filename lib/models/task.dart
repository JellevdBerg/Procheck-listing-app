import 'package:collection/collection.dart';
import 'package:hive/hive.dart';

import 'attachment.dart';
import 'recurrence_rule.dart';
import 'subtask.dart';
import 'task_priority.dart';

part 'task.g.dart';

/// Distinguishes "leave this field as-is" from "set it to null" in
/// [Task.copyWith], since a bare `= null` default can't tell the two apart.
const _unset = Object();

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
    this.dueDateEnd,
    double? sortOrder,
    this.priorityIndex = 0,
    List<Attachment>? attachments,
    this.workspaceId,
    this.recurrenceIndex = 0,
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

  /// End of a due-date range, when this task's due date spans more than one
  /// day (e.g. "due Sep 20 - Sep 25") rather than a single moment. Null for
  /// an ordinary single-day due date. Reminder notifications still fire off
  /// [dueDate] alone; this only affects how the due date is displayed and
  /// which calendar days show this task.
  @HiveField(13)
  DateTime? dueDateEnd;

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

  /// [RecurrenceRule.index] — stored as a plain int for the same reason as
  /// [priorityIndex]. Only meaningful alongside [dueDate]: completing a
  /// recurring task with no due date has no anchor to compute the next
  /// occurrence from, so the UI only offers a recurrence once a due date is
  /// set (see TasksNotifier.toggleTask/toggleSubtask, which spawn the next
  /// occurrence).
  @HiveField(14, defaultValue: 0)
  int recurrenceIndex;

  TaskPriority get priority => TaskPriority.fromIndex(priorityIndex);
  set priority(TaskPriority value) => priorityIndex = value.index;

  RecurrenceRule get recurrence => RecurrenceRule.fromIndex(recurrenceIndex);
  set recurrence(RecurrenceRule value) => recurrenceIndex = value.index;

  bool get hasSubtasks => subtasks.isNotEmpty;

  int get completedSubtaskCount =>
      subtasks.where((subtask) => subtask.isChecked).length;

  double get subtaskProgress =>
      subtasks.isEmpty ? 0 : completedSubtaskCount / subtasks.length;

  /// Builds a new [Task] with the given fields replaced — used instead of
  /// mutating this instance's fields so that value-equality-based Riverpod
  /// selectors (see [operator ==]) can tell an edited task apart from the
  /// unedited one still referenced by whatever watched it before the edit.
  /// Pass `null` explicitly for [notes]/[projectId]/[templateId]/[dueDate]/
  /// [dueDateEnd]/[workspaceId] to clear them; omit to leave them as-is.
  Task copyWith({
    String? title,
    bool? isChecked,
    Object? notes = _unset,
    List<Subtask>? subtasks,
    Object? projectId = _unset,
    Object? templateId = _unset,
    Object? dueDate = _unset,
    Object? dueDateEnd = _unset,
    double? sortOrder,
    int? priorityIndex,
    List<Attachment>? attachments,
    Object? workspaceId = _unset,
    int? recurrenceIndex,
  }) => Task(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    isChecked: isChecked ?? this.isChecked,
    notes: identical(notes, _unset) ? this.notes : notes as String?,
    subtasks: subtasks ?? [...this.subtasks],
    projectId: identical(projectId, _unset)
        ? this.projectId
        : projectId as String?,
    templateId: identical(templateId, _unset)
        ? this.templateId
        : templateId as String?,
    dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
    dueDateEnd: identical(dueDateEnd, _unset)
        ? this.dueDateEnd
        : dueDateEnd as DateTime?,
    sortOrder: sortOrder ?? this.sortOrder,
    priorityIndex: priorityIndex ?? this.priorityIndex,
    attachments: attachments ?? [...this.attachments],
    workspaceId: identical(workspaceId, _unset)
        ? this.workspaceId
        : workspaceId as String?,
    recurrenceIndex: recurrenceIndex ?? this.recurrenceIndex,
  );

  static const _subtaskListEquality = ListEquality<Subtask>();
  static const _attachmentListEquality = ListEquality<Attachment>();

  @override
  bool operator ==(Object other) =>
      other is Task &&
      other.id == id &&
      other.title == title &&
      other.isChecked == isChecked &&
      other.notes == notes &&
      other.projectId == projectId &&
      other.createdAt == createdAt &&
      other.templateId == templateId &&
      other.dueDate == dueDate &&
      other.dueDateEnd == dueDateEnd &&
      other.sortOrder == sortOrder &&
      other.priorityIndex == priorityIndex &&
      other.workspaceId == workspaceId &&
      other.recurrenceIndex == recurrenceIndex &&
      _subtaskListEquality.equals(other.subtasks, subtasks) &&
      _attachmentListEquality.equals(other.attachments, attachments);

  @override
  int get hashCode => Object.hash(
    id,
    title,
    isChecked,
    notes,
    projectId,
    createdAt,
    templateId,
    dueDate,
    dueDateEnd,
    sortOrder,
    priorityIndex,
    workspaceId,
    recurrenceIndex,
    _subtaskListEquality.hash(subtasks),
    _attachmentListEquality.hash(attachments),
  );

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
    'dueDateEnd': dueDateEnd?.toIso8601String(),
    'sortOrder': sortOrder,
    'priorityIndex': priorityIndex,
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'workspaceId': workspaceId,
    'recurrenceIndex': recurrenceIndex,
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
    dueDateEnd: json['dueDateEnd'] == null
        ? null
        : DateTime.parse(json['dueDateEnd'] as String),
    sortOrder: (json['sortOrder'] as num?)?.toDouble(),
    priorityIndex: json['priorityIndex'] as int? ?? 0,
    attachments: (json['attachments'] as List<dynamic>? ?? [])
        .map((a) => Attachment.fromJson(a as Map<String, dynamic>))
        .toList(),
    workspaceId: json['workspaceId'] as String?,
    recurrenceIndex: json['recurrenceIndex'] as int? ?? 0,
  );
}
