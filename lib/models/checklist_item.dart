import 'package:hive/hive.dart';

part 'checklist_item.g.dart';

@HiveType(typeId: 0)
class ChecklistItem extends HiveObject {
  ChecklistItem({
    required this.id,
    required this.title,
    this.isChecked = false,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  bool isChecked;

  ChecklistItem copyWith({String? title, bool? isChecked}) {
    return ChecklistItem(
      id: id,
      title: title ?? this.title,
      isChecked: isChecked ?? this.isChecked,
    );
  }
}
