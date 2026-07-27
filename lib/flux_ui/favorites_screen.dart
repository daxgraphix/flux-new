import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/radio_engine.dart';
import '../flux_storage/radio_storage.dart';
import 'widgets/empty_state_widget.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: Consumer<RadioEngine>(
        builder: (context, engine, child) {
          return Container(
            color: theme.scaffoldBackgroundColor,
            child: Column(
              children: [
                Expanded(
                  child: _favorites.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.favorite_outline,
                          title: 'No favorites yet',
                          message: 'Keep track of the stations you love by adding them to favorites.',
                          buttonLabel: 'Explore Stations',
                          onButtonPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
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
                                  style: theme.textTheme.titleMedium,
                                ),
                                subtitle: Text(
                                  '${favorite.country} • ${favorite.genre}',
                                  style: theme.textTheme.bodySmall,
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
          );
        },
      ),
    );
  }
}
