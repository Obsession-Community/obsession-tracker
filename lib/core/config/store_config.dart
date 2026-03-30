import 'dart:io';

/// Direct App Store and Google Play Store configuration
///
/// Native App Store and Google Play integration.
/// No API keys needed - stores are accessed via bundle ID.
///
/// IMPORTANT: iOS and macOS share the same App Store and product IDs
/// via Apple's Universal Purchase. Both platforms use the iOS product IDs.
class StoreConfig {
  /// iOS/macOS Product IDs (must match App Store Connect)
  /// These use reverse domain notation for Apple platforms
  /// Used by both iOS and macOS via Universal Purchase
  // Product IDs injected at build time via --dart-define
  // Must match App Store Connect / Google Play Console configuration
  static const String iosAnnualProductId = String.fromEnvironment(
    'IOS_ANNUAL_PRODUCT_ID',
    defaultValue: 'com.obsessioncommunity.tracker.premium.annual',
  );
  static const String iosMonthlyProductId = String.fromEnvironment(
    'IOS_MONTHLY_PRODUCT_ID',
    defaultValue: 'com.obsessioncommunity.tracker.premium.monthly',
  );

  /// Android Product IDs (must match Google Play Console)
  /// Android uses simpler naming convention
  static const String androidAnnualProductId = 'premium_annual';
  static const String androidMonthlyProductId = 'premium_monthly';

  /// Check if running on an Apple platform (iOS or macOS)
  /// Both use the same App Store and product IDs via Universal Purchase
  static bool get _isApplePlatform => Platform.isIOS || Platform.isMacOS;

  /// Get platform-specific annual product ID
  static String get annualProductId =>
      _isApplePlatform ? iosAnnualProductId : androidAnnualProductId;

  /// Get platform-specific monthly product ID
  static String get monthlyProductId =>
      _isApplePlatform ? iosMonthlyProductId : androidMonthlyProductId;

  /// All product IDs for querying
  static Set<String> get allProductIds => {
        annualProductId,
        monthlyProductId,
      };

  /// Premium entitlement identifier (for internal use)
  /// This is used for feature gating, not store communication
  static const String premiumEntitlementId = 'premium';

  /// Product type identifiers
  static const String productTypeAnnual = 'annual';
  static const String productTypeMonthly = 'monthly';

  /// Get product type from ID
  static String getProductType(String productId) {
    if (productId.contains('annual') || productId.contains('Annual')) {
      return productTypeAnnual;
    }
    return productTypeMonthly;
  }
}
