import Database from 'better-sqlite3';
import fs from 'fs';
import path from 'path';

const DB_PATH = process.env.DB_PATH || '/app/data/obsession-api.db';

let db: Database.Database | null = null;

/**
 * Check if a column exists in a table
 */
function columnExists(database: Database.Database, table: string, column: string): boolean {
  const result = database.prepare(`PRAGMA table_info(${table})`).all() as { name: string }[];
  return result.some(col => col.name === column);
}

/**
 * Add column if it doesn't exist
 */
function addColumnIfNotExists(database: Database.Database, table: string, column: string, type: string): void {
  if (!columnExists(database, table, column)) {
    console.log(`Adding column ${column} to ${table}`);
    database.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${type}`);
  }
}

/**
 * Run migrations to update existing database schema
 */
function runMigrations(database: Database.Database): void {
  // Migrate devices table
  addColumnIfNotExists(database, 'devices', 'environment', "TEXT DEFAULT 'production'");
  addColumnIfNotExists(database, 'devices', 'fcm_token', 'TEXT');
  addColumnIfNotExists(database, 'devices', 'fcm_token_updated_at', 'TEXT');
}

export function getDb(): Database.Database {
  if (!db) {
    // Ensure data directory exists
    const dir = path.dirname(DB_PATH);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    db = new Database(DB_PATH);
    db.pragma('journal_mode = WAL');

    // Initialize schema (creates tables if they don't exist)
    const schemaPath = path.join(__dirname, 'schema.sql');
    const schema = fs.readFileSync(schemaPath, 'utf-8');

    // Split schema into statements and run them individually
    // This allows CREATE INDEX IF NOT EXISTS to work even if some fail
    const statements = schema.split(';').filter(s => s.trim());
    for (const stmt of statements) {
      try {
        db.exec(stmt);
      } catch (err) {
        // Ignore errors from CREATE INDEX on non-existent columns
        // We'll fix those after migrations
        const errMsg = String(err);
        if (!errMsg.includes('no such column')) {
          throw err;
        }
      }
    }

    // Run migrations to add missing columns
    runMigrations(db);

    // Create indexes that depend on migrated columns
    try {
      db.exec(`CREATE INDEX IF NOT EXISTS idx_devices_fcm_token ON devices(fcm_token) WHERE fcm_token IS NOT NULL`);
    } catch {
      // Index may already exist
    }

    console.log(`Database initialized at ${DB_PATH}`);
  }
  return db;
}

export function closeDb(): void {
  if (db) {
    db.close();
    db = null;
  }
}
