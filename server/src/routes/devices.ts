import { Router, Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import crypto from 'crypto';
import { getDb } from '../db';

export const devicesRouter = Router();

/**
 * Generate a secure API key (64 hex chars)
 */
function generateApiKey(): string {
  return crypto.randomBytes(32).toString('hex');
}

interface RegisterBody {
  device_id: string;
  platform: string;
  app_version?: string;
}

/**
 * POST /api/v1/devices/register
 * Register a new device and get an API key.
 */
devicesRouter.post('/register', async (req: Request, res: Response) => {
  try {
    const body = req.body as RegisterBody;

    if (!body.device_id || !body.platform) {
      return res.status(400).json({ error: 'device_id and platform are required' });
    }

    const db = getDb();

    // Check if device already registered
    const existing = db
      .prepare('SELECT id, api_key FROM devices WHERE device_id = ?')
      .get(body.device_id) as { id: string; api_key: string } | undefined;

    if (existing) {
      // Return existing API key
      return res.json({
        id: existing.id,
        api_key: existing.api_key,
        message: 'Device already registered',
      });
    }

    // Register new device
    const id = uuidv4();
    const apiKey = generateApiKey();

    db.prepare(`
      INSERT INTO devices (id, api_key, device_id, platform, app_version, created_at, last_seen_at, is_active)
      VALUES (?, ?, ?, ?, ?, datetime('now'), datetime('now'), 1)
    `).run(id, apiKey, body.device_id, body.platform, body.app_version || null);

    return res.status(201).json({
      id,
      api_key: apiKey,
      message: 'Device registered successfully',
    });
  } catch (error) {
    console.error('Device registration error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/v1/devices/me
 * Get current device info. Requires API key.
 */
devicesRouter.get('/me', async (req: Request, res: Response) => {
  try {
    const apiKey = req.header('X-API-Key');

    if (!apiKey) {
      return res.status(401).json({ error: 'Missing API key' });
    }

    const db = getDb();

    const device = db.prepare(`
      SELECT id, device_id, platform, app_version, created_at, last_seen_at
      FROM devices
      WHERE api_key = ? AND is_active = 1
    `).get(apiKey);

    if (!device) {
      return res.status(401).json({ error: 'Invalid API key' });
    }

    // Update last_seen_at
    db.prepare("UPDATE devices SET last_seen_at = datetime('now') WHERE api_key = ?").run(apiKey);

    return res.json(device);
  } catch (error) {
    console.error('Device lookup error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

interface FcmTokenBody {
  fcm_token: string;
  environment?: 'development' | 'production';
}

/**
 * POST /api/v1/devices/fcm-token
 * Register or update FCM token for push notifications.
 */
devicesRouter.post('/fcm-token', async (req: Request, res: Response) => {
  try {
    const apiKey = req.header('X-API-Key');

    if (!apiKey) {
      return res.status(401).json({ error: 'Missing API key' });
    }

    const body = req.body as FcmTokenBody;

    if (!body.fcm_token) {
      return res.status(400).json({ error: 'fcm_token is required' });
    }

    const db = getDb();

    // Find device by API key
    const device = db
      .prepare('SELECT id FROM devices WHERE api_key = ? AND is_active = 1')
      .get(apiKey) as { id: string } | undefined;

    if (!device) {
      return res.status(401).json({ error: 'Invalid API key' });
    }

    // Update FCM token and environment
    const environment = body.environment || 'production';
    db.prepare(`
      UPDATE devices
      SET fcm_token = ?,
          fcm_token_updated_at = datetime('now'),
          environment = ?,
          last_seen_at = datetime('now')
      WHERE id = ?
    `).run(body.fcm_token, environment, device.id);

    console.log(`FCM token registered for device ${device.id} (${environment})`);

    return res.json({ message: 'FCM token registered successfully' });
  } catch (error) {
    console.error('FCM token registration error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * DELETE /api/v1/devices/fcm-token
 * Remove FCM token (opt-out of push notifications).
 */
devicesRouter.delete('/fcm-token', async (req: Request, res: Response) => {
  try {
    const apiKey = req.header('X-API-Key');

    if (!apiKey) {
      return res.status(401).json({ error: 'Missing API key' });
    }

    const db = getDb();

    // Find device by API key
    const device = db
      .prepare('SELECT id FROM devices WHERE api_key = ? AND is_active = 1')
      .get(apiKey) as { id: string } | undefined;

    if (!device) {
      return res.status(401).json({ error: 'Invalid API key' });
    }

    // Clear FCM token
    db.prepare(`
      UPDATE devices
      SET fcm_token = NULL,
          fcm_token_updated_at = datetime('now'),
          last_seen_at = datetime('now')
      WHERE id = ?
    `).run(device.id);

    console.log(`FCM token removed for device ${device.id}`);

    return res.json({ message: 'FCM token removed successfully' });
  } catch (error) {
    console.error('FCM token removal error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});
