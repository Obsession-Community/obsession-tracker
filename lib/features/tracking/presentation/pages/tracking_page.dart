import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/settings_models.dart' show CoordinateFormat;
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/treasure_hunt.dart';
import 'package:obsession_tracker/core/providers/app_settings_provider.dart' show generalSettingsProvider;
import 'package:obsession_tracker/core/providers/hunt_provider.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';
import 'package:obsession_tracker/core/providers/route_planning_provider.dart';
import 'package:obsession_tracker/core/providers/settings_provider.dart';
import 'package:obsession_tracker/core/providers/statistics_provider.dart';
import 'package:obsession_tracker/core/providers/waypoint_provider.dart';
import 'package:obsession_tracker/core/services/internationalization_service.dart';
import 'package:obsession_tracker/core/services/location_service.dart';
import 'package:obsession_tracker/core/services/route_planning_service.dart';
import 'package:obsession_tracker/core/utils/coordinate_formatter.dart';
import 'package:obsession_tracker/core/utils/orientation_calculator.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/custom_marker_creation_sheet.dart';
import 'package:obsession_tracker/features/subscription/presentation/widgets/premium_banner.dart';
import 'package:obsession_tracker/features/tracking/presentation/widgets/background_location_warning_dialog.dart';
import 'package:obsession_tracker/features/tracking/presentation/widgets/hunt_selection_modal.dart';
import 'package:obsession_tracker/features/tracking/presentation/widgets/route_selection_modal.dart';

/// Main tracking page for GPS breadcrumb recording.
///
/// Provides start/stop tracking functionality with real-time location display
/// and session management for the Obsession Tracker MVP.
class TrackingPage extends ConsumerStatefulWidget {
  const TrackingPage({super.key});

  @override
  ConsumerState<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends ConsumerState<TrackingPage> {
  final TextEditingController _sessionNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  late final StatisticsProvider _statisticsProvider;
  PlannedRoute? _selectedRoute; // Selected route for tracking
  TreasureHunt? _selectedHunt; // Selected hunt for session association

  // Compass data
  StreamSubscription<CompassEvent>? _compassSubscription;
  double _heading = 0.0;

  @override
  void initState() {
    super.initState();
    _statisticsProvider = StatisticsProvider();

    // Load available routes
    Future.microtask(
      () => ref.read(routePlanningProvider.notifier).loadAllRoutes(),
    );
  }

  void _startCompass() {
    if (_compassSubscription != null) return; // Already started

    debugPrint('📍 Starting compass for tracking page display');
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (mounted && event.heading != null) {
        setState(() {
          _heading = event.heading!;
        });
      }
    });
  }

  void _stopCompass() {
    if (_compassSubscription == null) return; // Already stopped

    debugPrint('📍 Stopping compass for tracking page');
    _compassSubscription?.cancel();
    _compassSubscription = null;
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    _descriptionController.dispose();
    _statisticsProvider.dispose();
    _stopCompass();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LocationState locationState = ref.watch(locationProvider);
    final LocationNotifier locationNotifier =
        ref.read(locationProvider.notifier);
    final generalSettings = ref.watch(generalSettingsProvider);

    // Listen to location state changes for statistics and waypoint synchronization
    ref.listen<LocationState>(locationProvider,
        (LocationState? previous, LocationState current) {
      _syncStatisticsWithLocation(previous, current);
      _syncWaypointsWithLocation(previous, current);

      // Start/stop compass based on tracking state
      if (current.isTracking && !(previous?.isTracking ?? false)) {
        // Tracking just started
        _startCompass();
      } else if (!current.isTracking && (previous?.isTracking ?? false)) {
        // Tracking just stopped
        _stopCompass();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Tracking'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Premium upgrade banner (only shows for free tier users)
          const PremiumUpgradeBanner(
            message: 'Track sessions, then upgrade to see land permissions',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildLocationStatusCard(locationState, locationNotifier),
                  const SizedBox(height: 16),
                  // Show warning banner if tracking is active without "Always" permission on iOS
                  if (Platform.isIOS &&
                      locationState.isTracking &&
                      locationState.detailedPermission != null &&
                      locationState.detailedPermission != LocationPermission.always)
                    BackgroundLocationWarningBanner(
                      currentPermission: locationState.detailedPermission!,
                      onOpenSettings: () async {
                        // Open iOS settings - permission status will be automatically
                        // refreshed when user returns via app lifecycle observer
                        await LocationService().openAppSettings();
                      },
                    ),
                  // Action buttons for Camera and Note when tracking is active
                  if (locationState.isTracking && locationState.activeSession != null)
                    _buildActionButtons(locationState.activeSession!.id),
                  if (!locationState.isTracking &&
                      locationState.activeSession == null)
                    _buildStartTrackingCard(locationNotifier),
                  if (locationState.isTracking || locationState.activeSession != null)
                    _buildActiveSessionCard(locationState, locationNotifier),
                  const SizedBox(height: 16),
                  _buildCurrentLocationCard(locationState, generalSettings.coordinateFormat),
                  const SizedBox(height: 16),
                  _buildBreadcrumbsCard(locationState, generalSettings.coordinateFormat),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStatusCard(
          LocationState state, LocationNotifier notifier) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    _getLocationStatusIcon(state.status),
                    color: _getLocationStatusColor(state.status),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Location Status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_getLocationStatusText(state.status)),
              if (state.errorMessage != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  state.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (state.status != LocationStatus.granted) ...<Widget>[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => notifier.requestLocationPermission(),
                  child: const Text('Grant Location Permission'),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _buildStartTrackingCard(LocationNotifier notifier) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Start New Adventure',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _sessionNameController,
                decoration: const InputDecoration(
                  labelText: 'Adventure Name',
                  hintText: 'e.g., Morning Hike',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Brief description of your adventure',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              // Route selection button
              Consumer(
                builder: (context, ref, child) {
                  final routeState = ref.watch(routePlanningProvider);
                  final hasRoutes = routeState.savedRoutes.isNotEmpty;

                  if (!hasRoutes) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _selectRoute,
                        icon: Icon(_selectedRoute != null ? Icons.check_circle : Icons.route),
                        label: Text(
                          _selectedRoute != null
                              ? 'Change route'
                              : 'Select route to follow (optional)',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          alignment: Alignment.centerLeft,
                          foregroundColor: _selectedRoute != null
                              ? Theme.of(context).primaryColor
                              : null,
                          side: BorderSide(
                            color: _selectedRoute != null
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                          ),
                        ),
                      ),
                      if (_selectedRoute != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Selected Route:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSelectedRoutePreview(_selectedRoute!),
                      ],
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
              // Hunt selection button
              Consumer(
                builder: (context, ref, child) {
                  final huntsAsync = ref.watch(huntProvider);
                  final hasHunts = huntsAsync.maybeWhen(
                    data: (hunts) => hunts.isNotEmpty,
                    orElse: () => false,
                  );

                  if (!hasHunts) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _selectHunt,
                        icon: Icon(_selectedHunt != null ? Icons.check_circle : Icons.search),
                        label: Text(
                          _selectedHunt != null
                              ? 'Change hunt'
                              : 'Associate with hunt (optional)',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          alignment: Alignment.centerLeft,
                          foregroundColor: _selectedHunt != null
                              ? Theme.of(context).colorScheme.secondary
                              : null,
                          side: BorderSide(
                            color: _selectedHunt != null
                                ? Theme.of(context).colorScheme.secondary
                                : Colors.grey,
                          ),
                        ),
                      ),
                      if (_selectedHunt != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Selected Hunt:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSelectedHuntPreview(_selectedHunt!),
                      ],
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _startTracking(notifier),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Tracking'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildActiveSessionCard(
      LocationState state, LocationNotifier notifier) {
    final TrackingSession session = state.activeSession!;

    // Determine status display based on session status
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (session.status == SessionStatus.completed) {
      statusText = 'Completed';
      statusColor = Theme.of(context).colorScheme.primary;
      statusIcon = Icons.check_circle;
    } else if (state.isTracking) {
      statusText = 'Recording';
      statusColor = Theme.of(context).colorScheme.primary;
      statusIcon = Icons.radio_button_checked;
    } else {
      statusText = 'Paused';
      statusColor = Colors.orange;
      statusIcon = Icons.pause_circle_filled;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  statusIcon,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (session.description != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                session.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            // Primary stats row
            Row(
              children: <Widget>[
                Expanded(
                  child:
                      _buildStatColumn('Distance', session.formattedDistance),
                ),
                Expanded(
                  child:
                      _buildStatColumn('Duration', session.formattedDuration),
                ),
                Expanded(
                  child:
                      _buildStatColumn('Points', '${session.breadcrumbCount}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Secondary stats row (elevation & speed)
            Row(
              children: <Widget>[
                Expanded(
                  child: _buildStatColumn(
                    'Elevation',
                    '+${session.formattedElevationGain} / -${session.formattedElevationLoss}',
                  ),
                ),
                Expanded(
                  child: _buildStatColumn(
                    'Max Speed',
                    session.formattedMaxSpeed ?? '-',
                  ),
                ),
                Expanded(
                  child: _buildStatColumn(
                    'Avg Speed',
                    session.formattedAverageSpeed ?? '-',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Note: WaypointCountChip removed - had contrast issue (gold text invisible on
            // gold primaryContainer background) and didn't filter by sessionId anyway.
            // Waypoint count visible on map and waypoints list instead.
            // Note: QuickWaypointToolbar removed - photo capture now consolidated to main FAB
            // Other waypoint types accessible via FAB expansion menu
            // Only show control buttons if session is not completed
            if (session.status != SessionStatus.completed)
              Row(
                children: <Widget>[
                  if (!state.isTracking && session.status == SessionStatus.paused)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => notifier.resumeTracking(),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Resume'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  if (state.isTracking) ...<Widget>[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => notifier.pauseTracking(),
                        icon: const Icon(Icons.pause),
                        label: const Text('Pause'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmStopTracking(notifier),
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
            else
              // Show message when session is completed
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Session completed and saved',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _clearCompletedSession(notifier),
                      icon: const Icon(Icons.add),
                      label: const Text('Start New Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLocationCard(LocationState state, CoordinateFormat coordinateFormat) {
    final Position? position = state.currentPosition;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.my_location),
                const SizedBox(width: 8),
                Text(
                  'Current Location',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (position != null) ...<Widget>[
              _buildLocationRow(
                  'Latitude', CoordinateFormatter.formatLatitude(position.latitude, coordinateFormat)),
              _buildLocationRow(
                  'Longitude', CoordinateFormatter.formatLongitude(position.longitude, coordinateFormat)),
              _buildLocationRow(
                  'Accuracy', InternationalizationService().formatDistance(position.accuracy)),
              if (position.altitude > 0)
                _buildLocationRow(
                    'Altitude', InternationalizationService().formatAltitude(position.altitude)),
              if (position.speed > 0)
                _buildLocationRow('Speed',
                    InternationalizationService().formatSpeed(position.speed)),
              _buildLocationRow(
                  'Heading', '${_heading.toStringAsFixed(1)}° ${OrientationCalculator.getCardinalDirection(_heading)}'),
              _buildLocationRow(
                  'Updated', _formatTimestamp(position.timestamp)),
            ] else ...<Widget>[
              const Text('No location data available'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () =>
                    ref.read(locationProvider.notifier).getCurrentPosition(),
                child: const Text('Get Current Location'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbsCard(LocationState state, CoordinateFormat coordinateFormat) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.timeline),
                  const SizedBox(width: 8),
                  Text(
                    'Breadcrumb Trail',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.currentBreadcrumbs.isNotEmpty) ...<Widget>[
                Text('${state.currentBreadcrumbs.length} breadcrumbs recorded'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    itemCount: state.currentBreadcrumbs.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Breadcrumb breadcrumb =
                          state.currentBreadcrumbs[index];
                      return ListTile(
                        dense: true,
                        leading: Text('#${index + 1}'),
                        title: Text(
                          CoordinateFormatter.formatPair(
                              breadcrumb.coordinates.latitude,
                              breadcrumb.coordinates.longitude,
                              coordinateFormat),
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12),
                        ),
                        subtitle: Text(
                          '±${breadcrumb.accuracy.toStringAsFixed(1)}m • ${_formatTimestamp(breadcrumb.timestamp)}',
                        ),
                      );
                    },
                  ),
                ),
              ] else
                const Text('No breadcrumbs recorded yet'),
            ],
          ),
        ),
      );

  Widget _buildStatColumn(String label, String value) => Column(
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      );

  Widget _buildLocationRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label),
            Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
      );

  Widget _buildSelectedRoutePreview(PlannedRoute route) {
    // Use theme-aware colors for dark mode support
    final textColor = Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    final iconColor = Theme.of(context).iconTheme.color?.withValues(alpha: 0.7) ??
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route, color: Theme.of(context).primaryColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    route.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _selectedRoute = null;
                    });
                  },
                  tooltip: 'Remove route',
                ),
              ],
            ),
            if (route.description != null) ...[
              const SizedBox(height: 8),
              Text(
                route.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 18, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  '${route.routePoints.length} pts',
                  style: TextStyle(fontSize: 14, color: textColor),
                ),
                const SizedBox(width: 20),
                Icon(Icons.straighten, size: 18, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  route.formattedDistance,
                  style: TextStyle(fontSize: 14, color: textColor),
                ),
                const SizedBox(width: 20),
                Icon(Icons.access_time, size: 18, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  route.formattedDuration,
                  style: TextStyle(fontSize: 14, color: textColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedHuntPreview(TreasureHunt hunt) {
    // Use theme-aware colors for dark mode support
    final textColor = Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.search, color: Theme.of(context).colorScheme.secondary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hunt.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getHuntStatusColor(hunt.status).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    hunt.status.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _getHuntStatusColor(hunt.status),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _selectedHunt = null;
                    });
                    ref.read(selectedHuntIdProvider.notifier).clearSelection();
                  },
                  tooltip: 'Remove hunt',
                ),
              ],
            ),
            if (hunt.description != null) ...[
              const SizedBox(height: 8),
              Text(
                hunt.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getHuntStatusColor(HuntStatus status) {
    switch (status) {
      case HuntStatus.active:
        return Colors.green;
      case HuntStatus.paused:
        return Colors.orange;
      case HuntStatus.solved:
        return Colors.amber;
      case HuntStatus.abandoned:
        return Colors.grey;
    }
  }

  Future<void> _selectRoute() async {
    final selectedRoute = await showModalBottomSheet<PlannedRoute>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RouteSelectionModal(),
    );

    if (selectedRoute != null && mounted) {
      setState(() {
        _selectedRoute = selectedRoute;
        // Auto-fill track name with route name if track name is empty
        if (_sessionNameController.text.trim().isEmpty) {
          _sessionNameController.text = selectedRoute.name;
        }
      });
    } else if (selectedRoute == null && mounted) {
      // User explicitly chose "No route"
      setState(() {
        _selectedRoute = null;
      });
    }
  }

  Future<void> _selectHunt() async {
    final selectedHunt = await showModalBottomSheet<TreasureHunt>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HuntSelectionModal(
        currentHuntId: _selectedHunt?.id,
      ),
    );

    if (selectedHunt != null && mounted) {
      setState(() {
        _selectedHunt = selectedHunt;
        // Update the selected hunt provider for persistence across the app
        ref.read(selectedHuntIdProvider.notifier).selectHunt(selectedHunt.id);
      });
    } else if (selectedHunt == null && mounted) {
      // User explicitly chose "No hunt"
      setState(() {
        _selectedHunt = null;
      });
      ref.read(selectedHuntIdProvider.notifier).clearSelection();
    }
  }

  Future<void> _startTracking(LocationNotifier notifier) async {
    final String name = _sessionNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an adventure name')),
      );
      return;
    }

    // Check for "Always Allow" permission on iOS before starting tracking
    if (Platform.isIOS && mounted) {
      final locationState = ref.read(locationProvider);
      final LocationPermission? permission = locationState.detailedPermission;

      // Show warning if not "Always" permission
      if (permission != null && permission != LocationPermission.always) {
        final bool shouldContinue = await BackgroundLocationWarningDialog.show(
          context: context,
          currentPermission: permission,
          onOpenSettings: () async {
            // Open iOS settings - permission status will be automatically
            // refreshed when user returns via app lifecycle observer
            await LocationService().openAppSettings();
          },
        );

        // If user chose not to continue, return early
        if (!shouldContinue) {
          return;
        }
      }
    }

    // Serialize route snapshot if a route is selected
    String? routeSnapshot;
    if (_selectedRoute != null) {
      try {
        routeSnapshot = jsonEncode(_selectedRoute!.toDatabaseMap());
      } catch (e) {
        debugPrint('⚠️ Failed to serialize route snapshot: $e');
      }
    }

    // Get GPS mode from user preferences
    final trackingSettings = ref.read(appSettingsProvider).tracking;

    // Start tracking with the selected route ID, hunt ID, and snapshot if chosen
    await notifier.startTracking(
      sessionName: name,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      plannedRouteId: _selectedRoute?.id,
      plannedRouteSnapshot: routeSnapshot,
      huntId: _selectedHunt?.id,
      gpsMode: trackingSettings.gpsMode,
    );

    // Start statistics tracking for the session
    final LocationState locationState = ref.read(locationProvider);
    if (locationState.activeSession != null) {
      _statisticsProvider.startTracking(locationState.activeSession!.id);
    }

    // Clear the form
    _sessionNameController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedRoute = null;
      _selectedHunt = null;
    });
  }

  void _confirmStopTracking(LocationNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Stop Tracking?'),
        content: const Text(
          'This will end your tracking session and save all recorded data. '
          'You can view the completed session in your history.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              notifier.stopTracking();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Tracking stopped and session saved'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  void _clearCompletedSession(LocationNotifier notifier) {
    ref.read(locationProvider.notifier).clearActiveSession();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ready to start a new session'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// Sync statistics provider with location provider state changes
  void _syncStatisticsWithLocation(
      LocationState? previous, LocationState current) {
    // Start statistics tracking when a session starts
    if (previous?.activeSession == null && current.activeSession != null) {
      _statisticsProvider.startTracking(current.activeSession!.id);
    }

    // Stop statistics tracking when session ends
    if (previous?.activeSession != null && current.activeSession == null) {
      _statisticsProvider.stopTracking();
    }
  }

  /// Sync waypoint provider with location provider state changes
  void _syncWaypointsWithLocation(
      LocationState? previous, LocationState current) {
    // Load waypoints when a session starts
    if (previous?.activeSession == null && current.activeSession != null) {
      ref
          .read(waypointProvider.notifier)
          .loadWaypointsForSession(current.activeSession!.id);
    }
  }

  IconData _getLocationStatusIcon(LocationStatus status) {
    switch (status) {
      case LocationStatus.granted:
        return Icons.location_on;
      case LocationStatus.denied:
      case LocationStatus.deniedForever:
        return Icons.location_off;
      case LocationStatus.serviceDisabled:
        return Icons.location_disabled;
      case LocationStatus.notSupported:
        return Icons.desktop_access_disabled;
      case LocationStatus.checking:
        return Icons.location_searching;
      case LocationStatus.unknown:
        return Icons.help_outline;
    }
  }

  Color _getLocationStatusColor(LocationStatus status) {
    switch (status) {
      case LocationStatus.granted:
        return Theme.of(context).colorScheme.primary;
      case LocationStatus.denied:
      case LocationStatus.deniedForever:
      case LocationStatus.serviceDisabled:
        return Theme.of(context).colorScheme.error;
      case LocationStatus.notSupported:
        return Colors.grey;
      case LocationStatus.checking:
        return Colors.orange;
      case LocationStatus.unknown:
        return Colors.grey;
    }
  }

  String _getLocationStatusText(LocationStatus status) {
    switch (status) {
      case LocationStatus.granted:
        return 'Location permission granted and services enabled';
      case LocationStatus.denied:
        return 'Location permission denied. Please grant permission to track your adventures.';
      case LocationStatus.deniedForever:
        return 'Location permission permanently denied. Please enable in app settings.';
      case LocationStatus.serviceDisabled:
        return 'Location services are disabled. Please enable in device settings.';
      case LocationStatus.notSupported:
        return 'GPS tracking is not available on desktop. Use mobile for live tracking.';
      case LocationStatus.checking:
        return 'Checking location permission status...';
      case LocationStatus.unknown:
        return 'Location permission status unknown';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      final String hour = timestamp.hour.toString().padLeft(2, '0');
      final String minute = timestamp.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
  }

  /// Build action button for adding markers when tracking is active
  Widget _buildActionButtons(String sessionId) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _ActionButton(
        icon: Icons.add_location_alt,
        label: 'Add Marker',
        color: const Color(0xFFD4AF37), // Gold - matches app theme
        onTap: () => _openMarkerCreation(sessionId),
      ),
    );
  }

  Future<void> _openMarkerCreation(String sessionId) async {
    // Get current GPS position
    final locationState = ref.read(locationProvider);
    final position = locationState.currentPosition;

    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waiting for GPS location...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await showCustomMarkerCreationSheet(
      context,
      latitude: position.latitude,
      longitude: position.longitude,
      sessionId: sessionId,
    );

    // Show feedback if a marker was created
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marker "${result.name}" saved!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// Styled action button for the tracking page
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
