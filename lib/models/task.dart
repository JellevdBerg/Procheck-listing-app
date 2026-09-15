import 'package:hive/hive.dart';

import 'subtask.dart';

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
  }) : subtasks = subtasks ?? [];

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
  );
}
