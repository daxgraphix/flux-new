import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/radio_engine.dart';
import '../flux_storage/radio_storage.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late RadioStorage _storage;
  List<FavoriteStation> _favorites = [];

  @override
  void initState() {
    super.initState();
    _storage = RadioStorage();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await _storage.getFavorites();
    setState(() {
      _favorites = favorites;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RadioEngine>(
      builder: (context, engine, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A2E), Color(0xFF0A0A0A)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Favorites',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: _favorites.isEmpty
                      ? const Center(
                          child: Text(
                            'No favorites yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _favorites.length,
                          itemBuilder: (context, index) {
                            final favorite = _favorites[index];
                            return Card(
                              color: Colors.white.withValues(alpha: 0.05),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: favorite.favicon.isNotEmpty
                                    ? CircleAvatar(
                                        backgroundImage: NetworkImage(
                                          favorite.favicon,
                                        ),
                                      )
                                    : const CircleAvatar(
                                        backgroundColor: Colors.red,
                                        child: Icon(
                                          Icons.favorite,
                                          color: Colors.black,
                                        ),
                                      ),
                                title: Text(
                                  favorite.name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  '${favorite.country} • ${favorite.genre}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.play_arrow,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => engine.playStation(
                                        favorite.toRadioStation(),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () async {
                                        await _storage.removeFavorite(
                                          favorite.id,
                                        );
                                        _loadFavorites();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
