import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../flux_engine/radio_engine.dart';
import '../flux_hardware/radio_service.dart';
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
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (canPop)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.red),
                      onPressed: () => Navigator.pop(context),
                    ),
                  Expanded(
                    child: Text(
                      'Radio by Country',
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
                                  color: const Color(0xFF1A1A1A),
                                  border: Border(left: BorderSide(color: Colors.red, width: 4)),
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      region.regionName,
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.red),
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
      MaterialPageRoute(
        builder: (_) => StationsListScreen(
          title: countryName,
          actions: [
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 20, color: Colors.red),
              onPressed: () async {
                final urlString = service.getStreemaCountryUrl(countryName);
                final url = Uri.parse(urlString);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(country.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              country.name,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}