import 'package:hive/hive.dart';

part 'folder.g.dart';

@HiveType(typeId: 3)
class Folder extends HiveObject {
  Folder({required this.id, required this.name, required this.createdAt});

  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  DateTime createdAt;
}
