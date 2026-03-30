/**
 * Cryptographic utilities for password hashing and token generation.
 * Uses Node.js crypto module with Web Crypto API compatibility.
 */
import { randomBytes, createHash, pbkdf2Sync } from 'crypto';

/**
 * Hash a password using PBKDF2 with SHA-256.
 * Compatible with the format used by obsession-bff.
 */
export function hashPassword(password: string): string {
  const salt = randomBytes(16);
  const iterations = 100000;

  const hash = pbkdf2Sync(password, salt, iterations, 32, 'sha256');

  // Format: $pbkdf2-sha256$iterations$salt$hash (base64)
  const saltB64 = salt.toString('base64');
  const hashB64 = hash.toString('base64');

  return `$pbkdf2-sha256$${iterations}$${saltB64}$${hashB64}`;
}

/**
 * Verify a password against a stored hash.
 */
export function verifyPassword(password: string, storedHash: string): boolean {
  // Parse the stored hash
  const parts = storedHash.split('$');
  if (parts.length !== 5 || parts[1] !== 'pbkdf2-sha256') {
    return false;
  }

  const iterations = parseInt(parts[2], 10);
  const salt = Buffer.from(parts[3], 'base64');
  const expectedHash = parts[4];

  const hash = pbkdf2Sync(password, salt, iterations, 32, 'sha256');
  const hashB64 = hash.toString('base64');

  return hashB64 === expectedHash;
}

/**
 * Generate a cryptographically secure random token.
 */
export function generateToken(): string {
  return randomBytes(32).toString('hex');
}

/**
 * Hash a token for storage (SHA-256).
 * We store hashed tokens so if DB is compromised, tokens can't be used.
 */
export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

/**
 * Generate a secure API key for device registration.
 */
export function generateApiKey(): string {
  return randomBytes(32).toString('hex');
}
