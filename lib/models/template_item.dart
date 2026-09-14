import 'package:hive/hive.dart';

part 'template_item.g.dart';

@HiveType(typeId: 1)
class TemplateItem extends HiveObject {
  TemplateItem({required this.id, required this.title});

  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  TemplateItem copyWith({String? title}) {
    return TemplateItem(id: id, title: title ?? this.title);
  }
}
