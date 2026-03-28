import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';
import 'package:url_launcher/url_launcher.dart';

/// Data Sources & Legal page showing government data attribution and disclaimer.
///
/// Required by Apple App Store for apps that display government information.
/// Provides:
/// - Clear disclaimer that the app is not affiliated with government entities
/// - Links to original .gov data sources
class DataSourcesPage extends StatelessWidget {
  const DataSourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Sources & Legal'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: context.responsivePadding,
        child: ResponsiveContentBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Important Disclaimer Card
            Card(
              color: Colors.orange.withValues(alpha: isDark ? 0.2 : 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Text(
                          'IMPORTANT DISCLAIMER',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Obsession Tracker ™ is an independent application and is NOT affiliated with, endorsed by, or connected to any government agency, including but not limited to the U.S. Forest Service, Bureau of Land Management, National Park Service, U.S. Fish & Wildlife Service, or U.S. Geological Survey.',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This app uses publicly available government data to help users understand land permissions. Always verify information with local authorities before engaging in any activities.',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Government Data Sources Section
            const Text(
              'Government Data Sources',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.gold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Land ownership and permission data in this app is derived from the following official U.S. government sources:',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // PAD-US
            _buildDataSourceCard(
              context: context,
              title: 'Protected Areas Database (PAD-US)',
              agency: 'U.S. Geological Survey (USGS)',
              description:
                  'The official national inventory of protected areas in the United States. Includes federal, state, and local protected lands.',
              url: 'https://www.usgs.gov/programs/gap-analysis-project/science/pad-us-data-overview',
              isDark: isDark,
            ),

            // USFS
            _buildDataSourceCard(
              context: context,
              title: 'National Forest System Lands',
              agency: 'U.S. Forest Service (USFS)',
              description:
                  'Boundaries and management data for National Forests, Grasslands, and other USFS-administered lands.',
              url: 'https://www.fs.usda.gov/visit/maps',
              isDark: isDark,
            ),

            // BLM
            _buildDataSourceCard(
              context: context,
              title: 'Public Land Survey System (PLSS)',
              agency: 'Bureau of Land Management (BLM)',
              description:
                  'Cadastral survey data and public land boundaries for BLM-managed lands.',
              url: 'https://www.blm.gov/services/land-records',
              isDark: isDark,
            ),

            // NPS
            _buildDataSourceCard(
              context: context,
              title: 'National Park Boundaries',
              agency: 'National Park Service (NPS)',
              description:
                  'Official boundaries and land status data for National Parks, Monuments, and Historic Sites.',
              url: 'https://www.nps.gov/subjects/gisandmapping/index.htm',
              isDark: isDark,
            ),

            // USFWS
            _buildDataSourceCard(
              context: context,
              title: 'National Wildlife Refuge System',
              agency: 'U.S. Fish & Wildlife Service (USFWS)',
              description:
                  'Boundaries and management data for National Wildlife Refuges and Wetland Management Districts.',
              url: 'https://www.fws.gov/program/national-wildlife-refuge-system/boundaries-data',
              isDark: isDark,
            ),

            // GNIS
            _buildDataSourceCard(
              context: context,
              title: 'Geographic Names Information System (GNIS)',
              agency: 'U.S. Geological Survey (USGS)',
              description:
                  'Historical place names including mines, ghost towns, cemeteries, churches, schools, and post offices. The official repository of domestic geographic names.',
              url: 'https://www.usgs.gov/tools/geographic-names-information-system-gnis',
              isDark: isDark,
            ),

            // HTMC
            _buildDataSourceCard(
              context: context,
              title: 'Historical Topographic Map Collection (HTMC)',
              agency: 'U.S. Geological Survey (USGS)',
              description:
                  'Scanned historical USGS topographic maps from 1884-2006. Includes survey plats and early quadrangle maps showing terrain, trails, and settlements as they existed historically.',
              url: 'https://www.usgs.gov/programs/national-geospatial-program/historical-topographic-maps-preserving-past',
              isDark: isDark,
            ),

            const SizedBox(height: 24),

            // Other Data Sources
            const Text(
              'Other Data Sources',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.gold,
              ),
            ),
            const SizedBox(height: 16),

            // OpenStreetMap
            _buildDataSourceCard(
              context: context,
              title: 'Trail Network Data',
              agency: 'OpenStreetMap Contributors',
              description:
                  'Trail locations and attributes from the collaborative OpenStreetMap project. © OpenStreetMap contributors.',
              url: 'https://www.openstreetmap.org/copyright',
              isDark: isDark,
            ),

            // Mapbox
            _buildDataSourceCard(
              context: context,
              title: 'Map Tiles & Basemaps',
              agency: 'Mapbox',
              description:
                  'Satellite imagery and map tiles provided by Mapbox. © Mapbox © OpenStreetMap.',
              url: 'https://www.mapbox.com/about/maps/',
              isDark: isDark,
            ),

            const SizedBox(height: 24),

            // Data Accuracy Notice
            Card(
              color: isDark ? AppTheme.darkSurface : Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.amber[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Data Accuracy Notice',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[700],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'While we strive to keep data current and accurate, land ownership and regulations can change. This app is for informational purposes only. Users should:',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildBulletPoint('Verify land status with local agencies before visiting', isDark),
                    _buildBulletPoint('Check for temporary closures or restrictions', isDark),
                    _buildBulletPoint('Obtain required permits before engaging in activities', isDark),
                    _buildBulletPoint('Respect private property and posted signs', isDark),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Legal Links Section (Required by Apple App Store)
            const Text(
              'Legal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.gold,
              ),
            ),
            const SizedBox(height: 16),

            _buildDataSourceCard(
              context: context,
              title: 'Privacy Policy',
              agency: 'Obsession Tracker ™',
              description:
                  'How we handle your data. Spoiler: your data stays on your device.',
              url: 'https://obsessiontracker.com/privacy.html',
              isDark: isDark,
            ),

            _buildDataSourceCard(
              context: context,
              title: 'Terms of Use (EULA)',
              agency: 'Apple Standard License Agreement',
              description:
                  'Licensed Application End User License Agreement for apps distributed through the App Store.',
              url: 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
              isDark: isDark,
            ),

            const SizedBox(height: 24),

            // Contact Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Questions or Corrections?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If you notice inaccurate data or have questions about our sources, please contact us:',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _launchUrl('mailto:support@obsessiontracker.com'),
                      child: const Row(
                        children: [
                          Icon(Icons.email, color: AppTheme.gold, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'support@obsessiontracker.com',
                            style: TextStyle(
                              color: AppTheme.gold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildDataSourceCard({
    required BuildContext context,
    required String title,
    required String agency,
    required String description,
    required String url,
    required bool isDark,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _launchUrl(url),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                agency,
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.open_in_new, size: 14, color: AppTheme.gold),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      url,
                      style: const TextStyle(
                        color: AppTheme.gold,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
