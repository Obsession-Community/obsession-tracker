import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:obsession_tracker/core/config/bff_config.dart';
import 'package:obsession_tracker/core/config/store_config.dart';
import 'package:obsession_tracker/core/models/subscription.dart';
import 'package:obsession_tracker/core/services/device_registration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing subscriptions via direct App Store / Play Store integration
///
/// Handles:
/// - In-app purchase SDK initialization
/// - Purchase flows
/// - Subscription status checking
/// - Restoration of purchases
/// - Receipt validation with tracker-api
class SubscriptionService {
  SubscriptionService._();

  static final SubscriptionService _instance = SubscriptionService._();
  static SubscriptionService get instance => _instance;

  bool _isConfigured = false;
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;

  /// Cached subscription status from store purchases
  SubscriptionStatus _cachedStatus = SubscriptionStatus.free();

  /// SharedPreferences keys for persistent caching
  static const String _keyIsPremium = 'subscription_is_premium';
  static const String _keyProductId = 'subscription_product_id';
  static const String _keyExpirationDate = 'subscription_expiration_date';
  static const String _keyWillRenew = 'subscription_will_renew';

  /// Test mode flag - when enabled, always returns Premium status
  /// Used for screenshot generation and integration tests
  static bool testModePremium = false;

  /// Stream of subscription status changes
  final StreamController<SubscriptionStatus> _statusController =
      StreamController<SubscriptionStatus>.broadcast();
  Stream<SubscriptionStatus> get statusStream => _statusController.stream;

  /// Initialize in-app purchase SDK
  ///
  /// Call this once during app initialization.
  /// No API keys needed - SDK connects to stores via bundle ID.
  Future<void> initialize() async {
    if (_isConfigured) {
      debugPrint('⚠️ In-app purchase already configured, skipping initialization');
      return;
    }

    // Skip App Store connection in test mode to avoid sign-in dialogs
    if (testModePremium) {
      debugPrint('⏭️ Skipping in-app purchase initialization (test mode)');
      _isConfigured = true;
      return;
    }

    try {
      debugPrint('🔐 Initializing in-app purchase...');
      debugPrint('   Platform: ${_getPlatformName()}');
      debugPrint('   Debug Mode: $kDebugMode');

      // Check if in-app purchases are available
      final available = await _iap.isAvailable();
      if (!available) {
        debugPrint('❌ In-app purchases not available on this device');
        throw PurchaseException('In-app purchases not available');
      }

      // iOS-specific configuration (optional delegate setup removed - not needed)

      // Listen for purchase updates
      _purchaseSubscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onError: (Object error) {
          debugPrint('❌ Purchase stream error: $error');
        },
      );

      _isConfigured = true;
      debugPrint('✅ In-app purchase initialized successfully');

      // Load cached subscription from disk (for offline support)
      await _loadCachedSubscription();

      // Query past purchases to check for active subscriptions
      await _queryPastPurchases();

      // Refresh subscription status
      await refreshSubscriptionStatus();
    } catch (e, stack) {
      debugPrint('❌ In-app purchase initialization failed: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  /// Get current subscription status from cached store data
  ///
  /// This method returns cached status updated by the purchase stream.
  /// Does NOT call backend - subscription display is handled client-side.
  /// Backend is only notified after purchase/restore for download access control.
  Future<SubscriptionStatus> getSubscriptionStatus() async {
    // Check if test mode is enabled (for screenshots and integration tests)
    if (testModePremium) {
      debugPrint('📸 Test mode enabled - returning Premium status for screenshots');
      return SubscriptionStatus.fromStoreReceipt(
        hasActiveSubscription: true,
        expirationDate: DateTime.now().add(const Duration(days: 365)),
        productIdentifier: 'test_premium_annual',
        willRenew: true,
      );
    }

    if (!_isConfigured) {
      throw StateError('In-app purchase not initialized. Call initialize() first.');
    }

    // Return cached status (updated by purchase stream)
    debugPrint('🔍 Returning cached subscription status: ${_cachedStatus.isPremium ? 'Premium' : 'Free'}');
    return _cachedStatus;
  }

  /// Refresh subscription status from platform stores
  Future<void> refreshSubscriptionStatus() async {
    final status = await getSubscriptionStatus();
    _statusController.add(status);
  }

  /// Get available offerings from platform stores
  Future<List<ProductOffering>> getOfferings() async {
    if (!_isConfigured) {
      throw StateError('In-app purchase not initialized. Call initialize() first.');
    }

    try {
      debugPrint('📦 Fetching product offerings from store...');

      // Query products from store
      final response = await _iap.queryProductDetails(StoreConfig.allProductIds);

      if (response.error != null) {
        debugPrint('⚠️ Error fetching products: ${response.error}');
        return [];
      }

      if (response.productDetails.isEmpty) {
        debugPrint('⚠️ No products found');
        return [];
      }

      debugPrint('✅ Found ${response.productDetails.length} products');

      // Convert to our ProductOffering model
      final products = response.productDetails.map((product) {
        return ProductOffering(
          identifier: product.id,
          productIdentifier: product.id,
          priceString: product.price,
          price: double.tryParse(product.rawPrice.toString()) ?? 0.0,
          currencyCode: product.currencyCode,
          title: product.title,
          description: product.description,
          subscriptionPeriod: _getSubscriptionPeriod(product),
          // freeTrialPeriod defaults to null - can be extracted from product if needed
        );
      }).toList();

      debugPrint('✅ Loaded ${products.length} product offerings');
      return products;
    } catch (e) {
      debugPrint('❌ Failed to get offerings: $e');
      return [];
    }
  }

  /// Purchase a subscription
  Future<SubscriptionStatus> purchase(ProductOffering offering) async {
    if (!_isConfigured) {
      throw StateError('In-app purchase not initialized. Call initialize() first.');
    }

    try {
      debugPrint('💳 Initiating purchase: ${offering.identifier}');

      // Query product details
      final response = await _iap.queryProductDetails({offering.productIdentifier});

      if (response.error != null) {
        throw PurchaseException('Failed to query product: ${response.error}');
      }

      if (response.productDetails.isEmpty) {
        throw PurchaseException('Product not found: ${offering.productIdentifier}');
      }

      final product = response.productDetails.first;

      // Create purchase param
      final purchaseParam = PurchaseParam(productDetails: product);

      // Initiate purchase
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      if (!success) {
        throw PurchaseException('Failed to initiate purchase');
      }

      // Purchase completion happens in _onPurchaseUpdate stream
      debugPrint('💳 Purchase initiated, waiting for completion...');

      // Return current status - actual status will be updated via stream
      return await getSubscriptionStatus();
    } catch (e) {
      debugPrint('❌ Purchase failed: $e');
      if (e is PurchaseException) rethrow;
      throw PurchaseException('Purchase failed: $e');
    }
  }

  /// Restore previous purchases
  ///
  /// This method:
  /// 1. Triggers store restore (fires purchase stream for valid purchases)
  /// 2. Verifies with server to clear stale cache if subscription expired
  /// 3. Returns the authoritative subscription status
  Future<SubscriptionStatus> restorePurchases() async {
    if (!_isConfigured) {
      throw StateError('In-app purchase not initialized. Call initialize() first.');
    }

    try {
      debugPrint('🔄 Restoring purchases...');

      // Restore purchases from platform
      // This triggers purchase stream for any valid purchases
      await _iap.restorePurchases();

      // Give the purchase stream time to process restored purchases
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Always verify with server after restore
      // This ensures stale cache is cleared if subscription expired on server
      // (e.g., expired test subscription returns nothing from store)
      await _verifySubscriptionWithServer();

      // Return the authoritative status (updated by server verification)
      final status = await getSubscriptionStatus();
      _statusController.add(status);

      if (status.isPremium) {
        debugPrint('✅ Purchases restored: Premium active');
      } else {
        debugPrint('ℹ️ No active subscription found');
      }

      return status;
    } catch (e) {
      debugPrint('❌ Restore failed: $e');
      throw PurchaseException('Failed to restore purchases: $e');
    }
  }

  /// Check if user has active premium subscription
  Future<bool> isPremiumActive() async {
    final status = await getSubscriptionStatus();
    return status.isPremium;
  }

  /// Get current entitlements based on subscription
  Future<Entitlement> getEntitlements() async {
    final status = await getSubscriptionStatus();
    return Entitlement.fromSubscriptionStatus(status);
  }

  /// Dispose resources
  void dispose() {
    _purchaseSubscription.cancel();
    _statusController.close();
  }

  // ============================================================================
  // Private Helper Methods
  // ============================================================================

  /// Handle purchase updates from platform stream
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    debugPrint('📡 Purchase update received: ${purchaseDetailsList.length} purchases');

    // For restored purchases, deduplicate and only process the most recent
    final restoredPurchases = <String, PurchaseDetails>{};

    for (final purchase in purchaseDetailsList) {
      debugPrint('   Purchase: ${purchase.productID}');
      debugPrint('   Status: ${purchase.status}');

      // Check if this is one of our subscription products
      if (StoreConfig.allProductIds.contains(purchase.productID)) {
        if (purchase.status == PurchaseStatus.purchased) {
          _handlePurchaseSuccess(purchase);
        } else if (purchase.status == PurchaseStatus.error) {
          _handlePurchaseError(purchase);
        } else if (purchase.status == PurchaseStatus.restored) {
          // Deduplicate restored purchases by product ID
          // Keep only the most recent for each product
          final existing = restoredPurchases[purchase.productID];
          if (existing == null) {
            restoredPurchases[purchase.productID] = purchase;
          } else {
            // Compare transaction IDs to keep the most recent
            // (iOS transaction IDs are sequential, higher = newer)
            if (purchase.purchaseID != null && existing.purchaseID != null) {
              if (purchase.purchaseID!.compareTo(existing.purchaseID!) > 0) {
                restoredPurchases[purchase.productID] = purchase;
              }
            }
          }
        } else if (purchase.status == PurchaseStatus.canceled) {
          debugPrint('   → Purchase canceled by user');
        } else if (purchase.status == PurchaseStatus.pending) {
          debugPrint('   → Purchase pending (awaiting external action)');
        }
      }

      // Always complete the purchase
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
        debugPrint('   → Purchase completed');
      }
    }

    // Process deduplicated restored purchases
    if (restoredPurchases.isNotEmpty) {
      debugPrint('📦 Processing ${restoredPurchases.length} unique restored purchases (deduplicated from ${purchaseDetailsList.length})');
      restoredPurchases.values.forEach(_handlePurchaseRestored);
    }
  }

  /// Handle successful purchase
  Future<void> _handlePurchaseSuccess(PurchaseDetails purchase) async {
    try {
      debugPrint('✅ Purchase successful: ${purchase.productID}');

      // Extract receipt data
      final receiptData = purchase.verificationData.serverVerificationData;

      // Validate receipt with server (updates cache internally)
      final status = await _validateReceiptWithServer(
        receiptData: receiptData,
        productId: purchase.productID,
        transactionId: purchase.purchaseID,
      );

      // Notify listeners of updated status
      if (status != null) {
        _statusController.add(status);
      }
    } catch (e) {
      debugPrint('❌ Failed to validate receipt: $e');
    }
  }

  /// Handle purchase error
  void _handlePurchaseError(PurchaseDetails purchase) {
    final error = purchase.error;
    debugPrint('❌ Purchase error: ${error?.message}');
    debugPrint('   Code: ${error?.code}');
    debugPrint('   Details: ${error?.details}');
  }

  /// Handle restored purchase
  Future<void> _handlePurchaseRestored(PurchaseDetails purchase) async {
    try {
      debugPrint('🔄 Purchase restored: ${purchase.productID}');

      // Extract receipt data
      final receiptData = purchase.verificationData.serverVerificationData;

      // Validate receipt with server (updates cache internally)
      final status = await _validateReceiptWithServer(
        receiptData: receiptData,
        productId: purchase.productID,
        transactionId: purchase.purchaseID,
      );

      // Notify listeners of updated status
      if (status != null) {
        _statusController.add(status);
      }
    } catch (e) {
      debugPrint('❌ Failed to validate restored receipt: $e');
    }
  }

  /// Validate receipt with tracker-api server (for download access control)
  ///
  /// This is called ONLY after purchase/restore to notify the backend.
  /// The backend stores this in the database for NHP download validation.
  /// Returns the validated subscription status from server.
  Future<SubscriptionStatus?> _validateReceiptWithServer({
    required String receiptData,
    required String productId,
    String? transactionId,
  }) async {
    try {
      debugPrint('🔍 Validating receipt with server...');

      // Get device credentials (use same device ID that was registered)
      final deviceId = await DeviceRegistrationService.instance.getDeviceId();
      final apiKey = await DeviceRegistrationService.instance.getApiKey();

      if (apiKey == null || deviceId == null) {
        debugPrint('⚠️ No API key or device ID found - device not registered');
        return null;
      }

      // Determine platform (iOS and macOS both use App Store)
      final platform = _getPlatformForApi();

      // Call tracker-api /verify-receipt endpoint
      final url = Uri.parse('${BFFConfig.productionEndpoint}/api/v1/subscription/verify-receipt');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
          'X-Device-ID': deviceId,
        },
        body: jsonEncode({
          'platform': platform,
          'receipt_data': receiptData,
          'product_id': productId,
          'transaction_id': transactionId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final isPremium = data['is_premium'] == true;
        debugPrint('✅ Receipt validated: ${isPremium ? 'Premium' : 'Free'}');

        // Update cached status based on server validation
        if (isPremium) {
          // Use actual expiration date from server, fallback to estimate
          DateTime expirationDate;
          final expiresAt = data['expires_at'] as String?;
          if (expiresAt != null) {
            expirationDate = DateTime.parse(expiresAt);
            debugPrint('📅 Using server expiration date: $expirationDate');
          } else {
            // Fallback: estimate based on product type
            final isAnnual = productId.contains('annual');
            expirationDate = DateTime.now().add(
              isAnnual ? const Duration(days: 365) : const Duration(days: 30),
            );
            debugPrint('📅 Using estimated expiration date: $expirationDate');
          }

          final status = SubscriptionStatus.fromStoreReceipt(
            hasActiveSubscription: true,
            productIdentifier: productId,
            expirationDate: expirationDate,
            willRenew: true,
          );

          _cachedStatus = status;
          _saveCachedSubscription(status);
          debugPrint('💾 Saved subscription to cache: Premium');
          return status;
        } else {
          // Server says not premium - clear cache
          _cachedStatus = SubscriptionStatus.free();
          _clearCachedSubscription();
          debugPrint('💾 Cleared subscription cache: Free');
          return SubscriptionStatus.free();
        }
      } else {
        debugPrint('⚠️ Receipt validation failed: ${response.statusCode}');
        debugPrint('   Response: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Receipt validation error: $e');
      return null;
    }
  }

  /// Load cached subscription from SharedPreferences
  /// This provides offline access to premium features
  Future<void> _loadCachedSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool(_keyIsPremium) ?? false;

      if (!isPremium) {
        debugPrint('💾 No cached premium subscription found');
        return;
      }

      // Check if subscription has expired
      final expirationDateStr = prefs.getString(_keyExpirationDate);
      if (expirationDateStr != null) {
        final expirationDate = DateTime.parse(expirationDateStr);
        if (expirationDate.isBefore(DateTime.now())) {
          debugPrint('⏰ Cached subscription expired: $expirationDate');
          await _clearCachedSubscription();
          return;
        }
      }

      // Load cached subscription
      final productId = prefs.getString(_keyProductId);
      final willRenew = prefs.getBool(_keyWillRenew) ?? false;

      _cachedStatus = SubscriptionStatus.fromStoreReceipt(
        hasActiveSubscription: true,
        productIdentifier: productId,
        expirationDate: expirationDateStr != null ? DateTime.parse(expirationDateStr) : null,
        willRenew: willRenew,
      );

      debugPrint('💾 Loaded cached subscription: Premium (expires: $expirationDateStr)');
    } catch (e) {
      debugPrint('❌ Failed to load cached subscription: $e');
    }
  }

  /// Save subscription to SharedPreferences for offline access
  Future<void> _saveCachedSubscription(SubscriptionStatus status) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_keyIsPremium, status.isPremium);
      await prefs.setString(_keyProductId, status.productIdentifier ?? '');
      await prefs.setBool(_keyWillRenew, status.willRenew);

      if (status.expirationDate != null) {
        await prefs.setString(_keyExpirationDate, status.expirationDate!.toIso8601String());
      }

      debugPrint('💾 Saved subscription to cache: ${status.isPremium ? 'Premium' : 'Free'}');
    } catch (e) {
      debugPrint('❌ Failed to save cached subscription: $e');
    }
  }

  /// Clear cached subscription
  Future<void> _clearCachedSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsPremium);
      await prefs.remove(_keyProductId);
      await prefs.remove(_keyExpirationDate);
      await prefs.remove(_keyWillRenew);
      _cachedStatus = SubscriptionStatus.free();
      debugPrint('💾 Cleared cached subscription');
    } catch (e) {
      debugPrint('❌ Failed to clear cached subscription: $e');
    }
  }

  /// Verify subscription status with server (without requiring a receipt)
  ///
  /// This checks the server's database to see if the device has an active subscription.
  /// Used after restore to clear stale cache if subscription has expired on server.
  Future<bool> _verifySubscriptionWithServer() async {
    try {
      debugPrint('🔍 Verifying subscription status with server...');

      // Get device credentials
      final apiKey = await DeviceRegistrationService.instance.getApiKey();

      if (apiKey == null) {
        debugPrint('⚠️ No API key found - device not registered');
        return false;
      }

      // Call tracker-api /validate endpoint
      final url = Uri.parse('${BFFConfig.productionEndpoint}/api/v1/subscription/validate');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
        },
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final isPremium = data['is_premium'] == true;
        final expiresAt = data['expires_at'] as String?;

        debugPrint('✅ Server subscription status: ${isPremium ? 'Premium' : 'Free'}');
        if (expiresAt != null) {
          debugPrint('   Expires: $expiresAt');
        }

        if (isPremium && expiresAt != null) {
          // Update cache with server data
          final expirationDate = DateTime.parse(expiresAt);
          final status = SubscriptionStatus.fromStoreReceipt(
            hasActiveSubscription: true,
            productIdentifier: _cachedStatus.productIdentifier,
            expirationDate: expirationDate,
            willRenew: _cachedStatus.willRenew,
          );
          _cachedStatus = status;
          await _saveCachedSubscription(status);
        } else if (!isPremium) {
          // Server says not premium - clear local cache
          await _clearCachedSubscription();
        }

        return isPremium;
      } else {
        debugPrint('⚠️ Server verification failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Server verification error: $e');
      return false;
    }
  }

  /// Query past purchases from store to detect active subscriptions
  /// This is called on app startup to restore subscription status
  Future<void> _queryPastPurchases() async {
    try {
      debugPrint('🔍 Querying past purchases from store...');

      // Trigger restore purchases (this will fire the purchase stream)
      await _iap.restorePurchases();

      debugPrint('✅ Past purchases query completed');
    } catch (e) {
      debugPrint('❌ Failed to query past purchases: $e');
    }
  }

  /// Extract subscription period from product details
  String? _getSubscriptionPeriod(ProductDetails product) {
    // iOS and macOS both use StoreKit (AppStoreProductDetails)
    if ((Platform.isIOS || Platform.isMacOS) && product is AppStoreProductDetails) {
      return product.skProduct.subscriptionPeriod?.toString();
    } else if (Platform.isAndroid && product is GooglePlayProductDetails) {
      return product.productDetails.subscriptionOfferDetails?.first.pricingPhases.first.billingPeriod;
    }
    return null;
  }

  /// Get platform name for logging
  String _getPlatformName() {
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  /// Get platform identifier for API calls
  /// iOS and macOS both use 'ios' since they share App Store
  String _getPlatformForApi() {
    if (Platform.isIOS || Platform.isMacOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }
}

/// Exception thrown during purchase operations
class PurchaseException implements Exception {
  PurchaseException(this.message, {this.cancelled = false});

  final String message;
  final bool cancelled;

  @override
  String toString() => 'PurchaseException: $message';
}
