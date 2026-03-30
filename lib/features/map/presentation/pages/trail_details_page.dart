import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:obsession_tracker/core/models/trail.dart';

/// Detailed trail information page for USFS trails
class TrailDetailsPage extends StatelessWidget {
  const TrailDetailsPage({
    required this.trail,
    super.key,
  });

  final Trail trail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trail Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showTrailHelp(context),
            tooltip: 'Trail Info Help',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trail header with icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.hiking,
                    size: 32,
                    color: Color(0xFF2196F3),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trail.trailName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (trail.trailNumber != null)
                        Text(
                          'Trail #${trail.trailNumber}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick stats cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.straighten,
                    label: 'Length',
                    value: '${trail.lengthMiles.toStringAsFixed(2)} mi',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.terrain,
                    label: 'Difficulty',
                    value: trail.difficulty ?? 'Unknown',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Trail Information Section
            _buildSection(
              context,
              title: 'Trail Information',
              children: [
                _buildInfoRow(
                  context,
                  'Trail Type',
                  _formatTrailType(trail.trailType),
                  Icons.category,
                ),
                if (trail.managingAgency != null)
                  _buildInfoRow(
                    context,
                    'Managing Agency',
                    trail.managingAgency!,
                    Icons.business,
                  ),
                if (trail.surfaceType != null)
                  _buildInfoRow(
                    context,
                    'Surface Type',
                    trail.surfaceType!,
                    Icons.landscape,
                  ),
                if (trail.trailClass != null)
                  _buildInfoRow(
                    context,
                    'Trail Class',
                    trail.trailClass!,
                    Icons.format_list_numbered,
                  ),
              ],
            ),

            // Allowed Uses Section
            if (trail.allowedUses.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSection(
                context,
                title: 'Allowed Uses',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: trail.allowedUses.map((use) {
                      return Chip(
                        label: Text(
                          _formatUseType(use),
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor:
                            theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ],

            // Data Source Section
            const SizedBox(height: 24),
            _buildSection(
              context,
              title: 'Data Source',
              children: [
                _buildInfoRow(
                  context,
                  'Source',
                  trail.dataSource,
                  Icons.source,
                ),
                _buildInfoRow(
                  context,
                  'Trail ID',
                  trail.id,
                  Icons.fingerprint,
                  onTap: () => _copyToClipboard(context, trail.id),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Text(
              'Tap values to copy to clipboard',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData? icon, {
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap ?? () => _copyToClipboard(context, value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTrailType(String type) {
    switch (type.toUpperCase()) {
      case 'TERRA':
        return 'Land Trail';
      case 'SNOW':
        return 'Snow Trail';
      case 'WATER':
        return 'Water Trail';
      default:
        return type;
    }
  }

  String _formatUseType(String use) {
    // Convert from API format (e.g., "HIKER_PEDESTRIAN") to display format
    return use
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied "$text" to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showTrailHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trail Information'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Trail Data Source',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Trail data comes from the U.S. Forest Service (USFS) and provides official trail information for treasure hunting navigation.',
              ),
              SizedBox(height: 12),
              Text(
                'Trail Types',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('• Land Trail: Standard hiking/biking trails'),
              Text('• Snow Trail: Winter/snowmobile trails'),
              Text('• Water Trail: Paddling/water routes'),
              SizedBox(height: 12),
              Text(
                'Difficulty Levels',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('Trail difficulty ratings help you plan your route based on terrain and conditions.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
