-- =============================================
-- Obsession Tracker API - Complete Schema
-- Migrated from obsession-bff to droplet infrastructure
-- =============================================

-- DEVICE REGISTRATION (for Mobile App)
CREATE TABLE IF NOT EXISTS devices (
    id TEXT PRIMARY KEY,
    device_id TEXT UNIQUE NOT NULL,
    api_key TEXT UNIQUE NOT NULL,
    platform TEXT,
    app_version TEXT,
    is_active INTEGER DEFAULT 1,
    environment TEXT DEFAULT 'production',
    fcm_token TEXT,
    fcm_token_updated_at TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    last_seen_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_devices_api_key ON devices(api_key);
CREATE INDEX IF NOT EXISTS idx_devices_device_id ON devices(device_id);
-- Note: idx_devices_fcm_token created in migration logic after column is added

-- SUBSCRIPTIONS (Direct Store Integration)
CREATE TABLE IF NOT EXISTS subscriptions (
    id TEXT PRIMARY KEY,
    device_id TEXT UNIQUE NOT NULL,
    platform TEXT NOT NULL, -- 'ios' or 'android'
    product_id TEXT NOT NULL,
    transaction_id TEXT UNIQUE,
    purchase_date TEXT NOT NULL,
    expiration_date TEXT,
    is_active INTEGER DEFAULT 1,
    auto_renew_status INTEGER DEFAULT 1,
    receipt_data TEXT, -- Encrypted receipt for re-validation
    last_validated_at TEXT DEFAULT (datetime('now')),
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT,
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_device_id ON subscriptions(device_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_transaction_id ON subscriptions(transaction_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_is_active ON subscriptions(is_active);
CREATE INDEX IF NOT EXISTS idx_subscriptions_expiration ON subscriptions(expiration_date);

-- ADMIN USERS & SESSIONS (for Admin Portal)
CREATE TABLE IF NOT EXISTS admin_users (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT DEFAULT 'admin',
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    last_login_at TEXT
);

CREATE TABLE IF NOT EXISTS admin_sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE,
    token_hash TEXT UNIQUE NOT NULL,
    expires_at TEXT NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_admin_sessions_token ON admin_sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_user ON admin_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_expires ON admin_sessions(expires_at);

-- HUNTS (Content Management)
CREATE TABLE IF NOT EXISTS hunts (
    id TEXT PRIMARY KEY,
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    subtitle TEXT,
    description TEXT,
    status TEXT DEFAULT 'upcoming',
    is_draft INTEGER DEFAULT 1,
    featured INTEGER DEFAULT 0,
    featured_order INTEGER,
    prize_value REAL,
    prize_description TEXT,
    location_hint TEXT,
    search_region TEXT,
    difficulty TEXT,
    hunt_type TEXT DEFAULT 'field',
    provider_name TEXT DEFAULT 'Unknown Provider',
    provider_url TEXT,
    provider_logo_url TEXT,
    hero_image_url TEXT,
    thumbnail_url TEXT,
    announced_at TEXT,
    starts_at TEXT,
    found_at TEXT,
    ends_at TEXT,
    created_by TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_hunts_slug ON hunts(slug);
CREATE INDEX IF NOT EXISTS idx_hunts_status ON hunts(status);
CREATE INDEX IF NOT EXISTS idx_hunts_is_draft ON hunts(is_draft);

CREATE TABLE IF NOT EXISTS hunt_media (
    id TEXT PRIMARY KEY,
    hunt_id TEXT NOT NULL REFERENCES hunts(id) ON DELETE CASCADE,
    media_type TEXT,
    url TEXT NOT NULL,
    caption TEXT,
    display_order INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_hunt_media_hunt ON hunt_media(hunt_id);

CREATE TABLE IF NOT EXISTS hunt_links (
    id TEXT PRIMARY KEY,
    hunt_id TEXT NOT NULL REFERENCES hunts(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    url TEXT NOT NULL,
    link_type TEXT,
    display_order INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_hunt_links_hunt ON hunt_links(hunt_id);

CREATE TABLE IF NOT EXISTS hunt_updates (
    id TEXT PRIMARY KEY,
    hunt_id TEXT NOT NULL REFERENCES hunts(id) ON DELETE CASCADE,
    title TEXT,
    content TEXT NOT NULL,
    created_by TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_hunt_updates_hunt ON hunt_updates(hunt_id);

-- ANNOUNCEMENTS
CREATE TABLE IF NOT EXISTS announcements (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    body TEXT,
    announcement_type TEXT DEFAULT 'info',
    priority TEXT DEFAULT 'normal',
    platforms TEXT, -- JSON array: ["ios", "android"]
    min_app_version TEXT,
    published_at TEXT,
    expires_at TEXT,
    is_active INTEGER DEFAULT 1,
    push_sent_at TEXT,
    push_sent_count INTEGER DEFAULT 0,
    created_by TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_announcements_active ON announcements(is_active, published_at, expires_at);
