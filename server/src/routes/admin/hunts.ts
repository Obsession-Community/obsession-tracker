import { Router, Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { getDb } from '../../db';
import { adminAuth } from '../../middleware/adminAuth';

export const adminHuntsRouter = Router();

// All admin hunt routes require authentication
adminHuntsRouter.use(adminAuth);

/**
 * GET /admin/hunts
 * List all hunts (including drafts).
 */
adminHuntsRouter.get('/', (req: Request, res: Response) => {
  const db = getDb();

  const results = db.prepare(`
    SELECT id, slug, title, subtitle, description, status, is_draft, featured, prize_value,
           prize_description, location_hint, search_region, difficulty, hunt_type,
           provider_name, provider_url, provider_logo_url,
           announced_at, starts_at, found_at, ends_at,
           featured_order, hero_image_url, thumbnail_url,
           created_by, created_at, updated_at
    FROM hunts
    ORDER BY created_at DESC
  `).all() as Record<string, unknown>[];

  const hunts = results.map((row) => ({
    id: row.id,
    slug: row.slug,
    title: row.title,
    subtitle: row.subtitle,
    description: row.description,
    status: row.status,
    isDraft: !!row.is_draft,
    featured: !!row.featured,
    prizeValueUsd: row.prize_value,
    prizeDescription: row.prize_description,
    locationHint: row.location_hint,
    searchRegion: row.search_region,
    difficulty: row.difficulty,
    huntType: row.hunt_type || 'field',
    providerName: row.provider_name,
    providerUrl: row.provider_url,
    providerLogoUrl: row.provider_logo_url,
    announcedAt: row.announced_at,
    startsAt: row.starts_at,
    foundAt: row.found_at,
    endsAt: row.ends_at,
    featuredOrder: row.featured_order,
    heroImageUrl: row.hero_image_url,
    thumbnailUrl: row.thumbnail_url,
    createdBy: row.created_by,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }));

  res.json(hunts);
});

/**
 * GET /admin/hunts/:id
 * Get a single hunt with all related data.
 */
adminHuntsRouter.get('/:id', (req: Request, res: Response) => {
  const id = req.params.id;
  const db = getDb();

  const hunt = db.prepare(`
    SELECT id, slug, title, subtitle, description, status, is_draft, featured, prize_value,
           prize_description, location_hint, search_region, difficulty, hunt_type,
           provider_name, provider_url, provider_logo_url,
           announced_at, starts_at, found_at, ends_at,
           featured_order, hero_image_url, thumbnail_url,
           created_by, created_at, updated_at
    FROM hunts
    WHERE id = ?
  `).get(id) as Record<string, unknown> | undefined;

  if (!hunt) {
    res.status(404).json({ error: 'Hunt not found' });
    return;
  }

  const huntId = hunt.id as string;

  // Get related data
  const media = db.prepare('SELECT * FROM hunt_media WHERE hunt_id = ? ORDER BY display_order').all(huntId);
  const links = db.prepare('SELECT * FROM hunt_links WHERE hunt_id = ? ORDER BY display_order').all(huntId);
  const updates = db.prepare('SELECT * FROM hunt_updates WHERE hunt_id = ? ORDER BY created_at DESC').all(huntId);

  res.json({
    id: hunt.id,
    slug: hunt.slug,
    title: hunt.title,
    subtitle: hunt.subtitle,
    description: hunt.description,
    status: hunt.status,
    isDraft: !!hunt.is_draft,
    featured: !!hunt.featured,
    prizeValueUsd: hunt.prize_value,
    prizeDescription: hunt.prize_description,
    locationHint: hunt.location_hint,
    searchRegion: hunt.search_region,
    difficulty: hunt.difficulty,
    huntType: hunt.hunt_type || 'field',
    providerName: hunt.provider_name,
    providerUrl: hunt.provider_url,
    providerLogoUrl: hunt.provider_logo_url,
    announcedAt: hunt.announced_at,
    startsAt: hunt.starts_at,
    foundAt: hunt.found_at,
    endsAt: hunt.ends_at,
    featuredOrder: hunt.featured_order,
    heroImageUrl: hunt.hero_image_url,
    thumbnailUrl: hunt.thumbnail_url,
    createdBy: hunt.created_by,
    createdAt: hunt.created_at,
    updatedAt: hunt.updated_at,
    media: media || [],
    links: links || [],
    updates: updates || [],
  });
});

/**
 * POST /admin/hunts
 * Create a new hunt.
 */
adminHuntsRouter.post('/', (req: Request, res: Response) => {
  const adminUser = req.adminUser!;
  const body = req.body;

  if (!body.title) {
    res.status(400).json({ error: 'Title is required' });
    return;
  }

  const db = getDb();
  const id = uuidv4();

  // Generate slug from title if not provided
  const slug = body.slug || body.title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');

  // Check slug uniqueness
  const existing = db.prepare('SELECT id FROM hunts WHERE slug = ?').get(slug);

  if (existing) {
    res.status(409).json({ error: 'Slug already exists' });
    return;
  }

  // Default is_draft to true (new hunts are drafts by default)
  const isDraft = body.is_draft ?? body.isDraft ?? true;

  db.prepare(`
    INSERT INTO hunts (
      id, slug, title, subtitle, description, status, is_draft, featured,
      prize_value, prize_description, location_hint, search_region, difficulty, hunt_type,
      provider_name, provider_url, provider_logo_url,
      announced_at, starts_at, found_at, ends_at,
      featured_order, hero_image_url, thumbnail_url,
      created_by
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    id,
    slug,
    body.title,
    body.subtitle || null,
    body.description || null,
    body.status || 'upcoming',
    isDraft ? 1 : 0,
    body.featured ? 1 : 0,
    body.prize_value ?? body.prizeValueUsd ?? null,
    body.prize_description ?? body.prizeDescription ?? null,
    body.location_hint ?? body.locationHint ?? null,
    body.search_region ?? body.searchRegion ?? null,
    body.difficulty || null,
    body.hunt_type ?? body.huntType ?? 'field',
    body.provider_name ?? body.providerName ?? null,
    body.provider_url ?? body.providerUrl ?? null,
    body.provider_logo_url ?? body.providerLogoUrl ?? null,
    body.announced_at ?? body.announcedAt ?? null,
    body.starts_at ?? body.startsAt ?? null,
    body.found_at ?? body.foundAt ?? null,
    body.ends_at ?? body.endsAt ?? null,
    body.featured_order ?? body.featuredOrder ?? null,
    body.hero_image_url ?? body.heroImageUrl ?? null,
    body.thumbnail_url ?? body.thumbnailUrl ?? null,
    adminUser.id
  );

  res.status(201).json({ id, slug, message: 'Hunt created' });
});

/**
 * PUT /admin/hunts/:id
 * Update a hunt.
 */
adminHuntsRouter.put('/:id', (req: Request, res: Response) => {
  const id = req.params.id;
  const body = req.body;

  const db = getDb();

  const existing = db.prepare('SELECT id FROM hunts WHERE id = ?').get(id);

  if (!existing) {
    res.status(404).json({ error: 'Hunt not found' });
    return;
  }

  // Check slug uniqueness if changing
  if (body.slug) {
    const slugExists = db.prepare('SELECT id FROM hunts WHERE slug = ? AND id != ?').get(body.slug, id);
    if (slugExists) {
      res.status(409).json({ error: 'Slug already exists' });
      return;
    }
  }

  const updates: string[] = ["updated_at = datetime('now')"];
  const params: unknown[] = [];

  // Basic fields
  if (body.title !== undefined) { updates.push('title = ?'); params.push(body.title); }
  if (body.slug !== undefined) { updates.push('slug = ?'); params.push(body.slug); }
  if (body.subtitle !== undefined) { updates.push('subtitle = ?'); params.push(body.subtitle); }
  if (body.description !== undefined) { updates.push('description = ?'); params.push(body.description); }
  if (body.status !== undefined) { updates.push('status = ?'); params.push(body.status); }

  // Draft status
  const isDraft = body.is_draft ?? body.isDraft;
  if (isDraft !== undefined) { updates.push('is_draft = ?'); params.push(isDraft ? 1 : 0); }

  if (body.featured !== undefined) { updates.push('featured = ?'); params.push(body.featured ? 1 : 0); }
  if (body.difficulty !== undefined) { updates.push('difficulty = ?'); params.push(body.difficulty); }

  // Prize fields
  const prizeValue = body.prize_value ?? body.prizeValueUsd;
  if (prizeValue !== undefined) { updates.push('prize_value = ?'); params.push(prizeValue); }
  const prizeDesc = body.prize_description ?? body.prizeDescription;
  if (prizeDesc !== undefined) { updates.push('prize_description = ?'); params.push(prizeDesc); }

  // Location fields
  const locationHint = body.location_hint ?? body.locationHint;
  if (locationHint !== undefined) { updates.push('location_hint = ?'); params.push(locationHint); }
  const searchRegion = body.search_region ?? body.searchRegion;
  if (searchRegion !== undefined) { updates.push('search_region = ?'); params.push(searchRegion); }

  // Hunt type
  const huntType = body.hunt_type ?? body.huntType;
  if (huntType !== undefined) { updates.push('hunt_type = ?'); params.push(huntType); }

  // Provider fields
  const providerName = body.provider_name ?? body.providerName;
  if (providerName !== undefined) { updates.push('provider_name = ?'); params.push(providerName); }
  const providerUrl = body.provider_url ?? body.providerUrl;
  if (providerUrl !== undefined) { updates.push('provider_url = ?'); params.push(providerUrl); }
  const providerLogoUrl = body.provider_logo_url ?? body.providerLogoUrl;
  if (providerLogoUrl !== undefined) { updates.push('provider_logo_url = ?'); params.push(providerLogoUrl); }

  // Date fields
  const announcedAt = body.announced_at ?? body.announcedAt;
  if (announcedAt !== undefined) { updates.push('announced_at = ?'); params.push(announcedAt); }
  const startsAt = body.starts_at ?? body.startsAt;
  if (startsAt !== undefined) { updates.push('starts_at = ?'); params.push(startsAt); }
  const foundAt = body.found_at ?? body.foundAt;
  if (foundAt !== undefined) { updates.push('found_at = ?'); params.push(foundAt); }
  const endsAt = body.ends_at ?? body.endsAt;
  if (endsAt !== undefined) { updates.push('ends_at = ?'); params.push(endsAt); }

  // Display fields
  const featuredOrder = body.featured_order ?? body.featuredOrder;
  if (featuredOrder !== undefined) { updates.push('featured_order = ?'); params.push(featuredOrder); }
  const heroImageUrl = body.hero_image_url ?? body.heroImageUrl;
  if (heroImageUrl !== undefined) { updates.push('hero_image_url = ?'); params.push(heroImageUrl); }
  const thumbnailUrl = body.thumbnail_url ?? body.thumbnailUrl;
  if (thumbnailUrl !== undefined) { updates.push('thumbnail_url = ?'); params.push(thumbnailUrl); }

  params.push(id);

  db.prepare(`UPDATE hunts SET ${updates.join(', ')} WHERE id = ?`).run(...params);

  res.json({ message: 'Hunt updated' });
});

/**
 * DELETE /admin/hunts/:id
 * Delete a hunt and all related data.
 */
adminHuntsRouter.delete('/:id', (req: Request, res: Response) => {
  const id = req.params.id;
  const db = getDb();

  const result = db.prepare('DELETE FROM hunts WHERE id = ?').run(id);

  if (result.changes === 0) {
    res.status(404).json({ error: 'Hunt not found' });
    return;
  }

  res.json({ message: 'Hunt deleted' });
});

// ==================== Hunt Media ====================

adminHuntsRouter.get('/:id/media', (req: Request, res: Response) => {
  const huntId = req.params.id;
  const db = getDb();

  const results = db.prepare('SELECT * FROM hunt_media WHERE hunt_id = ? ORDER BY display_order').all(huntId);
  res.json({ media: results || [] });
});

adminHuntsRouter.post('/:id/media', (req: Request, res: Response) => {
  const huntId = req.params.id;
  const body = req.body;

  if (!body.url) {
    res.status(400).json({ error: 'URL is required' });
    return;
  }

  const db = getDb();
  const id = uuidv4();

  db.prepare(`
    INSERT INTO hunt_media (id, hunt_id, media_type, url, caption, display_order)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(id, huntId, body.media_type || 'image', body.url, body.caption || null, body.display_order || 0);

  res.status(201).json({ id, message: 'Media added' });
});

adminHuntsRouter.delete('/:huntId/media/:mediaId', (req: Request, res: Response) => {
  const mediaId = req.params.mediaId;
  const db = getDb();

  db.prepare('DELETE FROM hunt_media WHERE id = ?').run(mediaId);
  res.json({ message: 'Media deleted' });
});

// ==================== Hunt Links ====================

adminHuntsRouter.get('/:id/links', (req: Request, res: Response) => {
  const huntId = req.params.id;
  const db = getDb();

  const results = db.prepare('SELECT * FROM hunt_links WHERE hunt_id = ? ORDER BY display_order').all(huntId);
  res.json({ links: results || [] });
});

adminHuntsRouter.post('/:id/links', (req: Request, res: Response) => {
  const huntId = req.params.id;
  const body = req.body;

  if (!body.title || !body.url) {
    res.status(400).json({ error: 'Title and URL are required' });
    return;
  }

  const db = getDb();
  const id = uuidv4();

  db.prepare(`
    INSERT INTO hunt_links (id, hunt_id, title, url, link_type, display_order)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(id, huntId, body.title, body.url, body.link_type || null, body.display_order || 0);

  res.status(201).json({ id, message: 'Link added' });
});

adminHuntsRouter.delete('/:huntId/links/:linkId', (req: Request, res: Response) => {
  const linkId = req.params.linkId;
  const db = getDb();

  db.prepare('DELETE FROM hunt_links WHERE id = ?').run(linkId);
  res.json({ message: 'Link deleted' });
});

// ==================== Hunt Updates ====================

adminHuntsRouter.get('/:id/updates', (req: Request, res: Response) => {
  const huntId = req.params.id;
  const db = getDb();

  const results = db.prepare('SELECT * FROM hunt_updates WHERE hunt_id = ? ORDER BY created_at DESC').all(huntId);
  res.json({ updates: results || [] });
});

adminHuntsRouter.post('/:id/updates', (req: Request, res: Response) => {
  const huntId = req.params.id;
  const adminUser = req.adminUser!;
  const body = req.body;

  if (!body.content) {
    res.status(400).json({ error: 'Content is required' });
    return;
  }

  const db = getDb();
  const id = uuidv4();

  db.prepare(`
    INSERT INTO hunt_updates (id, hunt_id, title, content, created_by)
    VALUES (?, ?, ?, ?, ?)
  `).run(id, huntId, body.title || null, body.content, adminUser.id);

  res.status(201).json({ id, message: 'Update added' });
});

adminHuntsRouter.delete('/:huntId/updates/:updateId', (req: Request, res: Response) => {
  const updateId = req.params.updateId;
  const db = getDb();

  db.prepare('DELETE FROM hunt_updates WHERE id = ?').run(updateId);
  res.json({ message: 'Update deleted' });
});
