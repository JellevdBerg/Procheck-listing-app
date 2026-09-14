import 'package:hive/hive.dart';

part 'checklist_item.g.dart';

@HiveType(typeId: 0)
class ChecklistItem extends HiveObject {
  ChecklistItem({
    required this.id,
    required this.title,
    this.isChecked = false,
    this.notes,
    List<ChecklistItem>? subtasks,
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
  List<ChecklistItem> subtasks;

  bool get hasSubtasks => subtasks.isNotEmpty;

  int get completedSubtaskCount =>
      subtasks.where((subtask) => subtask.isChecked).length;

  double get subtaskProgress =>
      subtasks.isEmpty ? 0 : completedSubtaskCount / subtasks.length;
}
