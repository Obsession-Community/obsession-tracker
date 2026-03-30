import { Router } from 'express';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';
import Database from 'better-sqlite3';

export const downloadsRouter = Router();

const DOWNLOADS_PATH = process.env.DOWNLOADS_PATH || '/app/downloads';

// Cache for quadrangle manifests (stateCode -> { manifest, generatedAt, directoryMtime })
// Manifests are expensive to generate (10+ seconds for large states like CA)
// Cache is invalidated when the maps directory is modified or after 5 minutes
interface ManifestCacheEntry {
  manifest: StateQuadrangleManifest;
  generatedAt: number;
  directoryMtime: number;
}
const manifestCache = new Map<string, ManifestCacheEntry>();
const MANIFEST_CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

// Legacy metadata interface (for backward compatibility)
interface StateMetadata {
  state_code: string;
  land_size: number;
  trails_size: number;
  historical_size: number;
  cell_size: number;
  total_size: number;
}

// New manifest-based layer system
interface LayerManifest {
  id: string;
  name: string;
  description: string;
  file: string;
  size: number;
  type: 'vector' | 'raster';
  format: 'geojson-zip' | 'mbtiles';
  era?: string;  // For historical map layers (e.g., "1850-1890")
  checksum?: string;  // SHA256 checksum for integrity verification
  updatedAt: string;
}

interface StateManifest {
  state: string;
  version: string;
  generatedAt: string;
  layers: LayerManifest[];
}

// Layer definitions with metadata
const LAYER_DEFINITIONS: Record<string, Omit<LayerManifest, 'file' | 'size' | 'checksum' | 'updatedAt'>> = {
  land: {
    id: 'land',
    name: 'Land Ownership',
    description: 'PAD-US land ownership boundaries with activity permissions',
    type: 'vector',
    format: 'geojson-zip',
  },
  trails: {
    id: 'trails',
    name: 'Trails',
    description: 'USFS and OSM trail data',
    type: 'vector',
    format: 'geojson-zip',
  },
  historical_places: {
    id: 'historical_places',
    name: 'Historical Places',
    description: 'GNIS historical points of interest (mines, ghost towns, cemeteries)',
    type: 'vector',
    format: 'geojson-zip',
  },
  maps_survey: {
    id: 'maps_survey',
    name: 'Survey Era Maps',
    description: 'GLO survey plats from the 1870s-1880s showing original land surveys and mining claims',
    type: 'raster',
    format: 'mbtiles',
    era: '1850-1890',
  },
  maps_early_topo: {
    id: 'maps_early_topo',
    name: 'Early Topos',
    description: 'USGS topographic maps from the 1890s-1920s showing mining districts and settlements',
    type: 'raster',
    format: 'mbtiles',
    era: '1890-1920',
  },
  cell_coverage: {
    id: 'cell_coverage',
    name: 'Cell Coverage',
    description: 'Cell tower locations with estimated coverage radius from OpenCelliD (CC-BY-SA 4.0)',
    type: 'vector',
    format: 'geojson-zip',
  },
};

// Map file names to layer IDs
const FILE_TO_LAYER: Record<string, string> = {
  'land.zip': 'land',
  'trails.zip': 'trails',
  'historical.zip': 'historical_places',
  'cell.zip': 'cell_coverage',
  'maps_survey.mbtiles': 'maps_survey',
  'maps_early_topo.mbtiles': 'maps_early_topo',
};

// ============================================================================
// Quadrangle-level manifest system for granular historical map downloads
// ============================================================================

interface QuadrangleBounds {
  west: number;
  south: number;
  east: number;
  north: number;
}

interface QuadrangleManifest {
  id: string;
  name: string;
  file: string;
  size: number;
  bounds: QuadrangleBounds;
  year: number;
  scale?: string;
  checksum?: string;
}

interface HistoricalEra {
  id: string;
  name: string;
  description: string;
  yearRange: string;
  quadrangles: QuadrangleManifest[];
}

interface StateQuadrangleManifest {
  state: string;
  version: string;
  generatedAt: string;
  eras: HistoricalEra[];
}

// Era definitions for consistent metadata
const ERA_DEFINITIONS: Record<string, { name: string; description: string; yearRange: string }> = {
  survey: {
    name: 'Survey Era Maps',
    description: 'GLO survey plats from the 1850s-1890s showing original land surveys and mining claims',
    yearRange: '1850-1890',
  },
  early_topo: {
    name: 'Early Topos',
    description: 'USGS topographic maps from the 1890s-1920s showing mining districts and settlements',
    yearRange: '1890-1920',
  },
};

/**
 * Read bounds from MBTiles metadata table
 */
function readMBTilesBounds(filePath: string): QuadrangleBounds | null {
  try {
    const db = new Database(filePath, { readonly: true });
    const row = db.prepare("SELECT value FROM metadata WHERE name = 'bounds'").get() as { value: string } | undefined;
    db.close();

    if (!row?.value) return null;

    const parts = row.value.split(',').map((s: string) => parseFloat(s.trim()));
    if (parts.length !== 4 || parts.some(isNaN)) return null;

    return {
      west: parts[0],
      south: parts[1],
      east: parts[2],
      north: parts[3],
    };
  } catch (error) {
    console.error(`Error reading MBTiles bounds from ${filePath}:`, error);
    return null;
  }
}

/**
 * Extract year from filename (e.g., 'laramie_1897.mbtiles' -> 1897)
 */
function extractYearFromFilename(filename: string): number {
  const match = filename.match(/_(\d{4})\./);
  return match ? parseInt(match[1], 10) : 0;
}

/**
 * Convert filename to human-readable name (e.g., 'south_pass_1891' -> 'South Pass')
 */
function filenameToDisplayName(filename: string): string {
  // Remove extension and year suffix
  const base = filename
    .replace(/\.mbtiles$/i, '')
    .replace(/_\d{4}$/, '');

  // Convert underscores to spaces and title case
  return base
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
}

/**
 * Get the most recent modification time of a directory (checks subdirectories too)
 */
function getDirectoryMtime(dirPath: string): number {
  try {
    let maxMtime = fs.statSync(dirPath).mtimeMs;

    const entries = fs.readdirSync(dirPath, { withFileTypes: true });
    for (const entry of entries) {
      const entryPath = path.join(dirPath, entry.name);
      if (entry.isDirectory()) {
        const subMtime = getDirectoryMtime(entryPath);
        if (subMtime > maxMtime) maxMtime = subMtime;
      } else {
        const stat = fs.statSync(entryPath);
        if (stat.mtimeMs > maxMtime) maxMtime = stat.mtimeMs;
      }
    }
    return maxMtime;
  } catch {
    return 0;
  }
}

/**
 * Try to load a pre-generated static manifest.json file
 * These are generated by generate-manifest.sh after upload
 *
 * Benefits over dynamic generation:
 * - Instant response (~0ms vs 10+ seconds for large states)
 * - Checksums pre-computed
 * - No database opens on each request
 */
function loadStaticManifest(stateCode: string): StateQuadrangleManifest | null {
  const manifestPath = path.join(DOWNLOADS_PATH, 'states', stateCode, 'maps', 'manifest.json');

  try {
    if (!fs.existsSync(manifestPath)) {
      return null;
    }

    const content = fs.readFileSync(manifestPath, 'utf-8');
    const manifest = JSON.parse(content) as StateQuadrangleManifest;

    // Basic validation
    if (!manifest.state || !manifest.eras || !Array.isArray(manifest.eras)) {
      console.log(`[Static Manifest] Invalid format for ${stateCode}, falling back to dynamic`);
      return null;
    }

    console.log(`[Static Manifest] Loaded ${stateCode}: ${manifest.eras.reduce((sum, e) => sum + e.quadrangles.length, 0)} quads`);
    return manifest;
  } catch (error) {
    console.error(`[Static Manifest] Error loading ${stateCode}:`, error);
    return null;
  }
}

/**
 * Generate quadrangle manifest for a state by scanning maps/ directory
 * Uses caching to avoid expensive regeneration on every request
 *
 * PRIORITY ORDER:
 * 1. Static manifest.json (instant, pre-generated)
 * 2. In-memory cache (fast, regenerated periodically)
 * 3. Dynamic generation (slow, 10+ seconds for large states)
 */
function generateQuadrangleManifest(stateCode: string): StateQuadrangleManifest | null {
  // FIRST: Try static manifest.json file (instant)
  const staticManifest = loadStaticManifest(stateCode);
  if (staticManifest) {
    return staticManifest;
  }

  const mapsPath = path.join(DOWNLOADS_PATH, 'states', stateCode, 'maps');

  if (!fs.existsSync(mapsPath)) {
    return null;
  }

  // SECOND: Check in-memory cache
  const cached = manifestCache.get(stateCode);
  const now = Date.now();
  const currentMtime = getDirectoryMtime(mapsPath);

  if (cached) {
    const age = now - cached.generatedAt;
    const mtimeChanged = currentMtime > cached.directoryMtime;

    if (age < MANIFEST_CACHE_TTL_MS && !mtimeChanged) {
      console.log(`[Manifest Cache] HIT for ${stateCode} (age: ${Math.round(age / 1000)}s)`);
      return cached.manifest;
    } else {
      console.log(`[Manifest Cache] STALE for ${stateCode} (age: ${Math.round(age / 1000)}s, mtimeChanged: ${mtimeChanged})`);
    }
  }

  // THIRD: Fall back to dynamic generation (slow)
  console.log(`[Manifest] Dynamic generation for ${stateCode} (no static manifest found)...`);
  const startTime = Date.now();

  const eras: HistoricalEra[] = [];

  // Scan each era directory
  for (const [eraId, eraDef] of Object.entries(ERA_DEFINITIONS)) {
    const quadsPath = path.join(mapsPath, eraId, 'quads');

    if (!fs.existsSync(quadsPath)) continue;

    const quadrangles: QuadrangleManifest[] = [];

    // Scan for MBTiles files
    const quadFiles = fs.readdirSync(quadsPath)
      .filter(f => f.endsWith('.mbtiles'));

    for (const quadFile of quadFiles) {
      const quadPath = path.join(quadsPath, quadFile);
      const stats = fs.statSync(quadPath);
      const bounds = readMBTilesBounds(quadPath);
      const year = extractYearFromFilename(quadFile);
      const id = quadFile.replace('.mbtiles', '');
      const name = filenameToDisplayName(quadFile);

      if (bounds) {
        quadrangles.push({
          id,
          name,
          file: `maps/${eraId}/quads/${quadFile}`,
          size: stats.size,
          bounds,
          year,
          // Only calculate checksum for smaller files
          checksum: stats.size < 50 * 1024 * 1024 ? calculateChecksum(quadPath) : undefined,
        });
      }
    }

    if (quadrangles.length > 0) {
      // Sort quadrangles by name
      quadrangles.sort((a, b) => a.name.localeCompare(b.name));

      eras.push({
        id: eraId,
        ...eraDef,
        quadrangles,
      });
    }
  }

  if (eras.length === 0) {
    return null;
  }

  const manifest: StateQuadrangleManifest = {
    state: stateCode,
    version: '2026.01',
    generatedAt: new Date().toISOString(),
    eras,
  };

  // Cache the result
  manifestCache.set(stateCode, {
    manifest,
    generatedAt: now,
    directoryMtime: currentMtime,
  });

  const elapsed = Date.now() - startTime;
  console.log(`[Manifest Cache] Generated ${stateCode} in ${elapsed}ms (${manifest.eras.reduce((sum, e) => sum + e.quadrangles.length, 0)} quads)`);

  return manifest;
}

/**
 * Calculate SHA256 checksum of a file
 */
function calculateChecksum(filePath: string): string | undefined {
  try {
    const fileBuffer = fs.readFileSync(filePath);
    const hashSum = crypto.createHash('sha256');
    hashSum.update(fileBuffer);
    return `sha256:${hashSum.digest('hex')}`;
  } catch {
    return undefined;
  }
}

/**
 * Get file stats (size and modification time)
 */
function getFileInfo(filePath: string): { size: number; updatedAt: string } | null {
  try {
    const stats = fs.statSync(filePath);
    return {
      size: stats.size,
      updatedAt: stats.mtime.toISOString(),
    };
  } catch {
    return null;
  }
}

/**
 * Generate manifest for a specific state
 */
function generateStateManifest(stateCode: string): StateManifest | null {
  const statePath = path.join(DOWNLOADS_PATH, 'states', stateCode);

  if (!fs.existsSync(statePath)) {
    return null;
  }

  const layers: LayerManifest[] = [];

  // Scan for all known file types
  for (const [fileName, layerId] of Object.entries(FILE_TO_LAYER)) {
    const filePath = path.join(statePath, fileName);
    const fileInfo = getFileInfo(filePath);

    if (fileInfo && fileInfo.size > 0) {
      const layerDef = LAYER_DEFINITIONS[layerId];
      if (layerDef) {
        layers.push({
          ...layerDef,
          file: fileName,
          size: fileInfo.size,
          updatedAt: fileInfo.updatedAt,
          // Note: checksum calculation is expensive, only include if file is small
          // or implement caching for production
          checksum: fileInfo.size < 50 * 1024 * 1024 ? calculateChecksum(filePath) : undefined,
        });
      }
    }
  }

  if (layers.length === 0) {
    return null;
  }

  return {
    state: stateCode,
    version: '2026.01',
    generatedAt: new Date().toISOString(),
    layers,
  };
}

/**
 * GET /api/v1/downloads/metadata
 * Returns metadata about available state downloads including file sizes.
 * Scans the local downloads directory to build the response.
 */
downloadsRouter.get('/metadata', async (req, res) => {
  try {
    const statesPath = path.join(DOWNLOADS_PATH, 'states');

    // Check if states directory exists
    if (!fs.existsSync(statesPath)) {
      return res.json({
        versions: { data: '1.0' },
        states: [],
        split_available: true,
      });
    }

    // Read all state directories
    const stateDirs = fs.readdirSync(statesPath, { withFileTypes: true })
      .filter(dirent => dirent.isDirectory())
      .map(dirent => dirent.name)
      .filter(name => /^[A-Z]{2}$/.test(name)); // Only 2-letter state codes

    const states: StateMetadata[] = [];

    for (const stateCode of stateDirs) {
      const statePath = path.join(statesPath, stateCode);

      const getFileSize = (filename: string): number => {
        const filePath = path.join(statePath, filename);
        try {
          const stats = fs.statSync(filePath);
          return stats.size;
        } catch {
          return 0;
        }
      };

      const landSize = getFileSize('land.zip');
      const trailsSize = getFileSize('trails.zip');
      const historicalSize = getFileSize('historical.zip');
      const cellSize = getFileSize('cell.zip');

      // Only include states that have at least one data file
      if (landSize > 0 || trailsSize > 0 || historicalSize > 0 || cellSize > 0) {
        states.push({
          state_code: stateCode,
          land_size: landSize,
          trails_size: trailsSize,
          historical_size: historicalSize,
          cell_size: cellSize,
          total_size: landSize + trailsSize + historicalSize + cellSize,
        });
      }
    }

    // Sort by state code
    states.sort((a, b) => a.state_code.localeCompare(b.state_code));

    res.json({
      versions: { data: '2.0-GNIS' },
      states,
      split_available: true,
    });
  } catch (error) {
    console.error('Error generating downloads metadata:', error);
    res.status(500).json({ error: 'Failed to generate metadata' });
  }
});

/**
 * GET /api/v1/downloads/states
 * Returns list of available states for download.
 */
downloadsRouter.get('/states', async (req, res) => {
  try {
    const statesPath = path.join(DOWNLOADS_PATH, 'states');

    if (!fs.existsSync(statesPath)) {
      return res.json({ states: [] });
    }

    const stateDirs = fs.readdirSync(statesPath, { withFileTypes: true })
      .filter(dirent => dirent.isDirectory())
      .map(dirent => dirent.name)
      .filter(name => /^[A-Z]{2}$/.test(name))
      .sort();

    res.json({ states: stateDirs });
  } catch (error) {
    console.error('Error listing states:', error);
    res.status(500).json({ error: 'Failed to list states' });
  }
});

/**
 * GET /api/v1/downloads/states/:stateCode/manifest
 * Returns detailed manifest for a specific state including all available layers.
 * This is the new layer-based download system that supports historical map overlays.
 */
downloadsRouter.get('/states/:stateCode/manifest', async (req, res) => {
  try {
    const stateCode = req.params.stateCode.toUpperCase();

    // Validate state code format
    if (!/^[A-Z]{2}$/.test(stateCode)) {
      return res.status(400).json({ error: 'Invalid state code format' });
    }

    const manifest = generateStateManifest(stateCode);

    if (!manifest) {
      return res.status(404).json({ error: 'State not found or has no data' });
    }

    // Cache for 1 hour (manifests change rarely)
    res.setHeader('Cache-Control', 'public, max-age=3600');
    res.json(manifest);
  } catch (error) {
    console.error('Error generating state manifest:', error);
    res.status(500).json({ error: 'Failed to generate manifest' });
  }
});

/**
 * GET /api/v1/downloads/manifests
 * Returns manifests for all available states in a single request.
 * Useful for app startup to fetch all state data at once.
 */
downloadsRouter.get('/manifests', async (req, res) => {
  try {
    const statesPath = path.join(DOWNLOADS_PATH, 'states');

    if (!fs.existsSync(statesPath)) {
      return res.json({
        version: '2026.01',
        generatedAt: new Date().toISOString(),
        states: [],
      });
    }

    const stateDirs = fs.readdirSync(statesPath, { withFileTypes: true })
      .filter(dirent => dirent.isDirectory())
      .map(dirent => dirent.name)
      .filter(name => /^[A-Z]{2}$/.test(name))
      .sort();

    const manifests: StateManifest[] = [];

    for (const stateCode of stateDirs) {
      const manifest = generateStateManifest(stateCode);
      if (manifest) {
        manifests.push(manifest);
      }
    }

    // Cache for 1 hour
    res.setHeader('Cache-Control', 'public, max-age=3600');
    res.json({
      version: '2026.01',
      generatedAt: new Date().toISOString(),
      states: manifests,
    });
  } catch (error) {
    console.error('Error generating all manifests:', error);
    res.status(500).json({ error: 'Failed to generate manifests' });
  }
});

/**
 * GET /api/v1/downloads/states/:stateCode/maps/manifest
 * Returns quadrangle-level manifest for historical maps in a specific state.
 * This enables granular downloads of individual USGS quadrangles.
 *
 * Response structure:
 * {
 *   state: "WY",
 *   version: "2026.01",
 *   generatedAt: "2026-01-23T...",
 *   eras: [
 *     {
 *       id: "early_topo",
 *       name: "Early Topos",
 *       description: "...",
 *       yearRange: "1890-1920",
 *       quadrangles: [
 *         {
 *           id: "laramie_1897",
 *           name: "Laramie",
 *           file: "maps/early_topo/quads/laramie_1897.mbtiles",
 *           size: 5242880,
 *           bounds: { west: -106.0, south: 41.0, east: -105.5, north: 41.5 },
 *           year: 1897
 *         }
 *       ]
 *     }
 *   ]
 * }
 */
downloadsRouter.get('/states/:stateCode/maps/manifest', async (req, res) => {
  try {
    const stateCode = req.params.stateCode.toUpperCase();

    // Validate state code format
    if (!/^[A-Z]{2}$/.test(stateCode)) {
      return res.status(400).json({ error: 'Invalid state code format' });
    }

    const manifest = generateQuadrangleManifest(stateCode);

    if (!manifest) {
      return res.status(404).json({
        error: 'No historical map quadrangles available for this state',
        state: stateCode,
      });
    }

    // Cache for 1 hour
    res.setHeader('Cache-Control', 'public, max-age=3600');
    res.json(manifest);
  } catch (error) {
    console.error('Error generating quadrangle manifest:', error);
    res.status(500).json({ error: 'Failed to generate quadrangle manifest' });
  }
});
