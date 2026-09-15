import 'package:hive/hive.dart';

part 'attachment.g.dart';

/// A file attached to a task. [path] is the on-disk location the file was
/// picked from — available on desktop, null on web (where only the picked
/// bytes are ever accessible, not a persistent path), in which case the
/// chip still shows the name/size but can't be reopened.
@HiveType(typeId: 5)
class Attachment extends HiveObject {
  Attachment({required this.name, required this.size, this.path});

  @HiveField(0)
  String name;

  /// Size in bytes.
  @HiveField(1)
  int size;

  @HiveField(2)
  String? path;

  /// A short, human-readable size, e.g. "184 KB".
  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {'name': name, 'size': size, 'path': path};

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
    name: json['name'] as String,
    size: json['size'] as int,
    path: json['path'] as String?,
  );
}
