import 'package:hive/hive.dart';

part 'subtask.g.dart';

@HiveType(typeId: 0)
class Subtask extends HiveObject {
  Subtask({required this.id, required this.title, this.isChecked = false});

  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  bool isChecked;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isChecked': isChecked,
  };

  factory Subtask.fromJson(Map<String, dynamic> json) => Subtask(
    id: json['id'] as String,
    title: json['title'] as String,
    isChecked: json['isChecked'] as bool? ?? false,
  );
}
