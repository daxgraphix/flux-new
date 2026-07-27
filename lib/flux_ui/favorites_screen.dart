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
    final theme = Theme.of(context);
    return Consumer<RadioEngine>(
      builder: (context, engine, child) {
        return Container(
          color: theme.scaffoldBackgroundColor,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Favorites',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: _favorites.isEmpty
                      ? Center(
                          child: Text(
                            'No favorites yet',
                            style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _favorites.length,
                          itemBuilder: (context, index) {
                            final favorite = _favorites[index];
                            return Card(
                              color: theme.cardColor,
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
                                    : CircleAvatar(
                                        backgroundColor: theme.primaryColor,
                                        child: Icon(
                                          Icons.favorite,
                                          color: theme.colorScheme.onPrimary,
                                        ),
                                      ),
                                title: Text(
                                  favorite.name,
                                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                                ),
                                subtitle: Text(
                                  '${favorite.country} • ${favorite.genre}',
                                  style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.play_arrow,
                                        color: theme.primaryColor,
                                      ),
                                      onPressed: () => engine.playStation(
                                        favorite.toRadioStation(),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: theme.colorScheme.error,
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
