import express from 'express';
import cors from 'cors';
import { devicesRouter } from './routes/devices';
import { subscriptionRouter } from './routes/subscription';
import { downloadsRouter } from './routes/downloads';
import { announcementsRouter } from './routes/announcements';
import { huntsRouter } from './routes/hunts';
import { configRouter } from './routes/config';
import { adminAuthRouter } from './routes/admin/auth';
import { adminAnnouncementsRouter } from './routes/admin/announcements';
import { adminHuntsRouter } from './routes/admin/hunts';
import { adminUploadsRouter } from './routes/admin/uploads';
import adminPushRouter from './routes/admin/push';
import { getDb, closeDb } from './db';

const app = express();
const PORT = process.env.PORT || 3003;

// CORS for admin portal and mobile app
app.use(cors({
  origin: [
    'https://obsessiontracker.com',
    'https://admin.obsessiontracker.com',
    'https://obsession-admin-portal.pages.dev',
    'http://localhost:3000',
    'http://localhost:4200',
  ],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key', 'X-Environment'],
  exposedHeaders: ['Content-Length', 'Content-Disposition'],
  maxAge: 86400,
  credentials: true,
}));

// Middleware
app.use(express.json());

// Request logging
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`${req.method} ${req.path} ${res.statusCode} ${duration}ms`);
  });
  next();
});

// Health check
app.get('/health', (req, res) => {
  try {
    // Check database connection
    const db = getDb();
    db.prepare('SELECT 1').get();
    res.json({ status: 'healthy', timestamp: new Date().toISOString() });
  } catch (error) {
    res.status(503).json({ status: 'unhealthy', error: String(error) });
  }
});

// Serve uploaded files (static)
const uploadsPath = process.env.UPLOADS_PATH || '/app/uploads';
app.use('/uploads', express.static(uploadsPath, {
  maxAge: '7d',
  immutable: true,
  setHeaders: (res) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Cache-Control', 'public, max-age=604800, immutable');
  }
}));

// Public routes (no auth required)
app.use('/config', configRouter);
app.use('/announcements', announcementsRouter);
app.use('/hunts', huntsRouter);

// Mobile app routes (API key auth)
app.use('/api/v1/devices', devicesRouter);
app.use('/api/v1/subscription', subscriptionRouter);
app.use('/api/v1/downloads', downloadsRouter);

// Admin portal routes (session token auth)
app.use('/admin/auth', adminAuthRouter);
app.use('/admin/announcements', adminAnnouncementsRouter);
app.use('/admin/hunts', adminHuntsRouter);
app.use('/admin/uploads', adminUploadsRouter);
app.use('/admin/push', adminPushRouter);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Error handler
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down...');
  closeDb();
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down...');
  closeDb();
  process.exit(0);
});

// Start server
app.listen(PORT, () => {
  console.log(`obsession-api listening on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);

  // Initialize database on startup
  getDb();
});
