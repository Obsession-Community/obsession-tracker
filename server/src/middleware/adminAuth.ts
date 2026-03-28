import { Request, Response, NextFunction } from 'express';
import { getDb } from '../db';
import { hashToken } from '../utils/crypto';

// Extend Express Request to include admin user info
declare global {
  namespace Express {
    interface Request {
      adminUser?: {
        id: string;
        username: string;
        role: string;
      };
      sessionId?: string;
    }
  }
}

/**
 * Middleware to validate admin session tokens.
 * Token is passed in Authorization header as "Bearer <token>"
 */
export function adminAuth(req: Request, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing or invalid authorization header' });
    return;
  }

  const token = authHeader.substring(7); // Remove "Bearer " prefix
  const tokenHash = hashToken(token);

  const db = getDb();

  const session = db.prepare(`
    SELECT s.id, s.user_id, s.expires_at, u.username, u.role
    FROM admin_sessions s
    JOIN admin_users u ON s.user_id = u.id
    WHERE s.token_hash = ?
  `).get(tokenHash) as {
    id: string;
    user_id: string;
    expires_at: string;
    username: string;
    role: string;
  } | undefined;

  if (!session) {
    res.status(401).json({ error: 'Invalid session' });
    return;
  }

  // Check if session expired
  if (new Date(session.expires_at) < new Date()) {
    // Clean up expired session
    db.prepare('DELETE FROM admin_sessions WHERE id = ?').run(session.id);
    res.status(401).json({ error: 'Session expired' });
    return;
  }

  // Store admin user info in request
  req.adminUser = {
    id: session.user_id,
    username: session.username,
    role: session.role,
  };
  req.sessionId = session.id;

  next();
}
