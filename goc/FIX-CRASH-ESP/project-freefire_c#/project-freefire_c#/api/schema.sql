-- ============================================
-- MeoMeo License System — Database Schema
-- SQLite3
-- ============================================

-- License keys issued by admin
CREATE TABLE IF NOT EXISTS license_keys (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    license_key     TEXT    UNIQUE NOT NULL,
    max_devices     INTEGER DEFAULT 1,
    duration_days   INTEGER DEFAULT 30,
    active          INTEGER DEFAULT 1,
    created_at      TEXT    DEFAULT (datetime('now'))
);

-- Devices bound to a license
CREATE TABLE IF NOT EXISTS devices (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id       TEXT    UNIQUE NOT NULL,
    license_key_id  INTEGER NOT NULL,
    hwid            TEXT    DEFAULT '',
    active          INTEGER DEFAULT 1,
    registered_at   TEXT    DEFAULT (datetime('now')),
    expires_at      TEXT    NOT NULL,
    FOREIGN KEY (license_key_id) REFERENCES license_keys(id)
);

-- Active sessions (rotating tokens)
CREATE TABLE IF NOT EXISTS sessions (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id       TEXT    NOT NULL,
    session_token   TEXT    NOT NULL,
    meomeo          TEXT    NOT NULL,
    sig             TEXT    NOT NULL,
    created_at      TEXT    DEFAULT (datetime('now')),
    expires_at      TEXT    NOT NULL
);

-- Global system config
CREATE TABLE IF NOT EXISTS global_config (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- System ON by default
INSERT OR IGNORE INTO global_config (key, value) VALUES ('system_active', '1');

-- Auth log for audit trail
CREATE TABLE IF NOT EXISTS auth_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id   TEXT NOT NULL,
    action      TEXT NOT NULL,
    result      TEXT NOT NULL,
    ip_address  TEXT DEFAULT '',
    created_at  TEXT DEFAULT (datetime('now'))
);
