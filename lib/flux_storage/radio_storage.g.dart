// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'radio_storage.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FavoriteStationAdapter extends TypeAdapter<FavoriteStation> {
  @override
  final int typeId = 1;

  @override
  FavoriteStation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FavoriteStation(
      id: fields[0] as String,
      name: fields[1] as String,
      url: fields[2] as String,
      country: fields[3] as String,
      genre: fields[4] as String,
      bitrate: fields[5] as int,
      favicon: fields[6] as String,
      addedDate: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FavoriteStation obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.url)
      ..writeByte(3)
      ..write(obj.country)
      ..writeByte(4)
      ..write(obj.genre)
      ..writeByte(5)
      ..write(obj.bitrate)
      ..writeByte(6)
      ..write(obj.favicon)
      ..writeByte(7)
      ..write(obj.addedDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteStationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RecentStationAdapter extends TypeAdapter<RecentStation> {
  @override
  final int typeId = 2;

  @override
  RecentStation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecentStation(
      station: fields[0] as RadioStation,
      playedDate: fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RecentStation obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.station)
      ..writeByte(1)
      ..write(obj.playedDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentStationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RadioAlarmAdapter extends TypeAdapter<RadioAlarm> {
  @override
  final int typeId = 5;

  @override
  RadioAlarm read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RadioAlarm(
      id: fields[0] as String,
      stationName: fields[1] as String,
      stationUrl: fields[2] as String,
      hour: fields[3] as int,
      minute: fields[4] as int,
      isEnabled: fields[5] as bool,
      daysOfWeek: (fields[6] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, RadioAlarm obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.stationName)
      ..writeByte(2)
      ..write(obj.stationUrl)
      ..writeByte(3)
      ..write(obj.hour)
      ..writeByte(4)
      ..write(obj.minute)
      ..writeByte(5)
      ..write(obj.isEnabled)
      ..writeByte(6)
      ..write(obj.daysOfWeek);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RadioAlarmAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
