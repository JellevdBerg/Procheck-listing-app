// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ActivityEntryAdapter extends TypeAdapter<ActivityEntry> {
  @override
  final int typeId = 6;

  @override
  ActivityEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ActivityEntry(
      kindIndex: fields[0] as int,
      description: fields[1] as String,
      timestamp: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ActivityEntry obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.kindIndex)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
