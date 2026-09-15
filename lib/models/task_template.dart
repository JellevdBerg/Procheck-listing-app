import 'package:hive/hive.dart';

import 'template_subtask.dart';

part 'task_template.g.dart';

/// A reusable pattern for a single main task and its subtasks.
@HiveType(typeId: 4)
class TaskTemplate extends HiveObject {
  TaskTemplate({
    required this.id,
    required this.name,
    required this.subtasks,
    required this.createdAt,
  });

  @HiveField(0)
  String id;

  /// The main task's title.
  @HiveField(1)
  String name;

  @HiveField(2)
  List<TemplateSubtask> subtasks;

  @HiveField(3)
  DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'subtasks': subtasks.map((s) => s.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory TaskTemplate.fromJson(Map<String, dynamic> json) => TaskTemplate(
    id: json['id'] as String,
    name: json['name'] as String,
    subtasks: (json['subtasks'] as List<dynamic>? ?? [])
        .map((s) => TemplateSubtask.fromJson(s as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
