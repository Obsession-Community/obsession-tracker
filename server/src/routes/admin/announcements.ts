import { Router, Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { getDb } from '../../db';
import { adminAuth } from '../../middleware/adminAuth';

export const adminAnnouncementsRouter = Router();

// All admin announcement routes require authentication
adminAnnouncementsRouter.use(adminAuth);

/**
 * GET /admin/announcements
 * List all announcements (including inactive).
 */
adminAnnouncementsRouter.get('/', (req: Request, res: Response) => {
  const db = getDb();

  const results = db.prepare(`
    SELECT id, title, body, announcement_type, priority, platforms,
           min_app_version, published_at, expires_at, is_active,
           created_by, created_at, updated_at
    FROM announcements
    ORDER BY created_at DESC
  `).all() as Record<string, unknown>[];

  // Transform snake_case to camelCase for Angular compatibility
  const announcements = results.map((row) => ({
    id: row.id,
    title: row.title,
    body: row.body,
    type: row.announcement_type,
    priority: row.priority,
    targetPlatforms: row.platforms ? JSON.parse(row.platforms as string) : null,
    targetMinVersion: row.min_app_version,
    publishedAt: row.published_at,
    expiresAt: row.expires_at,
    isActive: row.is_active,
    createdBy: row.created_by,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }));

  res.json(announcements);
});

/**
 * GET /admin/announcements/:id
 * Get a single announcement.
 */
adminAnnouncementsRouter.get('/:id', (req: Request, res: Response) => {
  const id = req.params.id;
  const db = getDb();

  const announcement = db.prepare(`
    SELECT id, title, body, announcement_type, priority, platforms,
           min_app_version, published_at, expires_at, is_active,
           created_by, created_at, updated_at
    FROM announcements
    WHERE id = ?
  `).get(id) as Record<string, unknown> | undefined;

  if (!announcement) {
    res.status(404).json({ error: 'Announcement not found' });
    return;
  }

  res.json({
    id: announcement.id,
    title: announcement.title,
    body: announcement.body,
    type: announcement.announcement_type,
    priority: announcement.priority,
    targetPlatforms: announcement.platforms ? JSON.parse(announcement.platforms as string) : null,
    targetMinVersion: announcement.min_app_version,
    publishedAt: announcement.published_at,
    expiresAt: announcement.expires_at,
    isActive: announcement.is_active,
    createdBy: announcement.created_by,
    createdAt: announcement.created_at,
    updatedAt: announcement.updated_at,
  });
});

/**
 * POST /admin/announcements
 * Create a new announcement.
 */
adminAnnouncementsRouter.post('/', (req: Request, res: Response) => {
  const adminUser = req.adminUser!;
  const body = req.body as {
    title: string;
    body?: string;
    announcement_type?: string;
    priority?: string;
    platforms?: string[];
    min_app_version?: string;
    published_at?: string;
    expires_at?: string;
    is_active?: boolean;
  };

  if (!body.title) {
    res.status(400).json({ error: 'Title is required' });
    return;
  }

  const db = getDb();
  const id = uuidv4();

  db.prepare(`
    INSERT INTO announcements (
      id, title, body, announcement_type, priority, platforms,
      min_app_version, published_at, expires_at, is_active, created_by
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    id,
    body.title,
    body.body || null,
    body.announcement_type || 'info',
    body.priority || 'normal',
    body.platforms ? JSON.stringify(body.platforms) : null,
    body.min_app_version || null,
    body.published_at || null,
    body.expires_at || null,
    body.is_active !== false ? 1 : 0,
    adminUser.id
  );

  res.status(201).json({ id, message: 'Announcement created' });
});

/**
 * PUT /admin/announcements/:id
 * Update an announcement.
 */
adminAnnouncementsRouter.put('/:id', (req: Request, res: Response) => {
  const id = req.params.id;
  const body = req.body as {
    title?: string;
    body?: string;
    announcement_type?: string;
    priority?: string;
    platforms?: string[];
    min_app_version?: string;
    published_at?: string;
    expires_at?: string;
    is_active?: boolean;
  };

  const db = getDb();

  // Check exists
  const existing = db.prepare('SELECT id FROM announcements WHERE id = ?').get(id);

  if (!existing) {
    res.status(404).json({ error: 'Announcement not found' });
    return;
  }

  // Build update query dynamically
  const updates: string[] = ['updated_at = datetime("now")'];
  const params: unknown[] = [];

  if (body.title !== undefined) {
    updates.push('title = ?');
    params.push(body.title);
  }
  if (body.body !== undefined) {
    updates.push('body = ?');
    params.push(body.body);
  }
  if (body.announcement_type !== undefined) {
    updates.push('announcement_type = ?');
    params.push(body.announcement_type);
  }
  if (body.priority !== undefined) {
    updates.push('priority = ?');
    params.push(body.priority);
  }
  if (body.platforms !== undefined) {
    updates.push('platforms = ?');
    params.push(JSON.stringify(body.platforms));
  }
  if (body.min_app_version !== undefined) {
    updates.push('min_app_version = ?');
    params.push(body.min_app_version);
  }
  if (body.published_at !== undefined) {
    updates.push('published_at = ?');
    params.push(body.published_at);
  }
  if (body.expires_at !== undefined) {
    updates.push('expires_at = ?');
    params.push(body.expires_at);
  }
  if (body.is_active !== undefined) {
    updates.push('is_active = ?');
    params.push(body.is_active ? 1 : 0);
  }

  params.push(id);

  db.prepare(`UPDATE announcements SET ${updates.join(', ')} WHERE id = ?`).run(...params);

  res.json({ message: 'Announcement updated' });
});

/**
 * DELETE /admin/announcements/:id
 * Delete an announcement.
 */
adminAnnouncementsRouter.delete('/:id', (req: Request, res: Response) => {
  const id = req.params.id;
  const db = getDb();

  const result = db.prepare('DELETE FROM announcements WHERE id = ?').run(id);

  if (result.changes === 0) {
    res.status(404).json({ error: 'Announcement not found' });
    return;
  }

  res.json({ message: 'Announcement deleted' });
});
