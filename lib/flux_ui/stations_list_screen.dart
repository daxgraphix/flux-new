import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'streema_browser_screen.dart';
import '../flux_engine/radio_engine.dart';
import '../flux_hardware/radio_service.dart';
import 'widgets/flux_image.dart';

class StationsListScreen extends StatefulWidget {
  final String title;
  final String? flag;
  final List<Widget>? actions;

  const StationsListScreen({
    super.key,
    required this.title,
    this.flag,
    this.actions,
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
                          icon: Icon(Icons.arrow_back, color: Theme.of(context).primaryColor),
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
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (widget.actions != null) ...widget.actions!,
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
                        ? Center(
                            child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
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
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final isTablet = constraints.maxWidth >= 600;
                                  if (isTablet) {
                                    return GridView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: constraints.maxWidth > 900 ? 3 : 2,
                                        childAspectRatio: 3.5,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 8,
                                      ),
                                      itemCount: engine.stations.length + 1,
                                      itemBuilder: (context, index) {
                                        if (index == engine.stations.length) {
                                          return _buildStreemaFooter(widget.title);
                                        }
                                        final station = engine.stations[index];
                                        return _buildStationItem(station, isDark, engine);
                                      },
                                    );
                                  }
                                  return ListView.builder(
                                    itemCount: engine.stations.length + 1,
                                    itemBuilder: (context, index) {
                                      if (index == engine.stations.length) {
                                        return _buildStreemaFooter(widget.title);
                                      }
                                      final station = engine.stations[index];
                                      return _buildStationItem(station, isDark, engine);
                                    },
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

  Widget _buildStationItem(RadioStation station, bool isDark, RadioEngine engine) {
    return Card(
      color: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.05),
      margin: const EdgeInsets.symmetric(
        horizontal: 0, // Handled by Grid/List padding
        vertical: 4,
      ),
      child: ListTile(
        leading: FluxImage(
          imageUrl: station.favicon,
          width: 40,
          height: 40,
          placeholder: CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            child: Icon(
              Icons.radio,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 20,
            ),
          ),
          errorWidget: CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            child: Icon(
              Icons.radio,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 20,
            ),
          ),
        ),
        title: Text(
          station.name,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${station.country} • ${station.genre}',
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.play_arrow,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
          onPressed: () => engine.playStation(station),
        ),
      ),
    );
  }

  Widget _buildStreemaFooter(String query) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Text(
            "Can't find what you're looking for?",
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              final url = RadioService().getStreemaSearchUrl(query);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StreemaBrowserScreen(url: url),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.travel_explore_rounded, size: 20, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 10),
                  Text(
                    'Search Streema Directory',
                    style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
