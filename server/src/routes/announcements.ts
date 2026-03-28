import { Router, Request, Response } from 'express';
import { getDb } from '../db';

export const announcementsRouter = Router();

/**
 * GET /announcements
 * List active announcements for the mobile app.
 * Public endpoint - no auth required.
 */
announcementsRouter.get('/', (req: Request, res: Response) => {
  const db = getDb();
  const platform = req.query.platform as string | undefined;

  let query = `
    SELECT id, title, body, announcement_type, priority, platforms,
           min_app_version, published_at, expires_at
    FROM announcements
    WHERE is_active = 1
      AND (published_at IS NULL OR published_at <= datetime('now'))
      AND (expires_at IS NULL OR expires_at > datetime('now'))
  `;

  const params: string[] = [];

  // Filter by platform if provided
  if (platform) {
    query += ` AND (platforms IS NULL OR platforms LIKE ?)`;
    params.push(`%"${platform}"%`);
  }

  query += ` ORDER BY priority DESC, published_at DESC`;

  const stmt = db.prepare(query);
  const results = (params.length > 0 ? stmt.all(...params) : stmt.all()) as Record<string, unknown>[];

  // Transform to camelCase for Flutter compatibility
  const announcements = results.map((row) => ({
    id: row.id,
    type: row.announcement_type,
    title: row.title,
    body: row.body,
    priority: row.priority,
    platforms: row.platforms ? JSON.parse(row.platforms as string) : null,
    minAppVersion: row.min_app_version,
    publishedAt: row.published_at,
    expiresAt: row.expires_at,
  }));

  res.json(announcements);
});

/**
 * GET /announcements/:id
 * Get a single announcement by ID.
 */
announcementsRouter.get('/:id', (req: Request, res: Response) => {
  const id = req.params.id;
  const db = getDb();

  const announcement = db.prepare(`
    SELECT id, title, body, announcement_type, priority, platforms,
           min_app_version, published_at, expires_at, created_at
    FROM announcements
    WHERE id = ? AND is_active = 1
  `).get(id) as Record<string, unknown> | undefined;

  if (!announcement) {
    res.status(404).json({ error: 'Announcement not found' });
    return;
  }

  res.json({
    ...announcement,
    platforms: announcement.platforms ? JSON.parse(announcement.platforms as string) : null,
  });
});
