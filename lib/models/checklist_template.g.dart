// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChecklistTemplateAdapter extends TypeAdapter<ChecklistTemplate> {
  @override
  final int typeId = 2;

  @override
  ChecklistTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChecklistTemplate(
      id: fields[0] as String,
      name: fields[1] as String,
      items: (fields[2] as List).cast<TemplateItem>(),
      createdAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ChecklistTemplate obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.items)
      ..writeByte(3)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChecklistTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
