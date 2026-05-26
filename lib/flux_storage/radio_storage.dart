import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import '../flux_hardware/radio_service.dart';

class FavoriteStation {
  final String id;
  final String name;
  final String url;
  final String country;
  final String genre;
  final int bitrate;
  final String favicon;
  final DateTime addedDate;

  FavoriteStation({
    required this.id,
    required this.name,
    required this.url,
    required this.country,
    required this.genre,
    required this.bitrate,
    required this.favicon,
    required this.addedDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'country': country,
      'genre': genre,
      'bitrate': bitrate,
      'favicon': favicon,
      'addedDate': addedDate.toIso8601String(),
    };
  }

  factory FavoriteStation.fromMap(Map<String, dynamic> map) {
    return FavoriteStation(
      id: map['id'],
      name: map['name'],
      url: map['url'],
      country: map['country'],
      genre: map['genre'],
      bitrate: map['bitrate'],
      favicon: map['favicon'],
      addedDate: DateTime.parse(map['addedDate']),
    );
  }

  RadioStation toRadioStation() {
    return RadioStation(
      name: name,
      url: url,
      country: country,
      language: '',
      genre: genre,
      bitrate: bitrate,
      favicon: favicon,
    );
  }
}

class RadioStorage {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'flux_radio.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) {
        db.execute(
          'CREATE TABLE favorites(id TEXT PRIMARY KEY, name TEXT, url TEXT, country TEXT, genre TEXT, bitrate INTEGER, favicon TEXT, addedDate TEXT)',
        );
        db.execute(
          'CREATE TABLE recent(id TEXT PRIMARY KEY, name TEXT, url TEXT, country TEXT, genre TEXT, bitrate INTEGER, favicon TEXT, playedDate TEXT)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) {
        if (oldVersion < 2) {
          db.execute(
            'CREATE TABLE favorites(id TEXT PRIMARY KEY, name TEXT, url TEXT, country TEXT, genre TEXT, bitrate INTEGER, favicon TEXT, addedDate TEXT)',
          );
          db.execute(
            'CREATE TABLE recent(id TEXT PRIMARY KEY, name TEXT, url TEXT, country TEXT, genre TEXT, bitrate INTEGER, favicon TEXT, playedDate TEXT)',
          );
        }
      },
    );
  }

  Future<void> addFavorite(RadioStation station) async {
    final db = await database;
    final favorite = FavoriteStation(
      id: '${station.name}_${station.url}',
      name: station.name,
      url: station.url,
      country: station.country,
      genre: station.genre,
      bitrate: station.bitrate,
      favicon: station.favicon,
      addedDate: DateTime.now(),
    );
    await db.insert(
      'favorites',
      favorite.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(String id) async {
    final db = await database;
    await db.delete('favorites', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FavoriteStation>> getFavorites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'favorites',
      orderBy: 'addedDate DESC',
    );
    return List.generate(maps.length, (i) {
      return FavoriteStation.fromMap(maps[i]);
    });
  }

  Future<bool> isFavorite(String id) async {
    final db = await database;
    final result = await db.query(
      'favorites',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty;
  }

  Future<void> addRecent(RadioStation station) async {
    final db = await database;
    final recent = {
      'id': '${station.name}_${station.url}',
      'name': station.name,
      'url': station.url,
      'country': station.country,
      'genre': station.genre,
      'bitrate': station.bitrate,
      'favicon': station.favicon,
      'playedDate': DateTime.now().toIso8601String(),
    };
    await db.insert(
      'recent',
      recent,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Keep only last 20
    await db.delete(
      'recent',
      where:
          'id NOT IN (SELECT id FROM recent ORDER BY playedDate DESC LIMIT 20)',
    );
  }

  Future<List<RadioStation>> getRecent() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('recent', orderBy: 'playedDate DESC', limit: 20);
    return List.generate(maps.length, (i) {
      final map = maps[i];
      return RadioStation(
        name: map['name'] as String,
        url: map['url'] as String,
        country: map['country'] as String,
        language: map['language'] as String? ?? '',
        genre: map['genre'] as String,
        bitrate: map['bitrate'] as int,
        favicon: map['favicon'] as String,
      );
    });
  }
}
