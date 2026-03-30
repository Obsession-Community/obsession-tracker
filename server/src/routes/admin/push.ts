import { Router, Request, Response } from 'express';
import { getDb } from '../../db';
import { sendFCMBatch } from '../../utils/fcm';
import { adminAuth } from '../../middleware/adminAuth';

const router = Router();

// All admin push routes require authentication
router.use(adminAuth);

// Simple in-memory rate limiter for admin push
const pushRateLimit = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT_WINDOW_MS = 60000; // 1 minute
const RATE_LIMIT_MAX = 5; // 5 pushes per minute per admin

// Get FCM service account from environment
function getServiceAccount() {
  const serviceAccountJson = process.env.FCM_SERVICE_ACCOUNT;
  if (!serviceAccountJson) {
    return null;
  }
  try {
    return JSON.parse(serviceAccountJson);
  } catch {
    return null;
  }
}

/**
 * POST /admin/push/announcement/:id
 * Send push notification for an announcement to all registered devices.
 * Query params:
 *   - environment: 'all' | 'production' | 'development' (default: 'production')
 *   - platforms: comma-separated list of platforms to target (e.g., 'ios,android,macos')
 */
router.post('/announcement/:id', async (req: Request, res: Response) => {
  const announcementId = req.params.id;
  const targetEnv = (req.query.environment as string) || 'production';
  const platformsParam = req.query.platforms as string | undefined;
  const adminUser = (req as any).adminUser;
  const db = getDb();

  // Rate limiting
  const now = Date.now();
  const key = adminUser.id;
  const entry = pushRateLimit.get(key);

  if (entry && now < entry.resetAt) {
    if (entry.count >= RATE_LIMIT_MAX) {
      return res.status(429).json({ error: 'Rate limit exceeded. Try again later.' });
    }
    entry.count++;
  } else {
    pushRateLimit.set(key, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
  }

  // Get announcement details
  const announcement = db.prepare(`
    SELECT id, title, body, platforms, announcement_type
    FROM announcements
    WHERE id = ? AND is_active = 1
  `).get(announcementId) as any;

  if (!announcement) {
    return res.status(404).json({ error: 'Announcement not found or inactive' });
  }

  // Get FCM service account from environment
  const serviceAccount = getServiceAccount();
  if (!serviceAccount) {
    return res.status(500).json({ error: 'FCM not configured. Set FCM_SERVICE_ACCOUNT secret.' });
  }

  // Get target platforms - use query param if provided, otherwise use announcement's platforms
  const platforms: string[] = platformsParam
    ? platformsParam.split(',').map((p) => p.trim().toLowerCase())
    : announcement.platforms
      ? JSON.parse(announcement.platforms)
      : ['ios', 'android', 'macos'];

  // Build platform filter
  let platformFilter = '';
  if (platforms.length > 0 && platforms.length < 3) {
    const platformConditions = platforms.map((p) => `platform = '${p}'`).join(' OR ');
    platformFilter = `AND (${platformConditions})`;
  }

  // Build environment filter
  let envFilter = '';
  if (targetEnv === 'production') {
    envFilter = "AND (environment = 'production' OR environment IS NULL)";
  } else if (targetEnv === 'development') {
    envFilter = "AND environment = 'development'";
  }
  // 'all' = no filter

  // Get all active devices with FCM tokens
  const devices = db.prepare(`
    SELECT fcm_token
    FROM devices
    WHERE fcm_token IS NOT NULL
      AND is_active = 1
      ${platformFilter}
      ${envFilter}
  `).all() as any[];

  if (!devices || devices.length === 0) {
    return res.json({ message: 'No devices to notify', sent: 0, failed: 0 });
  }

  const tokens = devices.map((d) => d.fcm_token);

  // Prepare notification message payload
  const data: Record<string, string> = {
    title: announcement.title,
    body: announcement.body || '',
    announcement_id: announcementId,
    type: 'announcement',
  };

  // Send batch push notifications
  console.log(`📤 Sending announcement push to ${tokens.length} devices (env: ${targetEnv}, platforms: ${platforms.join(',')})`);
  const result = await sendFCMBatch(tokens, data, serviceAccount);
  console.log(`📤 Push result: sent=${result.sent}, failed=${result.failed}, invalid=${result.invalidTokens.length}`);
  if (result.errors.length > 0) {
    console.log(`📤 Push errors:`, result.errors);
  }

  // Clean up invalid tokens
  if (result.invalidTokens.length > 0) {
    const updateStmt = db.prepare('UPDATE devices SET fcm_token = NULL WHERE fcm_token = ?');
    for (const invalidToken of result.invalidTokens) {
      updateStmt.run(invalidToken);
    }
  }

  // Update announcement with push sent info
  db.prepare(`
    UPDATE announcements
    SET push_sent_at = datetime('now'), push_sent_count = COALESCE(push_sent_count, 0) + ?
    WHERE id = ?
  `).run(result.sent, announcementId);

  return res.json({
    message: 'Push notifications sent',
    total_devices: tokens.length,
    sent: result.sent,
    failed: result.failed,
    invalid_tokens_removed: result.invalidTokens.length,
    errors: result.errors,
  });
});

/**
 * POST /admin/push/hunt/:id
 * Send push notification for a hunt to all registered devices.
 * Query params:
 *   - environment: 'all' | 'production' | 'development' (default: 'production')
 */
router.post('/hunt/:id', async (req: Request, res: Response) => {
  const huntId = req.params.id;
  const targetEnv = (req.query.environment as string) || 'production';
  const adminUser = (req as any).adminUser;
  const db = getDb();

  // Rate limiting
  const now = Date.now();
  const key = adminUser.id;
  const entry = pushRateLimit.get(key);

  if (entry && now < entry.resetAt) {
    if (entry.count >= RATE_LIMIT_MAX) {
      return res.status(429).json({ error: 'Rate limit exceeded. Try again later.' });
    }
    entry.count++;
  } else {
    pushRateLimit.set(key, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
  }

  // Get hunt details
  const hunt = db.prepare(`
    SELECT id, title, description, status
    FROM hunts
    WHERE id = ?
  `).get(huntId) as any;

  if (!hunt) {
    return res.status(404).json({ error: 'Hunt not found' });
  }

  // Get FCM service account from environment
  const serviceAccount = getServiceAccount();
  if (!serviceAccount) {
    return res.status(500).json({ error: 'FCM not configured. Set FCM_SERVICE_ACCOUNT secret.' });
  }

  // Build environment filter
  let envFilter = '';
  if (targetEnv === 'production') {
    envFilter = "AND (environment = 'production' OR environment IS NULL)";
  } else if (targetEnv === 'development') {
    envFilter = "AND environment = 'development'";
  }
  // 'all' = no filter

  // Get all active devices with FCM tokens
  const devices = db.prepare(`
    SELECT fcm_token
    FROM devices
    WHERE fcm_token IS NOT NULL
      AND is_active = 1
      ${envFilter}
  `).all() as any[];

  if (!devices || devices.length === 0) {
    return res.json({ message: 'No devices to notify', sent: 0, failed: 0 });
  }

  const tokens = devices.map((d) => d.fcm_token);

  // Prepare notification message payload
  const data: Record<string, string> = {
    title: `Hunt: ${hunt.title}`,
    body: hunt.description?.substring(0, 100) || 'Check out this treasure hunt!',
    hunt_id: huntId,
    type: 'hunt',
  };

  // Send batch push notifications
  const result = await sendFCMBatch(tokens, data, serviceAccount);

  // Clean up invalid tokens
  if (result.invalidTokens.length > 0) {
    const updateStmt = db.prepare('UPDATE devices SET fcm_token = NULL WHERE fcm_token = ?');
    for (const invalidToken of result.invalidTokens) {
      updateStmt.run(invalidToken);
    }
  }

  return res.json({
    message: 'Push notifications sent',
    total_devices: tokens.length,
    sent: result.sent,
    failed: result.failed,
    invalid_tokens_removed: result.invalidTokens.length,
    errors: result.errors,
  });
});

/**
 * GET /admin/push/stats
 * Get push notification statistics.
 */
router.get('/stats', (req: Request, res: Response) => {
  const db = getDb();

  const stats = db.prepare(`
    SELECT
      COUNT(*) as total_devices,
      COUNT(CASE WHEN fcm_token IS NOT NULL THEN 1 END) as push_enabled,
      COUNT(CASE WHEN platform = 'ios' AND fcm_token IS NOT NULL THEN 1 END) as ios_enabled,
      COUNT(CASE WHEN platform = 'android' AND fcm_token IS NOT NULL THEN 1 END) as android_enabled,
      COUNT(CASE WHEN platform = 'macos' AND fcm_token IS NOT NULL THEN 1 END) as macos_enabled,
      COUNT(CASE WHEN (environment = 'production' OR environment IS NULL) AND fcm_token IS NOT NULL THEN 1 END) as production_enabled,
      COUNT(CASE WHEN environment = 'development' AND fcm_token IS NOT NULL THEN 1 END) as development_enabled
    FROM devices
    WHERE is_active = 1
  `).get();

  return res.json(stats);
});

export default router;
