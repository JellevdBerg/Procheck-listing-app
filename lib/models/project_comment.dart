import 'package:hive/hive.dart';

part 'project_comment.g.dart';

/// A comment posted on a project (see [Project.comments]).
@HiveType(typeId: 7)
class ProjectComment extends HiveObject {
  ProjectComment({
    required this.id,
    required this.author,
    required this.text,
    required this.timestamp,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String author;

  @HiveField(2)
  String text;

  @HiveField(3)
  DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'id': id,
    'author': author,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ProjectComment.fromJson(Map<String, dynamic> json) =>
      ProjectComment(
        id: json['id'] as String,
        author: json['author'] as String,
        text: json['text'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
