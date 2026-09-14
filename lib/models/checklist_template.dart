import 'package:hive/hive.dart';

import 'template_item.dart';

part 'checklist_template.g.dart';

@HiveType(typeId: 2)
class ChecklistTemplate extends HiveObject {
  ChecklistTemplate({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<TemplateItem> items;

  @HiveField(3)
  DateTime createdAt;
}
