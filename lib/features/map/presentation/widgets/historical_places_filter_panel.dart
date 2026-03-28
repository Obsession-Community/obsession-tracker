import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/historical_place.dart';
import 'package:obsession_tracker/core/providers/historical_places_provider.dart';
import 'package:obsession_tracker/core/providers/subscription_provider.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/features/subscription/presentation/widgets/paywall_widget.dart';

/// Panel for filtering historical places overlay by category
class HistoricalPlacesFilterPanel extends ConsumerWidget {
  const HistoricalPlacesFilterPanel({
    super.key,
    this.onClose,
  });

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filter = ref.watch(historicalPlacesFilterProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, theme),
          if (isPremium)
            _buildFilterContent(context, theme, filter, ref)
          else
            _buildPremiumUpsell(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_city, size: 20),
          const SizedBox(width: 8),
          Text(
            'Historical Places',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterContent(
    BuildContext context,
    ThemeData theme,
    HistoricalPlaceFilter filter,
    WidgetRef ref,
  ) {
    final filterNotifier = ref.read(historicalPlacesFilterProvider.notifier);
    final registry = PlaceTypeRegistry();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick actions
          Row(
            children: [
              TextButton.icon(
                onPressed: filterNotifier.enableAllCategories,
                icon: const Icon(Icons.check_box, size: 18),
                label: const Text('All'),
                style: TextButton.styleFrom(
                  foregroundColor: filter.allCategoriesEnabled ? Colors.green : null,
                ),
              ),
              TextButton.icon(
                onPressed: filterNotifier.disableAllCategories,
                icon: const Icon(Icons.check_box_outline_blank, size: 18),
                label: const Text('None'),
                style: TextButton.styleFrom(
                  foregroundColor: filter.noCategoriesEnabled ? Colors.red : null,
                ),
              ),
            ],
          ),
          const Divider(),
          // Category toggles
          ...registry.allCategories.map((category) => _buildCategoryToggle(
                context,
                category,
                filter.enabledCategories.contains(category.id),
                () => filterNotifier.toggleCategory(category.id),
              )),
        ],
      ),
    );
  }

  Widget _buildCategoryToggle(
    BuildContext context,
    PlaceCategory category,
    bool enabled,
    VoidCallback onToggle,
  ) {
    // Get a representative color for the category
    final categoryColors = {
      'water': const Color(0xFF1E90FF),
      'terrain': const Color(0xFF696969),
      'historic': const Color(0xFF8B4513),
      'cultural': const Color(0xFFFFD700),
      'parks': const Color(0xFF228B22),
      'infra': const Color(0xFF708090),
    };
    final color = categoryColors[category.id] ?? Colors.grey;

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: enabled ? 1.0 : 0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  category.emoji,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: TextStyle(
                      color: enabled ? null : Colors.grey,
                      fontWeight: enabled ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                  Text(
                    category.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: enabled ? Colors.grey : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              onChanged: (_) => onToggle(),
              activeTrackColor: AppTheme.gold.withValues(alpha: 0.5),
              activeThumbColor: AppTheme.gold,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumUpsell(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: AppTheme.gold,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Premium Feature',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.gold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unlock historical places to discover mines, ghost towns, and hidden locations.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? AppTheme.textOnDarkMuted : AppTheme.textOnLightMuted,
                ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await showPaywall(context, title: 'Unlock Historical Places');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.darkBackground,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Start Free Trial',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
