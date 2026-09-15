import 'package:hive/hive.dart';

part 'template_subtask.g.dart';

@HiveType(typeId: 3)
class TemplateSubtask extends HiveObject {
  TemplateSubtask({required this.id, required this.title});

  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  Map<String, dynamic> toJson() => {'id': id, 'title': title};

  factory TemplateSubtask.fromJson(Map<String, dynamic> json) =>
      TemplateSubtask(id: json['id'] as String, title: json['title'] as String);
}
