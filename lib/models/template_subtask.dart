import 'package:hive/hive.dart';

part 'template_subtask.g.dart';

@HiveType(typeId: 3)
class TemplateSubtask extends HiveObject {
  TemplateSubtask({required this.id, required this.title});

  @HiveField(0)
  String id;

  @HiveField(1)
  String title;
}
