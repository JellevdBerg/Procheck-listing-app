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
}
