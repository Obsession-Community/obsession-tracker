import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/subscription.dart';
import 'package:obsession_tracker/core/services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State for subscription management
class SubscriptionState {
  const SubscriptionState({
    this.status,
    this.offerings = const [],
    this.isLoading = false,
    this.error,
  });

  final SubscriptionStatus? status;
  final List<ProductOffering> offerings;
  final bool isLoading;
  final String? error;

  /// Check if user is premium
  bool get isPremium => status?.isPremium ?? false;

  /// Check if user is free tier
  bool get isFree => !isPremium;

  /// Get current entitlements
  Entitlement get entitlements =>
      status != null ? Entitlement.fromSubscriptionStatus(status!) : Entitlement.free();

  SubscriptionState copyWith({
    SubscriptionStatus? status,
    List<ProductOffering>? offerings,
    bool? isLoading,
    String? error,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      offerings: offerings ?? this.offerings,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  @override
  String toString() {
    return 'SubscriptionState(status: $status, offerings: ${offerings.length}, '
        'isLoading: $isLoading, error: $error)';
  }
}

/// Subscription notifier for managing subscription state
class SubscriptionNotifier extends Notifier<SubscriptionState> {
  late final SubscriptionService _subscriptionService;

  @override
  SubscriptionState build() {
    _subscriptionService = SubscriptionService.instance;

    // Listen to subscription status changes
    _subscriptionService.statusStream.listen(_onSubscriptionStatusChanged);

    // Schedule initialization after build completes (avoid circular dependency)
    Future.microtask(_initialize);

    return const SubscriptionState();
  }

  /// Initialize subscription state
  Future<void> _initialize() async {
    try {
      state = state.copyWith(isLoading: true);

      // Get current subscription status
      final status = await _subscriptionService.getSubscriptionStatus();

      // Load offerings
      final offerings = await _subscriptionService.getOfferings();

      state = state.copyWith(
        status: status,
        offerings: offerings,
        isLoading: false,
      );

      debugPrint('✅ Subscription state initialized: ${status.tier}');
      debugPrint('   isPremium: ${status.isPremium}');
    } catch (e) {
      debugPrint('❌ Failed to initialize subscription state: $e');
      // Default to free tier when store connection fails
      final userMessage = _getUserFriendlyError(e.toString());
      state = state.copyWith(
        status: SubscriptionStatus.free(),
        isLoading: false,
        error: userMessage,
      );
      debugPrint('   Defaulting to FREE tier due to initialization error');
    }
  }

  /// Convert technical errors to user-friendly messages
  String _getUserFriendlyError(String technicalError) {
    if (technicalError.contains('not initialized')) {
      return 'Subscription service unavailable. Please restart the app or try again later.';
    }
    if (technicalError.contains('network') || technicalError.contains('connection')) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }
    if (technicalError.contains('PlatformException')) {
      return 'Store connection failed. Please try again later.';
    }
    // Return original for unknown errors
    return technicalError;
  }

  /// Refresh subscription status
  Future<void> refresh() async {
    try {
      state = state.copyWith(isLoading: true);
      await _subscriptionService.refreshSubscriptionStatus();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('❌ Failed to refresh subscription: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Purchase a subscription
  Future<bool> purchase(ProductOffering offering) async {
    try {
      state = state.copyWith(isLoading: true);

      debugPrint('💳 Purchasing: ${offering.identifier}');
      final status = await _subscriptionService.purchase(offering);

      state = state.copyWith(
        status: status,
        isLoading: false,
      );

      if (status.isPremium) {
        debugPrint('✅ Purchase successful - upgraded to Premium');
      }

      return true;
    } on PurchaseException catch (e) {
      debugPrint('❌ Purchase failed: ${e.message}');

      // Don't show error for user cancellation
      if (!e.cancelled) {
        state = state.copyWith(
          isLoading: false,
          error: e.message,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }

      return false;
    } catch (e) {
      debugPrint('❌ Purchase error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Purchase failed: $e',
      );
      return false;
    }
  }

  /// Restore previous purchases
  Future<bool> restorePurchases() async {
    try {
      state = state.copyWith(isLoading: true);

      debugPrint('🔄 Restoring purchases...');
      final status = await _subscriptionService.restorePurchases();

      state = state.copyWith(
        status: status,
        isLoading: false,
      );

      if (status.isPremium) {
        debugPrint('✅ Purchases restored - Premium active');
        return true;
      } else {
        debugPrint('ℹ️ No active purchases found');
        return false;
      }
    } on PurchaseException catch (e) {
      debugPrint('❌ Restore failed: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('❌ Restore error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Restore failed: $e',
      );
      return false;
    }
  }

  /// Handle subscription status changes
  void _onSubscriptionStatusChanged(SubscriptionStatus status) {
    state = state.copyWith(status: status);
    debugPrint('📡 Subscription status updated: ${status.tier}');
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith();
  }
}

/// Provider for subscription state
final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>(
  SubscriptionNotifier.new,
);

/// Provider for checking if user is premium
/// Checks actual subscription status from Apple/Google stores
/// Test mode can be enabled via SubscriptionService.testModePremium flag
final isPremiumProvider = Provider<bool>((ref) {
  // Check test mode bypass flag (must be explicitly enabled)
  if (SubscriptionService.testModePremium) {
    return true;
  }
  final subscriptionState = ref.watch(subscriptionProvider);
  return subscriptionState.isPremium;
});

/// Provider for current entitlements
final entitlementsProvider = Provider<Entitlement>((ref) {
  final subscriptionState = ref.watch(subscriptionProvider);
  return subscriptionState.entitlements;
});

/// Provider for tracking if the premium upgrade banner has been dismissed
/// Persists the dismissal state across app sessions
final premiumBannerDismissedProvider =
    NotifierProvider<PremiumBannerDismissedNotifier, bool>(
  PremiumBannerDismissedNotifier.new,
);

/// Notifier for managing premium banner dismissal state
class PremiumBannerDismissedNotifier extends Notifier<bool> {
  static const String _key = 'premium_banner_dismissed';

  @override
  bool build() {
    // Load dismissal state asynchronously after initialization
    _loadDismissalState();
    return false;
  }

  /// Load dismissal state from SharedPreferences
  Future<void> _loadDismissalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDismissed = prefs.getBool(_key) ?? false;
      state = isDismissed;
    } catch (e) {
      debugPrint('Error loading premium banner dismissal state: $e');
    }
  }

  /// Dismiss the banner and persist the state
  Future<void> dismiss() async {
    try {
      state = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
      debugPrint('✅ Premium banner dismissed and saved');
    } catch (e) {
      debugPrint('Error saving premium banner dismissal state: $e');
    }
  }

  /// Reset the dismissal state (e.g., after a new app version or for testing)
  Future<void> reset() async {
    try {
      state = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      debugPrint('✅ Premium banner dismissal state reset');
    } catch (e) {
      debugPrint('Error resetting premium banner dismissal state: $e');
    }
  }
}
