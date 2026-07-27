import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../flux_engine/radio_engine.dart';
import '../flux_hardware/radio_service.dart';
import 'widgets/flux_image.dart';

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
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final isTablet = constraints.maxWidth >= 600;
                            if (isTablet) {
                              return GridView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: constraints.maxWidth > 900 ? 3 : 2,
                                  childAspectRatio: 3.5,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: recent.length,
                                itemBuilder: (context, index) {
                                  return _buildRecentItem(recent[index], engine);
                                },
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: recent.length,
                              itemBuilder: (context, index) {
                                return _buildRecentItem(recent[index], engine);
                              },
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

  Widget _buildRecentItem(RadioStation item, RadioEngine engine) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      child: ListTile(
        leading: FluxImage(
          imageUrl: item.favicon,
          width: 40,
          height: 40,
          errorWidget: const CircleAvatar(
            backgroundColor: Colors.red,
            child: Icon(
              Icons.history,
              color: Colors.black,
            ),
          ),
        ),
        title: Text(
          item.name.isNotEmpty ? item.name : 'Unknown Station',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          "${item.country.isNotEmpty ? item.country : 'Unknown'} • ${item.genre}",
          style: const TextStyle(color: Colors.grey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
        onTap: () => engine.playStation(item),
      ),
    );
  }
}
