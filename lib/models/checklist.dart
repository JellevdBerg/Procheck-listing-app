import 'package:hive/hive.dart';

import 'checklist_item.dart';

part 'checklist.g.dart';

@HiveType(typeId: 4)
class Checklist extends HiveObject {
  Checklist({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
    this.folderId,
    this.templateId,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<ChecklistItem> items;

  @HiveField(3)
  DateTime createdAt;

  /// Null when the checklist isn't filed under any folder.
  @HiveField(4)
  String? folderId;

  /// The template this checklist was instantiated from, if any.
  @HiveField(5)
  String? templateId;

  int get completedCount => items.where((item) => item.isChecked).length;

  double get progress => items.isEmpty ? 0 : completedCount / items.length;

  bool get isComplete => items.isNotEmpty && completedCount == items.length;
}
