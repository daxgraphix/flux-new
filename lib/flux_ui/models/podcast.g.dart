// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PodcastAdapter extends TypeAdapter<Podcast> {
  @override
  final int typeId = 3;

  @override
  Podcast read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Podcast(
      id: fields[0] as String,
      title: fields[1] as String,
      publisher: fields[2] as String,
      image: fields[3] as String,
      description: fields[4] as String,
      rss: fields[5] as String,
      genres: (fields[6] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Podcast obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.publisher)
      ..writeByte(3)
      ..write(obj.image)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.rss)
      ..writeByte(6)
      ..write(obj.genres);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PodcastAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EpisodeAdapter extends TypeAdapter<Episode> {
  @override
  final int typeId = 4;

  @override
  Episode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Episode(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      audio: fields[3] as String,
      duration: fields[4] as int,
      pubDate: fields[5] as DateTime,
      image: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Episode obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.audio)
      ..writeByte(4)
      ..write(obj.duration)
      ..writeByte(5)
      ..write(obj.pubDate)
      ..writeByte(6)
      ..write(obj.image);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpisodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
