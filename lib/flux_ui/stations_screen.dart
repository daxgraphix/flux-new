import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/radio_engine.dart';

class StationsScreen extends StatelessWidget {
  const StationsScreen({super.key});

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
                    'All Stations',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: engine.isLoading
                      ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                      : ListView.builder(
                          itemCount: engine.stations.length,
                          itemBuilder: (context, index) {
                            final station = engine.stations[index];
                            return Card(
                              color: theme.cardColor,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: station.favicon.isNotEmpty
                                    ? CircleAvatar(
                                        backgroundImage: NetworkImage(
                                          station.favicon,
                                        ),
                                      )
                                    : CircleAvatar(
                                        backgroundColor: theme.primaryColor,
                                        child: const Icon(
                                          Icons.radio,
                                          color: Colors.white,
                                        ),
                                      ),
                                title: Text(
                                  station.name,
                                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                                ),
                                subtitle: Text(
                                  '${station.country} • ${station.genre} • ${station.bitrate}kbps',
                                  style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.play_arrow,
                                    color: theme.primaryColor,
                                  ),
                                  onPressed: () => engine.playStation(station),
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
