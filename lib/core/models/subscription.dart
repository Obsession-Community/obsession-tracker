/// Subscription and entitlement models for App Store and Google Play integration
library;

/// Subscription tier levels
enum SubscriptionTier {
  free,
  premium;

  /// Display name for UI
  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.premium:
        return 'Premium';
    }
  }

  /// Description for each tier
  String get description {
    switch (this) {
      case SubscriptionTier.free:
        return 'Basic GPS tracking and navigation';
      case SubscriptionTier.premium:
        return 'Full land rights data and premium features';
    }
  }
}

/// User's subscription status and entitlements
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.tier,
    required this.isActive,
    this.expirationDate,
    this.willRenew = false,
    this.productIdentifier,
    this.purchaseDate,
  });

  final SubscriptionTier tier;
  final bool isActive;
  final DateTime? expirationDate;
  final bool willRenew;
  final String? productIdentifier;
  final DateTime? purchaseDate;

  /// Check if subscription is currently active
  bool get isPremium => tier == SubscriptionTier.premium && isActive;

  /// Check if subscription has expired
  bool get isExpired {
    if (expirationDate == null) return false;
    return DateTime.now().isAfter(expirationDate!);
  }

  /// Days until expiration (null if no expiration or already expired)
  int? get daysUntilExpiration {
    if (expirationDate == null || isExpired) return null;
    return expirationDate!.difference(DateTime.now()).inDays;
  }

  /// Create a free tier subscription status
  factory SubscriptionStatus.free() {
    return const SubscriptionStatus(
      tier: SubscriptionTier.free,
      isActive: true,
    );
  }

  /// Create from store customer info
  factory SubscriptionStatus.fromStoreInfo({
    required bool hasActiveSubscription,
    DateTime? expirationDate,
    bool willRenew = false,
    String? productIdentifier,
    DateTime? purchaseDate,
  }) {
    return SubscriptionStatus(
      tier: hasActiveSubscription ? SubscriptionTier.premium : SubscriptionTier.free,
      isActive: hasActiveSubscription,
      expirationDate: expirationDate,
      willRenew: willRenew,
      productIdentifier: productIdentifier,
      purchaseDate: purchaseDate,
    );
  }

  /// Create from platform store receipt validation
  factory SubscriptionStatus.fromStoreReceipt({
    required bool hasActiveSubscription,
    DateTime? expirationDate,
    bool willRenew = false,
    String? productIdentifier,
    DateTime? purchaseDate,
  }) {
    return SubscriptionStatus(
      tier: hasActiveSubscription ? SubscriptionTier.premium : SubscriptionTier.free,
      isActive: hasActiveSubscription,
      expirationDate: expirationDate,
      willRenew: willRenew,
      productIdentifier: productIdentifier,
      purchaseDate: purchaseDate,
    );
  }

  SubscriptionStatus copyWith({
    SubscriptionTier? tier,
    bool? isActive,
    DateTime? expirationDate,
    bool? willRenew,
    String? productIdentifier,
    DateTime? purchaseDate,
  }) {
    return SubscriptionStatus(
      tier: tier ?? this.tier,
      isActive: isActive ?? this.isActive,
      expirationDate: expirationDate ?? this.expirationDate,
      willRenew: willRenew ?? this.willRenew,
      productIdentifier: productIdentifier ?? this.productIdentifier,
      purchaseDate: purchaseDate ?? this.purchaseDate,
    );
  }

  @override
  String toString() {
    return 'SubscriptionStatus(tier: $tier, isActive: $isActive, '
        'expirationDate: $expirationDate, willRenew: $willRenew)';
  }
}

/// Feature entitlements based on subscription tier
class Entitlement {
  const Entitlement({
    required this.activityPermissions,
    required this.propertyOwnerContactInfo,
    required this.trailData,
    required this.realtimePermissionAlerts,
    required this.offlineLandDataCaching,
    required this.advancedMapLayers,
    required this.prioritySupport,
  });

  final bool activityPermissions; // Metal detecting, treasure hunting permissions
  final bool propertyOwnerContactInfo;
  final bool trailData; // USFS, BLM, NPS trails
  final bool realtimePermissionAlerts;
  final bool offlineLandDataCaching;
  final bool advancedMapLayers;
  final bool prioritySupport;

  /// Create entitlements for free tier
  factory Entitlement.free() {
    return const Entitlement(
      activityPermissions: false,
      propertyOwnerContactInfo: false,
      trailData: false,
      realtimePermissionAlerts: false,
      offlineLandDataCaching: false,
      advancedMapLayers: false,
      prioritySupport: false,
    );
  }

  /// Create entitlements for premium tier
  factory Entitlement.premium() {
    return const Entitlement(
      activityPermissions: true,
      propertyOwnerContactInfo: true,
      trailData: true,
      realtimePermissionAlerts: true,
      offlineLandDataCaching: true,
      advancedMapLayers: true,
      prioritySupport: true,
    );
  }

  /// Create entitlements from subscription status
  factory Entitlement.fromSubscriptionStatus(SubscriptionStatus status) {
    return status.isPremium ? Entitlement.premium() : Entitlement.free();
  }
}

/// Product offering information from App Store / Google Play
class ProductOffering {
  const ProductOffering({
    required this.identifier,
    required this.productIdentifier,
    required this.priceString,
    required this.price,
    required this.currencyCode,
    required this.title,
    required this.description,
    this.subscriptionPeriod,
    this.freeTrialPeriod,
  });

  final String identifier;
  final String productIdentifier;
  final String priceString; // Formatted price (e.g., "$49.99")
  final double price; // Numeric price
  final String currencyCode;
  final String title;
  final String description;
  final String? subscriptionPeriod; // e.g., "P1Y" (1 year), "P1M" (1 month)
  final String? freeTrialPeriod; // e.g., "P7D" (7 days)

  /// Check if this is an annual subscription
  /// Checks both subscription period (P1Y) and product identifier (contains 'annual')
  bool get isAnnual =>
      (subscriptionPeriod?.contains('Y') ?? false) ||
      productIdentifier.toLowerCase().contains('annual');

  /// Check if this is a monthly subscription
  /// Checks both subscription period (P1M) and product identifier (contains 'monthly')
  bool get isMonthly =>
      (subscriptionPeriod?.contains('M') ?? false) ||
      productIdentifier.toLowerCase().contains('monthly');

  /// Get human-readable subscription period
  String get periodDescription {
    if (isAnnual) return 'year';
    if (isMonthly) return 'month';
    return 'period';
  }

  /// Get price per month for comparison
  double get pricePerMonth {
    if (isAnnual) return price / 12;
    if (isMonthly) return price;
    return price;
  }

  /// Get savings percentage compared to monthly
  int? getSavingsPercent(double monthlyPrice) {
    if (!isAnnual) return null;
    final annualMonthlyEquivalent = price / 12;
    final savings = ((monthlyPrice - annualMonthlyEquivalent) / monthlyPrice * 100).round();
    return savings > 0 ? savings : null;
  }
}
