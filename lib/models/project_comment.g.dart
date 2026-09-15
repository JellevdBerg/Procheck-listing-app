// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_comment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProjectCommentAdapter extends TypeAdapter<ProjectComment> {
  @override
  final int typeId = 7;

  @override
  ProjectComment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProjectComment(
      id: fields[0] as String,
      author: fields[1] as String,
      text: fields[2] as String,
      timestamp: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ProjectComment obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.author)
      ..writeByte(2)
      ..write(obj.text)
      ..writeByte(3)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectCommentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
