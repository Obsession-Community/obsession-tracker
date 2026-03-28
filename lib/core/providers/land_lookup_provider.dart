import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/providers/subscription_provider.dart';
import 'package:obsession_tracker/core/services/bff_mapping_service.dart';

/// Result of a land lookup request
class LandLookupResult {
  const LandLookupResult({
    required this.success,
    this.data,
    this.error,
    this.requiresUpgrade = false,
  });

  final bool success;
  final List<LandOwnership>? data;
  final String? error;
  final bool requiresUpgrade; // True if blocked by free tier restrictions

  factory LandLookupResult.success(List<LandOwnership> data) {
    return LandLookupResult(success: true, data: data);
  }

  factory LandLookupResult.requiresPremium() {
    return const LandLookupResult(
      success: false,
      requiresUpgrade: true,
      error: 'Premium subscription required for land ownership data and activity permissions.',
    );
  }

  factory LandLookupResult.error(String error) {
    return LandLookupResult(success: false, error: error);
  }
}

/// Provider that wraps land ownership lookups with entitlement checks
///
/// This provider:
/// - Checks if user is premium
/// - Free tier users are blocked from accessing land ownership data
/// - Returns results with upgrade prompts when blocked
class LandLookupService {
  LandLookupService(this.ref);

  final Ref ref;

  /// Perform a land ownership lookup with entitlement checking
  ///
  /// This is the main method to use for all land lookups.
  /// Premium users can access full land ownership data including:
  /// - Activity permissions (metal detecting, treasure hunting)
  /// - Property owner contact information
  /// - Trail data from USFS, BLM, NPS
  ///
  /// Free tier users will receive an upgrade prompt.
  Future<LandLookupResult> getLandOwnershipData({
    required double northBound,
    required double southBound,
    required double eastBound,
    required double westBound,
    int? limit,
  }) async {
    try {
      // Check if user is premium
      final isPremium = ref.read(isPremiumProvider);

      if (!isPremium) {
        // Free tier - land ownership data requires premium
        debugPrint('🚫 Land lookup blocked - premium subscription required');
        return LandLookupResult.requiresPremium();
      }

      debugPrint('✅ Land lookup allowed (premium tier)');

      // Perform the actual lookup
      final data = await BFFMappingService.instance.getLandOwnershipData(
        northBound: northBound,
        southBound: southBound,
        eastBound: eastBound,
        westBound: westBound,
        limit: limit ?? 50, // Default to 50 if not specified
      );

      return LandLookupResult.success(data);
    } catch (e) {
      debugPrint('❌ Land lookup failed: $e');
      return LandLookupResult.error('Failed to load land data: $e');
    }
  }

  /// Check if user can perform a land lookup
  ///
  /// Returns true for premium users, false for free tier
  bool canPerformLookup() {
    return ref.read(isPremiumProvider);
  }
}

/// Provider for land lookup service
final landLookupServiceProvider = Provider<LandLookupService>((ref) {
  return LandLookupService(ref);
});
