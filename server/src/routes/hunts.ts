import { Router, Request, Response } from 'express';
import { getDb } from '../db';

export const huntsRouter = Router();

/**
 * GET /hunts
 * List published hunts for the mobile app.
 * Public endpoint - no auth required.
 */
huntsRouter.get('/', (req: Request, res: Response) => {
  const db = getDb();
  const featured = req.query.featured as string | undefined;
  const status = req.query.status as string | undefined;

  let query = `
    SELECT id, slug, title, subtitle, description, status, featured, prize_value,
           prize_description, location_hint, search_region, difficulty, hunt_type,
           provider_name, provider_url, provider_logo_url,
           announced_at, starts_at, found_at, ends_at,
           featured_order, hero_image_url, thumbnail_url,
           created_at, updated_at
    FROM hunts
    WHERE is_draft = 0
  `;

  const params: unknown[] = [];

  if (featured === 'true') {
    query += ` AND featured = 1`;
  }

  if (status) {
    query += ` AND status = ?`;
    params.push(status);
  }

  query += ` ORDER BY featured DESC, featured_order ASC, created_at DESC`;

  const stmt = db.prepare(query);
  const results = (params.length > 0 ? stmt.all(...params) : stmt.all()) as Record<string, unknown>[];

  // Transform to camelCase for Flutter compatibility
  const hunts = results.map((row) => ({
    id: row.id,
    slug: row.slug,
    title: row.title,
    subtitle: row.subtitle,
    description: row.description,
    status: row.status,
    featured: !!row.featured,
    prizeValueUsd: row.prize_value,
    prizeDescription: row.prize_description,
    locationHint: row.location_hint,
    searchRegion: row.search_region,
    difficulty: row.difficulty,
    huntType: row.hunt_type || 'field',
    providerName: row.provider_name || 'Unknown Provider',
    providerUrl: row.provider_url,
    providerLogoUrl: row.provider_logo_url,
    announcedAt: row.announced_at,
    startsAt: row.starts_at,
    foundAt: row.found_at,
    endsAt: row.ends_at,
    featuredOrder: row.featured_order,
    heroImageUrl: row.hero_image_url,
    thumbnailUrl: row.thumbnail_url,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }));

  res.json(hunts);
});

/**
 * GET /hunts/:slug
 * Get a single hunt by slug with media, links, and updates.
 */
huntsRouter.get('/:slug', (req: Request, res: Response) => {
  const slug = req.params.slug;
  const db = getDb();

  const hunt = db.prepare(`
    SELECT id, slug, title, subtitle, description, status, featured, prize_value,
           prize_description, location_hint, search_region, difficulty, hunt_type,
           provider_name, provider_url, provider_logo_url,
           announced_at, starts_at, found_at, ends_at,
           featured_order, hero_image_url, thumbnail_url,
           created_at, updated_at
    FROM hunts
    WHERE slug = ? AND is_draft = 0
  `).get(slug) as Record<string, unknown> | undefined;

  if (!hunt) {
    res.status(404).json({ error: 'Hunt not found' });
    return;
  }

  const huntId = hunt.id as string;

  // Get media
  const media = db.prepare(`
    SELECT id, media_type, url, caption, display_order
    FROM hunt_media
    WHERE hunt_id = ?
    ORDER BY display_order ASC
  `).all(huntId);

  // Get links
  const links = db.prepare(`
    SELECT id, title, url, link_type, display_order
    FROM hunt_links
    WHERE hunt_id = ?
    ORDER BY display_order ASC
  `).all(huntId);

  // Get updates
  const updates = db.prepare(`
    SELECT id, title, content, created_at
    FROM hunt_updates
    WHERE hunt_id = ?
    ORDER BY created_at DESC
  `).all(huntId);

  res.json({
    id: hunt.id,
    slug: hunt.slug,
    title: hunt.title,
    subtitle: hunt.subtitle,
    description: hunt.description,
    status: hunt.status,
    featured: !!hunt.featured,
    prizeValueUsd: hunt.prize_value,
    prizeDescription: hunt.prize_description,
    locationHint: hunt.location_hint,
    searchRegion: hunt.search_region,
    difficulty: hunt.difficulty,
    huntType: hunt.hunt_type || 'field',
    providerName: hunt.provider_name || 'Unknown Provider',
    providerUrl: hunt.provider_url,
    providerLogoUrl: hunt.provider_logo_url,
    announcedAt: hunt.announced_at,
    startsAt: hunt.starts_at,
    foundAt: hunt.found_at,
    endsAt: hunt.ends_at,
    featuredOrder: hunt.featured_order,
    heroImageUrl: hunt.hero_image_url,
    thumbnailUrl: hunt.thumbnail_url,
    createdAt: hunt.created_at,
    updatedAt: hunt.updated_at,
    media: media || [],
    links: links || [],
    updates: updates || [],
  });
});
