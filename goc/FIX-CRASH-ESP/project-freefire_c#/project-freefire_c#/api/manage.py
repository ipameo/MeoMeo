"""
MeoMeo License Admin CLI
─────────────────────────
Quick admin commands without HTTP.

Usage:
  python manage.py add_key              — Generate a new 30-day key
  python manage.py add_key --days 90    — 90-day key
  python manage.py add_key --key CUSTOM — Custom key string
  python manage.py list_keys            — Show all keys
  python manage.py list_devices         — Show all devices
  python manage.py toggle_system on|off — Toggle global system
  python manage.py toggle_device <id> on|off  — Toggle specific device
  python manage.py revoke_key <key>     — Revoke a key
  python manage.py cleanup              — Remove expired sessions
  python manage.py logs [limit]         — View recent auth logs
"""

import os
import secrets
import sqlite3
import sys
from datetime import datetime

DB_PATH = os.environ.get("MEOMEO_DB", os.path.join(os.path.dirname(__file__), "data.db"))


def get_db():
    db = sqlite3.connect(DB_PATH)
    db.row_factory = sqlite3.Row
    return db


def generate_key():
    parts = [secrets.token_hex(2).upper() for _ in range(4)]
    return "-".join(parts)


def init():
    """Initialize database from schema."""
    db = sqlite3.connect(DB_PATH)
    schema_path = os.path.join(os.path.dirname(__file__), "schema.sql")
    with open(schema_path, "r") as f:
        db.executescript(f.read())
    db.close()
    print(f"[OK] Database initialized: {DB_PATH}")


def add_key(days=30, max_devices=1, custom_key=None):
    key = custom_key if custom_key else generate_key()
    db = get_db()
    try:
        db.execute(
            "INSERT INTO license_keys (license_key, max_devices, duration_days) VALUES (?, ?, ?)",
            (key, max_devices, days),
        )
        db.commit()
        print(f"[OK] Key created: {key} ({days} days, max {max_devices} devices)")
    except sqlite3.IntegrityError:
        print(f"[ERR] Key already exists: {key}")
    db.close()


def list_keys():
    db = get_db()
    rows = db.execute("""
        SELECT lk.*, COUNT(d.id) as used_devices
        FROM license_keys lk
        LEFT JOIN devices d ON lk.id = d.license_key_id
        GROUP BY lk.id
        ORDER BY lk.created_at DESC
    """).fetchall()
    if not rows:
        print("[INFO] No license keys found.")
        return
    print(f"{'KEY':<22} {'DAYS':>5} {'MAX':>4} {'USED':>5} {'ACTIVE':>7} {'CREATED':<20}")
    print("-" * 75)
    for r in rows:
        status = "YES" if r["active"] else "NO"
        print(f"{r['license_key']:<22} {r['duration_days']:>5} {r['max_devices']:>4} {r['used_devices']:>5} {status:>7} {r['created_at']:<20}")
    db.close()


def list_devices():
    db = get_db()
    rows = db.execute("""
        SELECT d.device_id, d.active, d.registered_at, d.expires_at,
               lk.license_key
        FROM devices d
        LEFT JOIN license_keys lk ON d.license_key_id = lk.id
        ORDER BY d.registered_at DESC
    """).fetchall()
    if not rows:
        print("[INFO] No devices registered.")
        return
    print(f"{'DEVICE_ID':<40} {'KEY':<22} {'ACTIVE':>7} {'EXPIRES':<20}")
    print("-" * 95)
    for r in rows:
        status = "YES" if r["active"] else "NO"
        did = r["device_id"][:38] + ".." if len(r["device_id"]) > 40 else r["device_id"]
        print(f"{did:<40} {r['license_key']:<22} {status:>7} {r['expires_at']:<20}")
    db.close()


def toggle_system(state):
    db = get_db()
    val = "1" if state.lower() in ("on", "1", "true") else "0"
    db.execute("UPDATE global_config SET value = ? WHERE key = 'system_active'", (val,))
    if val == "0":
        db.execute("DELETE FROM sessions")
    db.commit()
    print(f"[OK] System {'ON' if val == '1' else 'OFF'}")
    db.close()


def toggle_device(device_id, state):
    db = get_db()
    val = 1 if state.lower() in ("on", "1", "true") else 0
    db.execute("UPDATE devices SET active = ? WHERE device_id = ?", (val, device_id))
    if not val:
        db.execute("DELETE FROM sessions WHERE device_id = ?", (device_id,))
    db.commit()
    print(f"[OK] Device {device_id[:20]}.. → {'ON' if val else 'OFF'}")
    db.close()


def revoke_key(key):
    db = get_db()
    lk = db.execute("SELECT id FROM license_keys WHERE license_key = ?", (key,)).fetchone()
    if lk is None:
        print(f"[ERR] Key not found: {key}")
        db.close()
        return
    db.execute("UPDATE license_keys SET active = 0 WHERE id = ?", (lk["id"],))
    db.execute("UPDATE devices SET active = 0 WHERE license_key_id = ?", (lk["id"],))
    devices = db.execute("SELECT device_id FROM devices WHERE license_key_id = ?", (lk["id"],)).fetchall()
    for d in devices:
        db.execute("DELETE FROM sessions WHERE device_id = ?", (d["device_id"],))
    db.commit()
    print(f"[OK] Revoked key: {key} ({len(devices)} devices affected)")
    db.close()


def cleanup():
    db = get_db()
    now = datetime.utcnow().isoformat()
    result = db.execute("DELETE FROM sessions WHERE expires_at < ?", (now,))
    db.commit()
    print(f"[OK] Cleaned up {result.rowcount} expired sessions")
    db.close()


def show_logs(limit=50):
    db = get_db()
    rows = db.execute(
        "SELECT * FROM auth_log ORDER BY created_at DESC LIMIT ?", (limit,)
    ).fetchall()
    if not rows:
        print("[INFO] No logs found.")
        return
    print(f"{'TIME':<22} {'DEVICE':<20} {'ACTION':<10} {'RESULT':<15} {'IP':<15}")
    print("-" * 85)
    for r in rows:
        did = r["device_id"][:18] + ".." if len(r["device_id"]) > 20 else r["device_id"]
        print(f"{r['created_at']:<22} {did:<20} {r['action']:<10} {r['result']:<15} {r['ip_address']:<15}")
    db.close()


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(0)

    cmd = args[0]

    if cmd == "init":
        init()
    elif cmd == "add_key":
        days = 30
        max_dev = 1
        ckey = None
        i = 1
        while i < len(args):
            if args[i] == "--days" and i + 1 < len(args):
                days = int(args[i + 1]); i += 2
            elif args[i] == "--max" and i + 1 < len(args):
                max_dev = int(args[i + 1]); i += 2
            elif args[i] == "--key" and i + 1 < len(args):
                ckey = args[i + 1]; i += 2
            else:
                i += 1
        add_key(days, max_dev, ckey)
    elif cmd == "list_keys":
        list_keys()
    elif cmd == "list_devices":
        list_devices()
    elif cmd == "toggle_system" and len(args) > 1:
        toggle_system(args[1])
    elif cmd == "toggle_device" and len(args) > 2:
        toggle_device(args[1], args[2])
    elif cmd == "revoke_key" and len(args) > 1:
        revoke_key(args[1])
    elif cmd == "cleanup":
        cleanup()
    elif cmd == "logs":
        limit = int(args[1]) if len(args) > 1 else 50
        show_logs(limit)
    else:
        print(f"Unknown command: {cmd}")
        print(__doc__)
