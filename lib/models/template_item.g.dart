// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TemplateItemAdapter extends TypeAdapter<TemplateItem> {
  @override
  final int typeId = 1;

  @override
  TemplateItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TemplateItem(id: fields[0] as String, title: fields[1] as String);
  }

  @override
  void write(BinaryWriter writer, TemplateItem obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemplateItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
