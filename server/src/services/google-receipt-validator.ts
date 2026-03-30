import { google } from 'googleapis';

/**
 * Google Play Store Receipt Validator
 *
 * Validates purchases using Google Play Developer API
 * Requires service account with androidpublisher permissions
 */

/**
 * Validation result from Google receipt
 */
export interface GoogleReceiptValidation {
  isValid: boolean;
  isPremium: boolean;
  productId?: string;
  purchaseToken?: string;
  purchaseDate?: Date;
  expirationDate?: Date;
  willRenew?: boolean;
  error?: string;
}

/**
 * Validate Google Play receipt
 *
 * @param packageName - Android app package name (e.g., 'com.obsessiontracker.app')
 * @param productId - Subscription product ID
 * @param purchaseToken - Purchase token from Google Play
 * @param serviceAccountKeyPath - Path to service account JSON key file
 * @returns Validation result
 */
export async function validateGoogleReceipt(
  packageName: string,
  productId: string,
  purchaseToken: string,
  serviceAccountKeyPath: string
): Promise<GoogleReceiptValidation> {
  try {
    // Initialize Google Auth with service account
    const auth = new google.auth.GoogleAuth({
      keyFile: serviceAccountKeyPath,
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });

    const authClient = await auth.getClient();

    // Initialize Android Publisher API
    const androidPublisher = google.androidpublisher({
      version: 'v3',
      auth: authClient as any,
    });

    // Query subscription purchase
    const response = await androidPublisher.purchases.subscriptions.get({
      packageName,
      subscriptionId: productId,
      token: purchaseToken,
    });

    const subscription = response.data;

    if (!subscription) {
      return {
        isValid: false,
        isPremium: false,
        error: 'Subscription not found',
      };
    }

    // Check payment state
    // 0 = Payment pending, 1 = Payment received, 2 = Free trial, 3 = Pending deferred upgrade/downgrade
    const paymentState = subscription.paymentState;
    const isPaymentValid = paymentState === 1 || paymentState === 2;

    // Check expiration
    const expiryTimeMs = subscription.expiryTimeMillis
      ? parseInt(subscription.expiryTimeMillis, 10)
      : null;
    const isExpired = expiryTimeMs ? expiryTimeMs < Date.now() : false;

    // Check if subscription is active
    const isActive = isPaymentValid && !isExpired;

    // Check auto-renew status
    const willRenew = subscription.autoRenewing === true;

    return {
      isValid: true,
      isPremium: isActive,
      productId,
      purchaseToken,
      purchaseDate: subscription.startTimeMillis
        ? new Date(parseInt(subscription.startTimeMillis, 10))
        : undefined,
      expirationDate: expiryTimeMs ? new Date(expiryTimeMs) : undefined,
      willRenew,
    };
  } catch (error: any) {
    console.error('Google receipt validation error:', error);

    // Handle specific error codes
    if (error.code === 401) {
      return {
        isValid: false,
        isPremium: false,
        error: 'Authentication failed - check service account credentials',
      };
    }

    if (error.code === 404) {
      return {
        isValid: false,
        isPremium: false,
        error: 'Purchase not found',
      };
    }

    return {
      isValid: false,
      isPremium: false,
      error: error.message || 'Failed to validate receipt with Google',
    };
  }
}

/**
 * Validate Google Play receipt using environment variable for credentials
 *
 * Convenience wrapper that reads service account path from env
 */
export async function validateGoogleReceiptFromEnv(
  packageName: string,
  productId: string,
  purchaseToken: string
): Promise<GoogleReceiptValidation> {
  const serviceAccountPath = process.env.GOOGLE_SERVICE_ACCOUNT_KEY_FILE;

  if (!serviceAccountPath) {
    return {
      isValid: false,
      isPremium: false,
      error: 'GOOGLE_SERVICE_ACCOUNT_KEY_FILE environment variable not set',
    };
  }

  return validateGoogleReceipt(packageName, productId, purchaseToken, serviceAccountPath);
}
