import 'package:hive/hive.dart';

part 'project.g.dart';

@HiveType(typeId: 2)
class Project extends HiveObject {
  Project({required this.id, required this.name, required this.createdAt});

  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  DateTime createdAt;
}
