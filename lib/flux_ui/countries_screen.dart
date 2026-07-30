import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'streema_browser_screen.dart';
import '../flux_engine/station_provider.dart';
import '../flux_hardware/radio_service.dart';
import '../helpers/navigation_helper.dart';
import 'models/countries_data.dart';
import 'stations_list_screen.dart';

class CountriesScreen extends StatefulWidget {
  const CountriesScreen({super.key});

  @override
  State<CountriesScreen> createState() => _CountriesScreenState();
}

class _CountriesScreenState extends State<CountriesScreen> {
  int? _expandedRegionIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Radio by Country', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.0)),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  final isTablet = constraints.maxWidth >= 600;
                  
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: countriesData.length,
                    itemBuilder: (context, index) {
                      final region = countriesData[index];
                      final isExpanded = _expandedRegionIndex == index;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _expandedRegionIndex = isExpanded ? null : index;
                                });
                              },
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                  border: Border.all(
                                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      region.regionName,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    Icon(
                                      isExpanded ? Icons.expand_less : Icons.expand_more, 
                                      color: theme.colorScheme.primary,
                                      size: 28,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded)
                              Padding(
                                padding: const EdgeInsets.only(top: 12, bottom: 8),
                                child: isTablet 
                                  ? GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: isWide ? 4 : 3,
                                        childAspectRatio: 3,
                                        mainAxisSpacing: 8,
                                        crossAxisSpacing: 8,
                                      ),
                                      itemCount: region.countries.length,
                                      itemBuilder: (context, cIndex) {
                                        final country = region.countries[cIndex];
                                        return _CountryCard(
                                          country: country,
                                          onTap: () => _loadAndNavigateToCountry(context, country.name),
                                        );
                                      },
                                    )
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: region.countries.map((country) {
                                        return _CountryCard(
                                          country: country,
                                          onTap: () {
                                            _loadAndNavigateToCountry(context, country.name);
                                          },
                                        );
                                      }).toList(),
                                    ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _loadAndNavigateToCountry(BuildContext context, String countryName) {
    final stationProvider = context.read<StationProvider>();
    final service = RadioService();
    final theme = Theme.of(context);
    stationProvider.loadStationsByCountry(countryName);
    Navigator.push(
      context,
      NavigationHelper.slideRightRoute(
        StationsListScreen(
          title: countryName,
          actions: [
            IconButton(
              icon: Icon(Icons.open_in_new, size: 20, color: theme.primaryColor),
              onPressed: () {
                final urlString = service.getStreemaCountryUrl(countryName);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StreemaBrowserScreen(
                      url: urlString,
                    ),
                  ),
                );
              },
              tooltip: 'View more on Streema',
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryCard extends StatelessWidget {
  final Country country;
  final VoidCallback onTap;

  const _CountryCard({required this.country, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.1),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Text(country.flag, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                country.name.toUpperCase(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}