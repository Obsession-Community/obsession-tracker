// Sun & Moon Times Page
// Detailed astronomical information for trip planning

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:obsession_tracker/core/models/astronomical_data.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';
import 'package:obsession_tracker/core/providers/app_settings_provider.dart';
import 'package:obsession_tracker/core/providers/astronomical_provider.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';

/// Detailed Sun & Moon information page for trip planning
class SunMoonPage extends ConsumerWidget {
  const SunMoonPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final astroState = ref.watch(astronomicalProvider);
    final locationState = ref.watch(locationProvider);
    final generalSettings = ref.watch(generalSettingsProvider);
    final use24Hour = generalSettings.timeFormat == TimeFormat.format24;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sun & Moon'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(astronomicalProvider.notifier).refresh(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(
        context,
        astroState,
        locationState,
        isDark,
        use24Hour,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AstronomicalState astroState,
    LocationState locationState,
    bool isDark,
    bool use24Hour,
  ) {
    if (astroState.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Calculating astronomical data...'),
          ],
        ),
      );
    }

    if (astroState.data == null) {
      if (locationState.currentPosition == null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_off,
                  size: 64,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(height: 16),
                Text(
                  'Waiting for GPS Location',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sun and moon times require your current location. '
                  'Please enable location services and return to this page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (astroState.errorMessage != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Calculation Error',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  astroState.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    final data = astroState.data!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header with date and location
        _buildHeader(context, data, isDark),
        const SizedBox(height: 24),

        // Current conditions card
        _buildCurrentConditionsCard(context, data, isDark),
        const SizedBox(height: 16),

        // Sun section
        _buildSectionCard(
          context: context,
          title: 'Sun',
          icon: Icons.wb_sunny,
          iconColor: Colors.orange,
          isDark: isDark,
          children: [
            _buildTimeRow('Sunrise', data.sunrise, use24Hour, isDark),
            _buildTimeRow('Solar Noon', data.solarNoon, use24Hour, isDark),
            _buildTimeRow('Sunset', data.sunset, use24Hour, isDark),
            const Divider(height: 24),
            _buildInfoRow(
              'Day Length',
              data.dayLengthFormatted,
              isDark,
              icon: Icons.schedule,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Photography Windows section
        _buildSectionCard(
          context: context,
          title: 'Photography Windows',
          icon: Icons.camera_alt,
          iconColor: const Color(0xFFD4AF37),
          isDark: isDark,
          children: [
            _buildSubsectionHeader('Golden Hour', const Color(0xFFD4AF37), isDark),
            _buildTimeRangeRow(
              'Morning',
              data.goldenHourMorningStart,
              data.goldenHourMorningEnd,
              use24Hour,
              isDark,
            ),
            _buildTimeRangeRow(
              'Evening',
              data.goldenHourEveningStart,
              data.goldenHourEveningEnd,
              use24Hour,
              isDark,
            ),
            const SizedBox(height: 12),
            _buildSubsectionHeader('Blue Hour', Colors.blue, isDark),
            _buildTimeRangeRow(
              'Morning',
              data.blueHourMorningStart,
              data.blueHourMorningEnd,
              use24Hour,
              isDark,
            ),
            _buildTimeRangeRow(
              'Evening',
              data.blueHourEveningStart,
              data.blueHourEveningEnd,
              use24Hour,
              isDark,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Moon section
        _buildSectionCard(
          context: context,
          title: 'Moon',
          icon: Icons.nightlight_round,
          iconColor: Colors.indigo,
          isDark: isDark,
          children: [
            _buildMoonPhaseRow(data, isDark),
            const Divider(height: 24),
            _buildTimeRow('Moonrise', data.moonrise, use24Hour, isDark),
            _buildTimeRow('Moonset', data.moonset, use24Hour, isDark),
          ],
        ),
        const SizedBox(height: 16),

        // Twilight section
        _buildSectionCard(
          context: context,
          title: 'Civil Twilight',
          icon: Icons.brightness_4,
          iconColor: Colors.deepPurple,
          isDark: isDark,
          children: [
            _buildTimeRow('Dawn', data.civilTwilightStart, use24Hour, isDark),
            _buildTimeRow('Dusk', data.civilTwilightEnd, use24Hour, isDark),
          ],
        ),
        const SizedBox(height: 32),

        // Info footer
        _buildInfoFooter(context, data, isDark),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, AstronomicalData data, bool isDark) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

    return Column(
      children: [
        Text(
          dateFormat.format(data.date),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '${data.latitude.toStringAsFixed(4)}°, ${data.longitude.toStringAsFixed(4)}°',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentConditionsCard(
    BuildContext context,
    AstronomicalData data,
    bool isDark,
  ) {
    // Determine current conditions
    String condition;
    IconData icon;
    Color color;
    String description;

    if (data.isGoldenHour) {
      condition = 'Golden Hour';
      icon = Icons.wb_sunny;
      color = const Color(0xFFD4AF37);
      description = 'Perfect lighting for photography!';
    } else if (data.isBlueHour) {
      condition = 'Blue Hour';
      icon = Icons.nights_stay;
      color = Colors.blue;
      description = 'Soft, cool light for dramatic shots';
    } else if (data.isDaytime) {
      condition = 'Daylight';
      icon = Icons.wb_sunny;
      color = Colors.orange;

      final timeUntil = data.timeUntilNextSunEvent;
      if (timeUntil != null && data.nextSunEvent != null) {
        final hours = timeUntil.inHours;
        final minutes = timeUntil.inMinutes.remainder(60);
        description = hours > 0
            ? 'Sunset in ${hours}h ${minutes}m'
            : 'Sunset in ${minutes}m';
      } else {
        description = 'Sun is up';
      }
    } else {
      condition = 'Night';
      icon = Icons.nightlight_round;
      color = Colors.indigo;

      final timeUntil = data.timeUntilNextSunEvent;
      if (timeUntil != null && data.nextSunEvent != null) {
        final hours = timeUntil.inHours;
        final minutes = timeUntil.inMinutes.remainder(60);
        description = hours > 0
            ? 'Sunrise in ${hours}h ${minutes}m'
            : 'Sunrise in ${minutes}m';
      } else {
        description = 'Sun is down';
      }
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    condition,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            // Moon phase indicator
            Column(
              children: [
                Text(
                  data.moonPhase.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.moonIllumination.round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSubsectionHeader(String title, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow(String label, DateTime? time, bool use24Hour, bool isDark) {
    final timeStr = time != null
        ? (use24Hour
            ? DateFormat('HH:mm').format(time)
            : DateFormat('h:mm a').format(time))
        : '--:--';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Text(
            timeStr,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
              color: time != null
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.grey[600] : Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeRow(
    String label,
    DateTime? start,
    DateTime? end,
    bool use24Hour,
    bool isDark,
  ) {
    String rangeStr;
    if (start != null && end != null) {
      final startStr = use24Hour
          ? DateFormat('HH:mm').format(start)
          : DateFormat('h:mm a').format(start);
      final endStr = use24Hour
          ? DateFormat('HH:mm').format(end)
          : DateFormat('h:mm a').format(end);
      rangeStr = '$startStr - $endStr';
    } else {
      rangeStr = '--:-- - --:--';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          Text(
            rangeStr,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: start != null
                  ? (isDark ? Colors.grey[300] : Colors.grey[800])
                  : (isDark ? Colors.grey[600] : Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoonPhaseRow(AstronomicalData data, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            data.moonPhase.emoji,
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.moonPhase.displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.moonIllumination.round()}% illuminated',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Visual illumination indicator
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.grey[800]!,
                  Colors.grey[300]!,
                ],
                stops: [
                  1.0 - (data.moonIllumination / 100),
                  1.0 - (data.moonIllumination / 100),
                ],
              ),
              border: Border.all(
                color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoFooter(
    BuildContext context,
    AstronomicalData data,
    bool isDark,
  ) {
    final calculatedFormat = DateFormat('h:mm a').format(data.calculatedAt);

    return Column(
      children: [
        Icon(
          Icons.info_outline,
          size: 20,
          color: isDark ? Colors.grey[600] : Colors.grey[400],
        ),
        const SizedBox(height: 8),
        Text(
          'All times calculated locally using astronomical algorithms.\n'
          'Accuracy: typically within 1-2 minutes of official sources.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Last calculated: $calculatedFormat',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[700] : Colors.grey[400],
          ),
        ),
      ],
    );
  }
}
