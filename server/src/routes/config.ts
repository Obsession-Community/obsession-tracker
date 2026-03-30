import { Router, Request, Response } from 'express';
import fs from 'fs';
import path from 'path';

export const configRouter = Router();

const CONFIG_DIR = process.env.CONFIG_DIR || '/app/config';

/**
 * GET /config
 * Returns app configuration from local config file.
 * Public endpoint - no auth required.
 * Supports X-Environment: dev header for testing.
 */
configRouter.get('/', (req: Request, res: Response) => {
  const environment = req.header('X-Environment');
  const configFile = environment === 'dev' ? 'config.dev.json' : 'config.json';
  const configPath = path.join(CONFIG_DIR, configFile);

  // Try to read from local config file
  if (fs.existsSync(configPath)) {
    try {
      const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
      res.json(config);
      return;
    } catch (error) {
      console.error('Error reading config file:', error);
    }
  }

  // Return default config if not found
  res.json({
    apiVersion: '1.0.0',
    minAppVersion: {
      ios: '1.0.0',
      android: '1.0.0',
    },
    recommendedAppVersion: {
      ios: '1.0.0',
      android: '1.0.0',
    },
    maintenance: {
      active: false,
      message: null,
      estimatedEnd: null,
    },
    data: {
      currentVersion: 'PAD-US-4.1-GNIS',
      source: 'PAD-US 4.1 + GNIS + OpenCelliD',
      description: 'Land ownership, trails, historical places, and cell coverage',
      versions: {
        land: 'PAD-US-4.1',
        trails: 'OSM-2024.12',
        historical: 'GNIS-2024.2',
        cell: '2026-01',
      },
      splitDownloadsAvailable: true,
    },
    links: {
      discord: 'https://discord.gg/obsessiontracker',
      support: 'mailto:support@obsessiontracker.com',
      privacy: 'https://obsessiontracker.com/privacy',
      terms: 'https://obsessiontracker.com/terms',
      appStoreIos: 'https://apps.apple.com/app/obsession-tracker/id6738952467',
      appStoreAndroid: 'https://play.google.com/store/apps/details?id=com.obsessiontracker.app',
    },
    features: {
      trailGrouping: true,
      cloudSync: false,
      premiumEnabled: true,
    },
    announcements: [],
  });
});
