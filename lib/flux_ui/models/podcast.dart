import 'package:hive/hive.dart';

part 'podcast.g.dart';

@HiveType(typeId: 3)
class Podcast {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String publisher;
  @HiveField(3)
  final String image;
  @HiveField(4)
  final String description;
  @HiveField(5)
  final String rss;
  @HiveField(6)
  final List<String> genres;

  Podcast({
    required this.id,
    required this.title,
    required this.publisher,
    required this.image,
    required this.description,
    required this.rss,
    this.genres = const [],
  });

  factory Podcast.fromJson(Map<String, dynamic> json) {
    return Podcast(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      publisher: json['publisher'] ?? '',
      image: json['image'] ?? '',
      description: json['description'] ?? '',
      rss: json['rss'] ?? '',
      genres: List<String>.from(json['genres'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'publisher': publisher,
      'image': image,
      'description': description,
      'rss': rss,
      'genres': genres,
    };
  }
}

@HiveType(typeId: 4)
class Episode {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String description;
  @HiveField(3)
  final String audio;
  @HiveField(4)
  final int duration;
  @HiveField(5)
  final DateTime pubDate;
  @HiveField(6)
  final String image;
  @HiveField(7)
  final String? downloadPath;

  Episode({
    required this.id,
    required this.title,
    required this.description,
    required this.audio,
    required this.duration,
    required this.pubDate,
    required this.image,
    this.downloadPath,
  });

  bool get isDownloaded => downloadPath != null;

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      audio: json['audio'] ?? '',
      duration: json['duration'] ?? 0,
      pubDate: DateTime.fromMillisecondsSinceEpoch(json['pub_date_ms'] ?? 0),
      image: json['image'] ?? '',
      downloadPath: json['download_path'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'audio': audio,
      'duration': duration,
      'pub_date_ms': pubDate.millisecondsSinceEpoch,
      'image': image,
      'download_path': downloadPath,
    };
  }

  Episode copyWith({String? downloadPath}) {
    return Episode(
      id: id,
      title: title,
      description: description,
      audio: audio,
      duration: duration,
      pubDate: pubDate,
      image: image,
      downloadPath: downloadPath ?? this.downloadPath,
    );
  }
}
