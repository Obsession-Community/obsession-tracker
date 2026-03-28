import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/services/land_ownership_service.dart';

/// Service to generate and insert test land ownership data
class TestLandDataService {
  factory TestLandDataService() => _instance;
  TestLandDataService._internal();
  static final TestLandDataService _instance = TestLandDataService._internal();

  final LandOwnershipService _landService = LandOwnershipService.instance;

  /// Generate test data for the Black Hills region of South Dakota
  /// This includes Wind Cave National Park and surrounding areas
  Future<void> generateBlackHillsTestData() async {
    await _landService.initialize();

    // Clear existing data first
    await _landService.clearAllLandOwnership();

    final testLands = <LandOwnership>[];

    // Wind Cave National Park (real approximate location)
    testLands.add(_createLandOwnership(
      id: 'test_wind_cave_np',
      type: LandOwnershipType.nationalPark,
      name: 'Wind Cave National Park',
      agencyName: 'National Park Service',
      unitName: 'Wind Cave',
      bounds: const LandBounds(
        north: 43.623,
        south: 43.523,
        east: -103.377,
        west: -103.577,
      ),
      accessType: AccessType.feeRequired,
      allowedUses: [
        LandUseType.hiking,
        LandUseType.camping,
        LandUseType.photography,
        LandUseType.birdWatching,
      ],
    ));

    // Black Hills National Forest (surrounding area)
    testLands.add(_createLandOwnership(
      id: 'test_black_hills_nf_1',
      type: LandOwnershipType.nationalForest,
      name: 'Black Hills National Forest',
      agencyName: 'US Forest Service',
      unitName: 'Black Hills North',
      bounds: const LandBounds(
        north: 43.723,
        south: 43.623,
        east: -103.277,
        west: -103.477,
      ),
      accessType: AccessType.publicOpen,
      allowedUses: [
        LandUseType.hiking,
        LandUseType.camping,
        LandUseType.hunting,
        LandUseType.fishing,
        LandUseType.ohvUse,
      ],
    ));

    // Custer State Park
    testLands.add(_createLandOwnership(
      id: 'test_custer_sp',
      type: LandOwnershipType.statePark,
      name: 'Custer State Park',
      agencyName: 'South Dakota Game, Fish and Parks',
      unitName: 'Custer',
      bounds: const LandBounds(
        north: 43.823,
        south: 43.623,
        east: -103.277,
        west: -103.377,
      ),
      accessType: AccessType.feeRequired,
      allowedUses: [
        LandUseType.hiking,
        LandUseType.camping,
        LandUseType.fishing,
        LandUseType.photography,
      ],
    ));

    // BLM Land
    testLands.add(_createLandOwnership(
      id: 'test_blm_1',
      type: LandOwnershipType.bureauOfLandManagement,
      name: 'BLM South Dakota Field Office',
      agencyName: 'Bureau of Land Management',
      unitName: 'Fort Meade Recreation Area',
      bounds: const LandBounds(
        north: 44.423,
        south: 44.323,
        east: -103.477,
        west: -103.577,
      ),
      accessType: AccessType.publicOpen,
      allowedUses: [
        LandUseType.hiking,
        LandUseType.camping,
        LandUseType.rockHounding,
        LandUseType.ohvUse,
      ],
    ));

    // State Forest
    testLands.add(_createLandOwnership(
      id: 'test_state_forest_1',
      type: LandOwnershipType.stateForest,
      name: 'South Dakota State Forest',
      agencyName: 'South Dakota Department of Agriculture',
      unitName: 'Newton Hills',
      bounds: const LandBounds(
        north: 43.923,
        south: 43.823,
        east: -103.177,
        west: -103.277,
      ),
      accessType: AccessType.publicOpen,
      allowedUses: [
        LandUseType.hiking,
        LandUseType.hunting,
        LandUseType.fishing,
      ],
    ));

    // Private Land parcels
    for (int i = 0; i < 5; i++) {
      testLands.add(_createLandOwnership(
        id: 'test_private_$i',
        type: LandOwnershipType.privateLand,
        name: 'Private Ranch ${i + 1}',
        bounds: LandBounds(
          north: 43.523 + (i * 0.05),
          south: 43.473 + (i * 0.05),
          east: -103.677 + (i * 0.05),
          west: -103.727 + (i * 0.05),
        ),
        accessType: AccessType.noPublicAccess,
        allowedUses: [],
      ));
    }

    // Tribal Land
    testLands.add(_createLandOwnership(
      id: 'test_tribal_1',
      type: LandOwnershipType.tribalLand,
      name: 'Pine Ridge Indian Reservation',
      agencyName: 'Oglala Sioux Tribe',
      unitName: 'Pine Ridge',
      bounds: const LandBounds(
        north: 43.223,
        south: 43.023,
        east: -102.777,
        west: -103.077,
      ),
      accessType: AccessType.permitRequired,
      allowedUses: [
        LandUseType.hiking,
        LandUseType.photography,
      ],
    ));

    // Wildlife Refuge
    testLands.add(_createLandOwnership(
      id: 'test_nwr_1',
      type: LandOwnershipType.nationalWildlifeRefuge,
      name: 'Lacreek National Wildlife Refuge',
      agencyName: 'US Fish and Wildlife Service',
      unitName: 'Lacreek',
      bounds: const LandBounds(
        north: 43.123,
        south: 43.023,
        east: -101.677,
        west: -101.777,
      ),
      accessType: AccessType.publicOpen,
      allowedUses: [
        LandUseType.birdWatching,
        LandUseType.photography,
        LandUseType.fishing,
      ],
    ));

    // Wilderness Area
    testLands.add(_createLandOwnership(
      id: 'test_wilderness_1',
      type: LandOwnershipType.wilderness,
      name: 'Black Elk Wilderness',
      agencyName: 'US Forest Service',
      unitName: 'Black Elk',
      bounds: const LandBounds(
        north: 44.023,
        south: 43.923,
        east: -103.777,
        west: -103.877,
      ),
      accessType: AccessType.publicOpen,
      allowedUses: [
        LandUseType.hiking,
        LandUseType.camping,
      ],
      restrictions: ['No motorized vehicles', 'No bicycles'],
    ));

    // Insert all test data
    for (final land in testLands) {
      await _landService.saveLandOwnership(land);
    }

    debugPrint('Inserted ${testLands.length} test land ownership records');
  }

  /// Generate test data for a specific area around given coordinates
  Future<void> generateTestDataAroundLocation({
    required double latitude,
    required double longitude,
    double radiusDegrees = 0.5,
    int numParcels = 20,
  }) async {
    await _landService.initialize();

    final random = Random();
    final testLands = <LandOwnership>[];

    // Common land types with their probability weights
    final landTypeWeights = [
      (LandOwnershipType.nationalForest, 15),
      (LandOwnershipType.nationalPark, 5),
      (LandOwnershipType.statePark, 10),
      (LandOwnershipType.stateForest, 10),
      (LandOwnershipType.bureauOfLandManagement, 15),
      (LandOwnershipType.privateLand, 30),
      (LandOwnershipType.tribalLand, 5),
      (LandOwnershipType.wilderness, 5),
      (LandOwnershipType.nationalWildlifeRefuge, 5),
    ];

    for (int i = 0; i < numParcels; i++) {
      // Random offset from center
      final offsetLat = (random.nextDouble() - 0.5) * radiusDegrees * 2;
      final offsetLng = (random.nextDouble() - 0.5) * radiusDegrees * 2;

      // Random size
      final size = 0.02 + random.nextDouble() * 0.08;

      // Select land type based on weights
      final type = _selectWeightedType(landTypeWeights, random);

      final bounds = LandBounds(
        north: latitude + offsetLat + size,
        south: latitude + offsetLat,
        east: longitude + offsetLng + size,
        west: longitude + offsetLng,
      );

      testLands.add(_createLandOwnership(
        id: 'test_gen_${type.name}_$i',
        type: type,
        name: '${type.displayName} Parcel ${i + 1}',
        agencyName: _getAgencyForType(type),
        unitName: 'Unit ${i + 1}',
        bounds: bounds,
        accessType: _getAccessTypeForType(type),
        allowedUses: _getAllowedUsesForType(type),
      ));
    }

    // Insert all test data
    for (final land in testLands) {
      await _landService.saveLandOwnership(land);
    }

    debugPrint(
        'Generated ${testLands.length} test parcels around $latitude, $longitude');
  }

  LandOwnershipType _selectWeightedType(
    List<(LandOwnershipType, int)> weights,
    Random random,
  ) {
    final totalWeight = weights.fold<int>(0, (sum, item) => sum + item.$2);
    var randomValue = random.nextInt(totalWeight);

    for (final (type, weight) in weights) {
      randomValue -= weight;
      if (randomValue < 0) return type;
    }

    return LandOwnershipType.unknown;
  }

  String? _getAgencyForType(LandOwnershipType type) {
    switch (type) {
      case LandOwnershipType.nationalForest:
        return 'US Forest Service';
      case LandOwnershipType.nationalPark:
        return 'National Park Service';
      case LandOwnershipType.bureauOfLandManagement:
        return 'Bureau of Land Management';
      case LandOwnershipType.nationalWildlifeRefuge:
        return 'US Fish and Wildlife Service';
      case LandOwnershipType.statePark:
      case LandOwnershipType.stateForest:
        return 'State Parks and Recreation';
      case LandOwnershipType.tribalLand:
        return 'Tribal Government';
      default:
        return null;
    }
  }

  AccessType _getAccessTypeForType(LandOwnershipType type) {
    switch (type) {
      case LandOwnershipType.privateLand:
        return AccessType.noPublicAccess;
      case LandOwnershipType.nationalPark:
      case LandOwnershipType.statePark:
        return AccessType.feeRequired;
      case LandOwnershipType.tribalLand:
        return AccessType.permitRequired;
      default:
        return AccessType.publicOpen;
    }
  }

  List<LandUseType> _getAllowedUsesForType(LandOwnershipType type) {
    switch (type) {
      case LandOwnershipType.privateLand:
        return [];
      case LandOwnershipType.nationalPark:
      case LandOwnershipType.statePark:
        return [
          LandUseType.hiking,
          LandUseType.camping,
          LandUseType.photography,
          LandUseType.birdWatching,
        ];
      case LandOwnershipType.nationalForest:
      case LandOwnershipType.bureauOfLandManagement:
        return [
          LandUseType.hiking,
          LandUseType.camping,
          LandUseType.hunting,
          LandUseType.fishing,
          LandUseType.ohvUse,
        ];
      case LandOwnershipType.wilderness:
        return [
          LandUseType.hiking,
          LandUseType.camping,
        ];
      case LandOwnershipType.nationalWildlifeRefuge:
        return [
          LandUseType.birdWatching,
          LandUseType.photography,
          LandUseType.fishing,
        ];
      default:
        return [LandUseType.hiking];
    }
  }

  LandOwnership _createLandOwnership({
    required String id,
    required LandOwnershipType type,
    required String name,
    required LandBounds bounds,
    required AccessType accessType,
    required List<LandUseType> allowedUses,
    String? agencyName,
    String? unitName,
    List<String>? restrictions,
  }) {
    final now = DateTime.now();
    return LandOwnership(
      id: id,
      ownershipType: type,
      ownerName: name,
      agencyName: agencyName,
      unitName: unitName,
      accessType: accessType,
      allowedUses: allowedUses,
      restrictions: restrictions ?? [],
      fees: accessType == AccessType.feeRequired ? r'$10/day' : null,
      bounds: bounds,
      centroid: bounds.center,
      dataSource: 'TEST_DATA',
      dataSourceDate: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Verify test data was inserted correctly
  Future<Map<String, dynamic>> verifyTestData() async {
    await _landService.initialize();

    final totalCount = await _landService.getLandOwnershipCount();
    final countByType = await _landService.getLandOwnershipCountByType();

    // Test filtering for specific area
    const blackHillsBounds = LandBounds(
      north: 44.5,
      south: 43.0,
      east: -103.0,
      west: -104.0,
    );

    const filter = LandOwnershipFilter(
      enabledTypes: {
        LandOwnershipType.nationalPark,
        LandOwnershipType.nationalForest,
        LandOwnershipType.statePark,
      },
    );

    final filteredData = await _landService.getFilteredLandOwnership(
      filter,
      blackHillsBounds,
    );

    return {
      'totalCount': totalCount,
      'countByType': countByType,
      'filteredCount': filteredData.length,
      'sampleData': filteredData
          .take(3)
          .map((l) => {
                'id': l.id,
                'type': l.ownershipType.name,
                'name': l.ownerName,
                'unit': l.unitName,
              })
          .toList(),
    };
  }
}
