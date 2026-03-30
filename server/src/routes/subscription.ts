import { Router, Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { getDb } from '../db';
import { validateAppleReceipt } from '../services/apple-receipt-validator';
import { validateGoogleReceiptFromEnv } from '../services/google-receipt-validator';

export const subscriptionRouter = Router();

// Test bypass devices - only active when ENABLE_TEST_BYPASS=true in environment
const testPremiumDeviceIds: string[] = process.env.TEST_PREMIUM_DEVICE_IDS
  ? process.env.TEST_PREMIUM_DEVICE_IDS.split(',').map(id => id.trim())
  : [];

/**
 * POST /api/v1/subscription/verify-receipt
 * Verify and store a purchase receipt from mobile app.
 * Called after purchase/restore to notify backend for download access control.
 */
subscriptionRouter.post('/verify-receipt', async (req: Request, res: Response) => {
  try {
    const apiKey = req.header('X-API-Key');
    const deviceId = req.header('X-Device-ID');

    console.log(`📱 /verify-receipt request from device: ${deviceId?.substring(0, 8)}...`);

    if (!apiKey || !deviceId) {
      console.log(`❌ Missing headers: apiKey=${!!apiKey}, deviceId=${!!deviceId}`);
      return res.status(401).json({ error: 'Missing authentication headers' });
    }

    const { platform, receipt_data, product_id, transaction_id } = req.body;

    if (!platform || !receipt_data || !product_id) {
      console.log(`❌ Missing body fields: platform=${!!platform}, receipt_data=${!!receipt_data}, product_id=${!!product_id}`);
      return res.status(400).json({ error: 'Missing required fields' });
    }

    if (platform !== 'ios' && platform !== 'android') {
      console.log(`❌ Invalid platform: ${platform}`);
      return res.status(400).json({ error: 'Invalid platform' });
    }

    const db = getDb();

    // Verify device exists and is active
    const device = db.prepare(`
      SELECT id, device_id FROM devices WHERE api_key = ? AND device_id = ? AND is_active = 1
    `).get(apiKey, deviceId) as { id: string; device_id: string } | undefined;

    if (!device) {
      console.log(`❌ Device not found: deviceId=${deviceId}, apiKey=${apiKey?.substring(0, 8)}...`);
      return res.status(401).json({ error: 'Invalid device credentials' });
    }

    console.log(`✅ Device found: ${device.device_id.substring(0, 8)}...`);

    // Validate receipt with platform stores
    let validation;
    if (platform === 'ios') {
      const appleSharedSecret = process.env.APPLE_SHARED_SECRET;
      if (!appleSharedSecret) {
        console.error('APPLE_SHARED_SECRET not configured');
        return res.status(503).json({ error: 'Apple validation not configured' });
      }

      validation = await validateAppleReceipt(receipt_data, appleSharedSecret);
    } else {
      // Android
      const packageName = 'com.obsessiontracker.app';
      validation = await validateGoogleReceiptFromEnv(packageName, product_id, receipt_data);
    }

    if (!validation.isValid) {
      console.warn(`Receipt validation failed for device ${deviceId}: ${validation.error}`);
      return res.status(400).json({
        success: false,
        is_premium: false,
        error: validation.error || 'Receipt validation failed',
      });
    }

    // Store subscription in database
    const subscriptionId = uuidv4();
    const now = new Date().toISOString();

    // Get transaction ID based on platform, with fallback to prevent UNIQUE constraint issues
    const txnId = platform === 'ios'
      ? ('transactionId' in validation ? validation.transactionId : transaction_id)
      : ('purchaseToken' in validation ? validation.purchaseToken : transaction_id);
    const safeTxnId = txnId || `${device.device_id}-${Date.now()}`;

    try {
      // Use a two-step approach: delete existing then insert
      // This avoids UNIQUE constraint conflicts on transaction_id
      db.prepare('DELETE FROM subscriptions WHERE device_id = ?').run(device.device_id);
      db.prepare(`
        INSERT INTO subscriptions (
          id, device_id, platform, product_id, transaction_id,
          purchase_date, expiration_date, is_active, auto_renew_status,
          receipt_data, last_validated_at, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        subscriptionId,
        device.device_id,
        platform,
        validation.productId || product_id,
        safeTxnId,
        validation.purchaseDate?.toISOString() || now,
        validation.expirationDate?.toISOString() || null,
        validation.isPremium ? 1 : 0,
        validation.willRenew ? 1 : 0,
        receipt_data,
        now,
        now,
        now
      );
      console.log(`✅ Subscription validated and stored for device ${deviceId}: ${validation.isPremium ? 'Premium' : 'Free'}`);
    } catch (dbError: any) {
      console.error(`❌ Failed to store subscription for device ${deviceId}: ${dbError.message}`);
      // Still return the validation result even if DB write fails
    }

    return res.json({
      success: true,
      is_premium: validation.isPremium,
      product_id: validation.productId,
      expires_at: validation.expirationDate?.toISOString() || null,
    });

  } catch (error) {
    console.error('Receipt verification error:', error);
    return res.status(500).json({
      success: false,
      is_premium: false,
      error: 'Receipt verification failed',
    });
  }
});

/**
 * POST /api/v1/subscription/validate
 * Validate device subscription status from local database.
 * Used by NHP server to check if device should get download access.
 * Fast database lookup - no external API calls.
 */
subscriptionRouter.post('/validate', async (req: Request, res: Response) => {
  try {
    const apiKey = req.header('X-API-Key');

    if (!apiKey) {
      return res.status(401).json({ error: 'Missing API key' });
    }

    const db = getDb();

    // Look up device by API key
    const device = db.prepare(`
      SELECT id, device_id, is_active FROM devices WHERE api_key = ?
    `).get(apiKey) as { id: string; device_id: string; is_active: number } | undefined;

    if (!device) {
      return res.status(401).json({ error: 'Invalid API key' });
    }

    if (!device.is_active) {
      return res.status(403).json({ error: 'Device deactivated' });
    }

    // Update last_seen_at
    db.prepare("UPDATE devices SET last_seen_at = datetime('now') WHERE id = ?").run(device.id);

    // Test bypass - only when ENABLE_TEST_BYPASS=true AND device is in TEST_PREMIUM_DEVICE_IDS
    if (process.env.ENABLE_TEST_BYPASS === 'true' && testPremiumDeviceIds.includes(device.device_id)) {
      console.log(`[TEST] Bypassing subscription check for test device: ${device.device_id}`);
      return res.json({
        is_premium: true,
        entitlements: { premium: { is_active: true } },
        expires_at: null,
      });
    }

    // Query subscription from local database
    const subscription = db.prepare(`
      SELECT product_id, expiration_date, is_active, auto_renew_status
      FROM subscriptions
      WHERE device_id = ? AND is_active = 1
    `).get(device.device_id) as {
      product_id: string;
      expiration_date: string | null;
      is_active: number;
      auto_renew_status: number;
    } | undefined;

    if (!subscription) {
      // No subscription found
      return res.json({
        is_premium: false,
        entitlements: {},
        expires_at: null,
      });
    }

    // Check if expired
    const isExpired = subscription.expiration_date
      ? new Date(subscription.expiration_date) < new Date()
      : false;

    const isPremium = subscription.is_active === 1 && !isExpired;

    return res.json({
      is_premium: isPremium,
      entitlements: isPremium ? { premium: { is_active: true } } : {},
      expires_at: subscription.expiration_date,
    });

  } catch (error) {
    console.error('Subscription validation error:', error);
    return res.status(500).json({
      is_premium: false,
      error: 'Subscription service error',
    });
  }
});

/**
 * GET /api/v1/subscription/status
 * Get full subscription status for the device (for debugging/admin).
 * Queries local database - no external API calls.
 */
subscriptionRouter.get('/status', async (req: Request, res: Response) => {
  try {
    const apiKey = req.header('X-API-Key');

    if (!apiKey) {
      return res.status(401).json({ error: 'Missing API key' });
    }

    const db = getDb();

    const device = db.prepare(`
      SELECT id, device_id FROM devices WHERE api_key = ? AND is_active = 1
    `).get(apiKey) as { id: string; device_id: string } | undefined;

    if (!device) {
      return res.status(401).json({ error: 'Invalid API key' });
    }

    // Update last_seen_at
    db.prepare("UPDATE devices SET last_seen_at = datetime('now') WHERE id = ?").run(device.id);

    // Query subscription from local database
    const subscription = db.prepare(`
      SELECT
        platform,
        product_id,
        transaction_id,
        purchase_date,
        expiration_date,
        is_active,
        auto_renew_status,
        last_validated_at,
        created_at
      FROM subscriptions
      WHERE device_id = ?
    `).get(device.device_id) as {
      platform: string;
      product_id: string;
      transaction_id: string;
      purchase_date: string;
      expiration_date: string | null;
      is_active: number;
      auto_renew_status: number;
      last_validated_at: string;
      created_at: string;
    } | undefined;

    if (!subscription) {
      return res.json({
        is_premium: false,
        subscription_type: 'free',
        features: [],
      });
    }

    // Check if expired
    const isExpired = subscription.expiration_date
      ? new Date(subscription.expiration_date) < new Date()
      : false;

    const isPremium = subscription.is_active === 1 && !isExpired;

    // Determine active features based on subscription
    const features: string[] = [];
    if (isPremium) {
      features.push('offline_maps', 'premium_layers');
    }

    return res.json({
      is_premium: isPremium,
      subscription_type: isPremium ? 'premium' : 'free',
      features,
      platform: subscription.platform,
      product_id: subscription.product_id,
      transaction_id: subscription.transaction_id,
      purchase_date: subscription.purchase_date,
      expires_at: subscription.expiration_date,
      auto_renew: subscription.auto_renew_status === 1,
      last_validated_at: subscription.last_validated_at,
      created_at: subscription.created_at,
    });

  } catch (error) {
    console.error('Subscription status error:', error);
    return res.status(500).json({ error: 'Subscription service error' });
  }
});
