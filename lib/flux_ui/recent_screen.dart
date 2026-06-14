import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/radio_engine.dart';

class RecentScreen extends StatefulWidget {
  const RecentScreen({super.key});

  @override
  State<RecentScreen> createState() => _RecentScreenState();
}

class _RecentScreenState extends State<RecentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RadioEngine>(context, listen: false).loadRecentStations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RadioEngine>(
      builder: (context, engine, child) {
        final recent = engine.recentStations;
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
                    'Recently Played',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: recent.isEmpty
                      ? const Center(
                          child: Text(
                            'No recent stations',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: recent.length,
                          itemBuilder: (context, index) {
                            final item = recent[index];
                            return Card(
                              color: Colors.white.withValues(alpha: 0.05),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: item.favicon.isNotEmpty
                                    ? CircleAvatar(
                                        backgroundImage: NetworkImage(item.favicon),
                                      )
                                    : const CircleAvatar(
                                        backgroundColor: Colors.red,
                                        child: Icon(
                                          Icons.history,
                                          color: Colors.black,
                                        ),
                                      ),
                                title: Text(
                                  item.name.isNotEmpty ? item.name : 'Unknown Station',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                subtitle: Text(
                                  "${item.country.isNotEmpty ? item.country : 'Unknown'} • ${item.genre}",
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    engine.playStation(item);
                                  },
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
