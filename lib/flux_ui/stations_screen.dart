import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/radio_engine.dart';

class StationsScreen extends StatelessWidget {
  const StationsScreen({super.key});

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
                    'All Stations',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: engine.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: engine.stations.length,
                          itemBuilder: (context, index) {
                            final station = engine.stations[index];
                            return Card(
                              color: Colors.white.withValues(alpha: 0.05),
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
                                    : const CircleAvatar(
                                        backgroundColor: Colors.red,
                                        child: Icon(
                                          Icons.radio,
                                          color: Colors.black,
                                        ),
                                      ),
                                title: Text(
                                  station.name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  '${station.country} • ${station.genre} • ${station.bitrate}kbps',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.red,
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
