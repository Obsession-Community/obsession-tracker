import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:obsession_tracker/core/models/detailed_property_info.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';

/// Detailed property information page with comprehensive data
class PropertyDetailsPage extends StatefulWidget {
  const PropertyDetailsPage({
    required this.landOwnership,
    this.detailedInfo,
    super.key,
  });

  final LandOwnership landOwnership;
  final DetailedPropertyInfo? detailedInfo;

  @override
  State<PropertyDetailsPage> createState() => _PropertyDetailsPageState();
}

class _PropertyDetailsPageState extends State<PropertyDetailsPage> {
  DetailedPropertyInfo? _detailedInfo;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _detailedInfo = widget.detailedInfo;
    // TODO(dev): Re-enable detailed info fetching when BFF supports landOwnership(id) query
    // For now, just display the data we already have from the tap
    // if (_detailedInfo == null) {
    //   _fetchDetailedInfo();
    // }
  }

  Future<void> _fetchDetailedInfo() async {
    // TODO(dev): Implement when BFF supports single property query by ID
    // For now, we just use the data passed in from the map tap
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Placeholder - query not yet supported by BFF
    setState(() {
      _isLoading = false;
      _error = 'Detailed property info not available yet';
    });
    return;

    /*
    try {
      final client = GraphQLService.instance.client;

      const query = r'''
        query GetDetailedPropertyInfo($id: ID!) {
          landOwnership(id: $id) {
            id
            detailedInfo {
              coordinates {
                latitude
                longitude
                centroidLat
                centroidLon
                boundsNorth
                boundsSouth
                boundsEast
                boundsWest
                utmZone
                utmEasting
                utmNorthing
                township
                range
                section
                quarterSection
              }
              magneticDeclination {
                declinationDegrees
                annualChange
                calculatedDate
                gridVariation
                headingCorrection
              }
              propertyHistory {
                date
                eventType
                description
                previousOwner
                newOwner
                salePrice
                acreageChange
              }
              surveyData {
                surveyDate
                surveyor
                platBook
                platPage
                deedBook
                deedPage
                legalDescriptionFull
                metesBounds
                surveyAccuracy
              }
              environmentalInfo {
                elevationFt
                elevationM
                terrainType
                soilType
                vegetationType
                waterFeatures
                geologicalFeatures
                wildlifeHabitat
                fireRisk
                floodZone
              }
              boundaryDetails {
                boundaryMarkers {
                  markerType
                  latitude
                  longitude
                  description
                  condition
                }
                fenceType
                gates {
                  gateType
                  locationLat
                  locationLon
                  isLocked
                  accessInstructions
                }
                accessRoads {
                  roadName
                  roadType
                  condition
                  seasonalAccess
                }
                parkingAreas {
                  name
                  latitude
                  longitude
                  capacity
                  facilities
                }
                trailAccess {
                  trailName
                  difficulty
                  lengthMiles
                  trailheadLat
                  trailheadLon
                }
              }
              additionalMetadata {
                key
                value
                source
                lastUpdated
              }
            }
          }
        }
      ''';

      final result = await client.query(
        QueryOptions(
          document: gql(query),
          variables: {'id': widget.landOwnership.id},
        ),
      );

      if (result.hasException) {
        setState(() {
          _error = result.exception.toString();
          _isLoading = false;
        });
        return;
      }

      final data = result.data?['landOwnership']?['detailedInfo'];
      if (data != null) {
        setState(() {
          _detailedInfo = DetailedPropertyInfo.fromJson(data as Map<String, dynamic>);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'No detailed information available';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
    */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.landOwnership.unitName ?? widget.landOwnership.ownerName),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO(dev): Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingCard(context)
          : _error != null
              ? _buildErrorCard(context)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeaderCard(context),
                    const SizedBox(height: 16),
                    if (_detailedInfo != null) ...[
                      _buildCoordinatesCard(context, _detailedInfo!.coordinates),
                      const SizedBox(height: 16),
                      _buildMagneticDeclinationCard(context, _detailedInfo!.magneticDeclination),
                      const SizedBox(height: 16),
                      if (_detailedInfo!.surveyData != null)
                        _buildSurveyDataCard(context, _detailedInfo!.surveyData!),
                      const SizedBox(height: 16),
                      if (_detailedInfo!.environmentalInfo != null)
                        _buildEnvironmentalCard(context, _detailedInfo!.environmentalInfo!),
                      const SizedBox(height: 16),
                      if (_detailedInfo!.propertyHistory.isNotEmpty)
                        _buildHistoryCard(context, _detailedInfo!.propertyHistory),
                      const SizedBox(height: 16),
                      if (_detailedInfo!.additionalMetadata.isNotEmpty)
                        _buildMetadataCard(context, _detailedInfo!.additionalMetadata),
                    ],
                  ],
                ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Color(widget.landOwnership.ownershipType.defaultColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.landOwnership.ownershipType.displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.landOwnership.designation != null)
                        Text(
                          widget.landOwnership.designation!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(context, 'Owner', widget.landOwnership.ownerName),
            if (widget.landOwnership.agencyName != null)
              _buildInfoRow(context, 'Agency', widget.landOwnership.agencyName!),
            _buildInfoRow(context, 'Access', widget.landOwnership.accessType.displayName),
            if (widget.landOwnership.fees != null)
              _buildInfoRow(context, 'Fees', widget.landOwnership.fees!),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'Error Loading Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchDetailedInfo,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoordinatesCard(BuildContext context, PropertyCoordinates coords) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Location & Coordinates',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCopyableCoordinate(
              context,
              'Center Point',
              '${coords.centroidLat.toStringAsFixed(6)}, ${coords.centroidLon.toStringAsFixed(6)}',
              'Decimal Degrees',
            ),
            const Divider(height: 24),
            _buildCoordinateRow(context, 'North Bound', coords.boundsNorth.toStringAsFixed(6)),
            _buildCoordinateRow(context, 'South Bound', coords.boundsSouth.toStringAsFixed(6)),
            _buildCoordinateRow(context, 'East Bound', coords.boundsEast.toStringAsFixed(6)),
            _buildCoordinateRow(context, 'West Bound', coords.boundsWest.toStringAsFixed(6)),
            if (coords.utmZone != null) ...[
              const Divider(height: 24),
              _buildCoordinateRow(context, 'UTM Zone', coords.utmZone!),
              if (coords.utmEasting != null)
                _buildCoordinateRow(context, 'UTM Easting', '${coords.utmEasting!.toStringAsFixed(2)}m'),
              if (coords.utmNorthing != null)
                _buildCoordinateRow(context, 'UTM Northing', '${coords.utmNorthing!.toStringAsFixed(2)}m'),
            ],
            if (coords.township != null || coords.range != null || coords.section != null) ...[
              const Divider(height: 24),
              Text(
                'PLSS (Public Land Survey System)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (coords.township != null)
                _buildCoordinateRow(context, 'Township', coords.township!),
              if (coords.range != null)
                _buildCoordinateRow(context, 'Range', coords.range!),
              if (coords.section != null)
                _buildCoordinateRow(context, 'Section', coords.section!),
              if (coords.quarterSection != null)
                _buildCoordinateRow(context, 'Quarter Section', coords.quarterSection!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMagneticDeclinationCard(BuildContext context, MagneticDeclination declination) {
    final absValue = declination.declinationDegrees.abs();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.explore, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Magnetic Declination',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '${absValue.toStringAsFixed(2)}° ${declination.directionLabel}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Compass Correction',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'What This Means:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              declination.declinationDegrees > 0
                  ? 'Magnetic North is ${absValue.toStringAsFixed(1)}° East of True North. Add ${absValue.toStringAsFixed(1)}° to magnetic compass readings to get true bearings.'
                  : 'Magnetic North is ${absValue.toStringAsFixed(1)}° West of True North. Subtract ${absValue.toStringAsFixed(1)}° from magnetic compass readings to get true bearings.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildInfoRow(context, 'Annual Change', '${declination.annualChange.toStringAsFixed(2)}°/year'),
            _buildInfoRow(context, 'Calculated', declination.calculatedDate),
            if (declination.gridVariation != null)
              _buildInfoRow(context, 'Grid Variation', '${declination.gridVariation!.toStringAsFixed(2)}°'),
          ],
        ),
      ),
    );
  }

  Widget _buildSurveyDataCard(BuildContext context, SurveyData surveyData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Legal Description & Survey',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                surveyData.legalDescriptionFull,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
            if (surveyData.surveyAccuracy != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    _getAccuracyIcon(surveyData.surveyAccuracy!),
                    size: 16,
                    color: _getAccuracyColor(surveyData.surveyAccuracy!),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Survey Accuracy: ${surveyData.surveyAccuracy}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _getAccuracyColor(surveyData.surveyAccuracy!),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            if (surveyData.platBook != null || surveyData.deedBook != null) ...[
              const Divider(height: 24),
              if (surveyData.platBook != null)
                _buildInfoRow(context, 'Plat Book', '${surveyData.platBook}${surveyData.platPage != null ? ', Page ${surveyData.platPage}' : ''}'),
              if (surveyData.deedBook != null)
                _buildInfoRow(context, 'Deed Book', '${surveyData.deedBook}${surveyData.deedPage != null ? ', Page ${surveyData.deedPage}' : ''}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentalCard(BuildContext context, EnvironmentalInfo envInfo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.terrain, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Environmental Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (envInfo.elevationFt != null)
              _buildInfoRow(context, 'Elevation', '${envInfo.elevationFt!.toStringAsFixed(0)} ft (${envInfo.elevationM?.toStringAsFixed(0) ?? 'N/A'} m)'),
            if (envInfo.terrainType != null)
              _buildInfoRow(context, 'Terrain', envInfo.terrainType!),
            if (envInfo.soilType != null)
              _buildInfoRow(context, 'Soil Type', envInfo.soilType!),
            if (envInfo.vegetationType != null)
              _buildInfoRow(context, 'Vegetation', envInfo.vegetationType!),
            if (envInfo.waterFeatures.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Water Features',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...envInfo.waterFeatures.map((feature) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.water_drop, size: 14),
                    const SizedBox(width: 8),
                    Text(feature),
                  ],
                ),
              )),
            ],
            if (envInfo.geologicalFeatures.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Geological Features',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...envInfo.geologicalFeatures.map((feature) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.landscape, size: 14),
                    const SizedBox(width: 8),
                    Text(feature),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, List<PropertyHistoryEntry> history) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Property History',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...history.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              entry.date,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(entry.eventType),
                              labelStyle: const TextStyle(fontSize: 10),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(entry.description),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard(BuildContext context, List<MetadataEntry> metadata) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Additional Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...metadata.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildInfoRow(context, entry.key, entry.value),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading detailed property information...'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinateRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyableCoordinate(BuildContext context, String label, String value, String format) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                format,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied $label to clipboard'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getAccuracyIcon(String accuracy) {
    switch (accuracy.toLowerCase()) {
      case 'high':
        return Icons.verified;
      case 'medium':
        return Icons.check_circle_outline;
      case 'low':
        return Icons.warning_amber;
      default:
        return Icons.help_outline;
    }
  }

  Color _getAccuracyColor(String accuracy) {
    switch (accuracy.toLowerCase()) {
      case 'high':
        return Colors.green.shade700;
      case 'medium':
        return Colors.orange.shade700;
      case 'low':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }
}
