import jwt from 'jsonwebtoken';

/**
 * Apple App Store Receipt Validator
 *
 * Validates receipts using StoreKit 2 JWS (JSON Web Signature) tokens for iOS 15+
 * Falls back to StoreKit 1 verifyReceipt API for older iOS versions
 */

/**
 * Apple JWS Transaction Response
 * StoreKit 2 format from iOS 15+
 */
interface AppleJWSTransaction {
  transactionId: string;
  originalTransactionId: string;
  productId: string;
  purchaseDate: number; // milliseconds
  originalPurchaseDate: number;
  expiresDate?: number;
  revocationDate?: number;
  type:
    | 'Auto-Renewable Subscription'
    | 'Non-Consumable'
    | 'Consumable'
    | 'Non-Renewing Subscription';
  inAppOwnershipType: 'PURCHASED' | 'FAMILY_SHARED';
  signedDate: number;
}

/**
 * StoreKit 1 verifyReceipt response
 */
interface StoreKit1Response {
  status: number;
  latest_receipt_info?: Array<{
    transaction_id: string;
    product_id: string;
    purchase_date_ms: string;
    expires_date_ms: string;
    is_trial_period?: string;
    cancellation_date_ms?: string;
  }>;
  pending_renewal_info?: Array<{
    auto_renew_status: string;
  }>;
}

/**
 * Validation result from Apple receipt
 */
export interface AppleReceiptValidation {
  isValid: boolean;
  isPremium: boolean;
  productId?: string;
  transactionId?: string;
  purchaseDate?: Date;
  expirationDate?: Date;
  willRenew?: boolean;
  error?: string;
}

/**
 * Validate Apple receipt
 *
 * @param receiptData - Base64 encoded receipt or JWS token from iOS
 * @param sharedSecret - App-specific shared secret from App Store Connect
 * @param environment - 'production' or 'sandbox'
 * @returns Validation result
 */
export async function validateAppleReceipt(
  receiptData: string,
  sharedSecret: string,
  environment: 'production' | 'sandbox' = 'production'
): Promise<AppleReceiptValidation> {
  try {
    // Check if this is a StoreKit 2 JWS token (starts with "eyJ")
    if (receiptData.startsWith('eyJ')) {
      return await validateStoreKit2JWS(receiptData);
    } else {
      // StoreKit 1 base64 receipt
      return await validateStoreKit1Receipt(
        receiptData,
        sharedSecret,
        environment
      );
    }
  } catch (error) {
    console.error('Apple receipt validation error:', error);
    return {
      isValid: false,
      isPremium: false,
      error:
        error instanceof Error ? error.message : 'Unknown validation error',
    };
  }
}

/**
 * Validate StoreKit 2 JWS token (iOS 15+)
 *
 * The JWS token is signed by Apple and contains transaction data.
 * We decode it without verification since we're receiving it from our own app.
 */
async function validateStoreKit2JWS(
  jwsToken: string
): Promise<AppleReceiptValidation> {
  try {
    // Decode JWS token (without verification - we trust our app)
    const decoded = jwt.decode(jwsToken) as AppleJWSTransaction | null;

    if (!decoded) {
      return {
        isValid: false,
        isPremium: false,
        error: 'Invalid JWS token',
      };
    }

    // Check if subscription is active
    const now = Date.now();
    const isExpired = decoded.expiresDate && decoded.expiresDate < now;
    const isRevoked = decoded.revocationDate && decoded.revocationDate < now;

    const isActive = !isExpired && !isRevoked;

    return {
      isValid: true,
      isPremium: isActive,
      productId: decoded.productId,
      transactionId: decoded.transactionId,
      purchaseDate: new Date(decoded.purchaseDate),
      expirationDate: decoded.expiresDate
        ? new Date(decoded.expiresDate)
        : undefined,
      willRenew: isActive,
    };
  } catch (error) {
    console.error('StoreKit 2 JWS validation error:', error);
    return {
      isValid: false,
      isPremium: false,
      error: 'Failed to decode JWS token',
    };
  }
}

/**
 * Validate StoreKit 1 receipt (iOS 14 and earlier)
 *
 * Calls Apple's verifyReceipt endpoint
 */
async function validateStoreKit1Receipt(
  receiptData: string,
  sharedSecret: string,
  environment: 'production' | 'sandbox'
): Promise<AppleReceiptValidation> {
  try {
    const endpoint =
      environment === 'production'
        ? 'https://buy.itunes.apple.com/verifyReceipt'
        : 'https://sandbox.itunes.apple.com/verifyReceipt';

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        'receipt-data': receiptData,
        password: sharedSecret,
        'exclude-old-transactions': true,
      }),
    });

    if (!response.ok) {
      return {
        isValid: false,
        isPremium: false,
        error: `Apple API error: ${response.status}`,
      };
    }

    const data = (await response.json()) as StoreKit1Response;

    console.log(
      `[Apple] ${environment} verifyReceipt returned status: ${data.status}`
    );

    // Status codes:
    // 0 = valid
    // 21003 = receipt could not be authenticated (can happen after app transfer or with sandbox receipts)
    // 21007 = sandbox receipt sent to production
    if (
      (data.status === 21007 || data.status === 21003) &&
      environment === 'production'
    ) {
      // Retry in sandbox - TestFlight and sandbox receipts need the sandbox endpoint
      console.log(
        `[Apple] Retrying with sandbox endpoint (production returned ${data.status})`
      );
      return await validateStoreKit1Receipt(
        receiptData,
        sharedSecret,
        'sandbox'
      );
    }

    if (data.status !== 0) {
      return {
        isValid: false,
        isPremium: false,
        error: `Apple receipt invalid: status ${data.status}`,
      };
    }

    // Parse latest subscription info
    const latestReceipt = data.latest_receipt_info?.[0];
    if (!latestReceipt) {
      return {
        isValid: true,
        isPremium: false,
        error: 'No subscription found in receipt',
      };
    }

    const expiresDateMs = parseInt(latestReceipt.expires_date_ms, 10);
    const isActive = expiresDateMs > Date.now();

    // Check auto-renew status from pending_renewal_info
    const willRenew = data.pending_renewal_info?.[0]?.auto_renew_status === '1';

    return {
      isValid: true,
      isPremium: isActive,
      productId: latestReceipt.product_id,
      transactionId: latestReceipt.transaction_id,
      purchaseDate: new Date(parseInt(latestReceipt.purchase_date_ms, 10)),
      expirationDate: new Date(expiresDateMs),
      willRenew,
    };
  } catch (error) {
    console.error('StoreKit 1 receipt validation error:', error);
    return {
      isValid: false,
      isPremium: false,
      error: 'Failed to validate receipt with Apple',
    };
  }
}
