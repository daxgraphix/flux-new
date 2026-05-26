import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/radio_engine.dart';

class StationsListScreen extends StatefulWidget {
  final String title;
  final String? flag;

  const StationsListScreen({
    super.key,
    required this.title,
    this.flag,
  });

  @override
  State<StationsListScreen> createState() => _StationsListScreenState();
}

class _StationsListScreenState extends State<StationsListScreen> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A1A2E), const Color(0xFF0A0A0A)]
                : [const Color(0xFFE8EAF6), const Color(0xFFD1C4E9)],
          ),
        ),
        child: SafeArea(
          child: Consumer<RadioEngine>(
            builder: (context, engine, child) {
              return Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.red),
                          onPressed: () => Navigator.pop(context),
                        ),
                        if (widget.flag != null) ...[
                          Text(
                            widget.flag!,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Stations count
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${engine.stations.length} stations found',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Stations list
                  Expanded(
                    child: engine.isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: Colors.red),
                          )
                        : engine.stations.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.radio,
                                      size: 48,
                                      color: isDark
                                          ? Colors.grey[600]
                                          : Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No stations found',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: engine.stations.length,
                                itemBuilder: (context, index) {
                                  final station = engine.stations[index];
                                  return Card(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.05),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    child: ListTile(
                                      leading: station.favicon.isNotEmpty
                                          ? ClipOval(
                                              child: Image.network(
                                                station.favicon,
                                                width: 40,
                                                height: 40,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return const CircleAvatar(
                                                    backgroundColor:
                                                        Colors.red,
                                                    child: Icon(
                                                      Icons.radio,
                                                      color: Colors.black,
                                                      size: 20,
                                                    ),
                                                  );
                                                },
                                              ),
                                            )
                                          : const CircleAvatar(
                                              backgroundColor: Colors.red,
                                              child: Icon(
                                                Icons.radio,
                                                color: Colors.black,
                                                size: 20,
                                              ),
                                            ),
                                      title: Text(
                                        station.name,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${station.country} • ${station.genre} • ${station.bitrate}kbps',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.red,
                                          size: 24,
                                        ),
                                        onPressed: () =>
                                            engine.playStation(station),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
