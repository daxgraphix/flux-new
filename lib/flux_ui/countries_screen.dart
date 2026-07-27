import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'streema_browser_screen.dart';
import '../flux_engine/radio_engine.dart';
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
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (canPop)
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: theme.primaryColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  Expanded(
                    child: Text(
                      'Radio by Country',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  final isTablet = constraints.maxWidth >= 600;
                  
                  return ListView.builder(
                    itemCount: countriesData.length,
                    itemBuilder: (context, index) {
                      final region = countriesData[index];
                      final isExpanded = _expandedRegionIndex == index;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _expandedRegionIndex = isExpanded ? null : index;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  border: Border(left: BorderSide(color: theme.primaryColor, width: 4)),
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      region.regionName,
                                      style: TextStyle(color: theme.textTheme.titleMedium?.color, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: theme.primaryColor),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
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
    final engine = context.read<RadioEngine>();
    final service = context.read<RadioService>();
    engine.loadStationsByCountry(countryName);
    Navigator.push(
      context,
      NavigationHelper.slideUpRoute(
        StationsListScreen(
          title: countryName,
          actions: [
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 20, color: Colors.red),
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.1),
          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(country.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              country.name,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}