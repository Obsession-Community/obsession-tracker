import { Router, Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { getDb } from '../../db';
import { adminAuth } from '../../middleware/adminAuth';
import { verifyPassword, generateToken, hashToken, hashPassword } from '../../utils/crypto';

export const adminAuthRouter = Router();

// Session duration: 24 hours
const SESSION_DURATION_MS = 24 * 60 * 60 * 1000;

/**
 * POST /admin/auth/login
 * Authenticate admin user and create session.
 */
adminAuthRouter.post('/login', (req: Request, res: Response) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      res.status(400).json({ error: 'Username and password are required' });
      return;
    }

    const db = getDb();

    // Find user
    const user = db.prepare(`
      SELECT id, username, password_hash, role, failed_login_attempts, locked_until
      FROM admin_users
      WHERE username = ?
    `).get(username) as {
      id: string;
      username: string;
      password_hash: string;
      role: string;
      failed_login_attempts: number;
      locked_until: string | null;
    } | undefined;

    if (!user) {
      // Don't reveal whether user exists
      res.status(401).json({ error: 'Invalid credentials' });
      return;
    }

    // Check if account is locked
    if (user.locked_until && new Date(user.locked_until) > new Date()) {
      res.status(423).json({ error: 'Account temporarily locked. Try again later.' });
      return;
    }

    // Verify password
    const valid = verifyPassword(password, user.password_hash);

    if (!valid) {
      // Increment failed attempts
      const newAttempts = user.failed_login_attempts + 1;
      let lockUntil: string | null = null;

      // Lock account after 5 failed attempts for 15 minutes
      if (newAttempts >= 5) {
        lockUntil = new Date(Date.now() + 15 * 60 * 1000).toISOString();
      }

      db.prepare(`
        UPDATE admin_users
        SET failed_login_attempts = ?, locked_until = ?
        WHERE id = ?
      `).run(newAttempts, lockUntil, user.id);

      res.status(401).json({ error: 'Invalid credentials' });
      return;
    }

    // Reset failed attempts on successful login
    db.prepare(`
      UPDATE admin_users
      SET failed_login_attempts = 0, locked_until = NULL, last_login_at = datetime('now')
      WHERE id = ?
    `).run(user.id);

    // Create session token
    const token = generateToken();
    const tokenHash = hashToken(token);
    const sessionId = uuidv4();
    const expiresAt = new Date(Date.now() + SESSION_DURATION_MS).toISOString();

    // Get client info for audit
    const ipAddress = req.header('X-Forwarded-For') || req.ip || 'unknown';
    const userAgent = req.header('User-Agent') || 'unknown';

    db.prepare(`
      INSERT INTO admin_sessions (id, user_id, token_hash, expires_at, ip_address, user_agent)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(sessionId, user.id, tokenHash, expiresAt, ipAddress, userAgent);

    res.json({
      token,
      expires_at: expiresAt,
      user: {
        id: user.id,
        username: user.username,
        role: user.role,
      },
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Login failed', details: String(error) });
  }
});

/**
 * POST /admin/auth/logout
 * Invalidate current session.
 */
adminAuthRouter.post('/logout', adminAuth, (req: Request, res: Response) => {
  const sessionId = req.sessionId;
  const db = getDb();

  db.prepare('DELETE FROM admin_sessions WHERE id = ?').run(sessionId);

  res.json({ message: 'Logged out successfully' });
});

/**
 * GET /admin/auth/me
 * Get current authenticated admin user.
 */
adminAuthRouter.get('/me', adminAuth, (req: Request, res: Response) => {
  res.json(req.adminUser);
});

/**
 * POST /admin/auth/change-password
 * Change the current user's password.
 */
adminAuthRouter.post('/change-password', adminAuth, (req: Request, res: Response) => {
  try {
    const adminUser = req.adminUser!;
    const db = getDb();

    const { current_password, new_password } = req.body;

    if (!current_password || !new_password) {
      res.status(400).json({ error: 'Current password and new password are required' });
      return;
    }

    // Validate new password strength
    if (new_password.length < 8) {
      res.status(400).json({ error: 'New password must be at least 8 characters' });
      return;
    }

    // Get current password hash
    const user = db.prepare('SELECT password_hash FROM admin_users WHERE id = ?')
      .get(adminUser.id) as { password_hash: string } | undefined;

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    // Verify current password
    const valid = verifyPassword(current_password, user.password_hash);
    if (!valid) {
      res.status(401).json({ error: 'Current password is incorrect' });
      return;
    }

    // Hash new password and update
    const newHash = hashPassword(new_password);
    db.prepare('UPDATE admin_users SET password_hash = ? WHERE id = ?')
      .run(newHash, adminUser.id);

    // Invalidate all other sessions for this user (security best practice)
    const currentSessionId = req.sessionId;
    db.prepare('DELETE FROM admin_sessions WHERE user_id = ? AND id != ?')
      .run(adminUser.id, currentSessionId);

    res.json({ message: 'Password changed successfully' });
  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({ error: 'Failed to change password' });
  }
});
