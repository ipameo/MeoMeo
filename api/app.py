"""
MeoMeo License API Server
─────────────────────────
Anti-crack licensing system for ESP patch.

Endpoints:
  POST /api/auth        — Authenticate device, get session token + meomeo
  POST /api/verify      — Verify session is still valid
  POST /api/heartbeat   — Periodic heartbeat from app while injected
  GET  /api/status      — Check system on/off + device status
  POST /api/admin/toggle      — Toggle system or per-device on/off
  POST /api/admin/add_key     — Generate new license key
  POST /api/admin/revoke_key  — Revoke a license key
  GET  /api/admin/users       — List all devices/sessions
  GET  /api/admin/keys        — List all license keys
  GET  /api/admin/logs        — View auth logs

Run:
  python app.py                    # dev mode (port 2007)
  gunicorn app:app -b 0.0.0.0:2007 # production
"""

import hashlib
import hmac
import json
import os
import secrets
import sqlite3
import time
from datetime import datetime, timedelta
from functools import wraps

from flask import Flask, g, jsonify, render_template, request

# ─── Config ───────────────────────────────────────────────────────────────────
APP_SECRET = os.environ.get("MEOMEO_SECRET", "xtr_s3cret_k3y_2024_meomeo")
ADMIN_PASSWORD = os.environ.get("MEOMEO_ADMIN_PASS", "admin_meomeo_2024")
SESSION_TTL_MINUTES = 30  # Session token lifespan
HEARTBEAT_GRACE_MINUTES = 10  # Extra grace after last heartbeat
DB_PATH = os.environ.get("MEOMEO_DB", os.path.join(os.path.dirname(__file__), "data.db"))

app = Flask(__name__, template_folder=os.path.join(os.path.dirname(__file__), "templates"))


# ─── Database ─────────────────────────────────────────────────────────────────
def get_db():
    if "db" not in g:
        g.db = sqlite3.connect(DB_PATH)
        g.db.row_factory = sqlite3.Row
        g.db.execute("PRAGMA journal_mode=WAL")
        g.db.execute("PRAGMA foreign_keys=ON")
    return g.db


@app.teardown_appcontext
def close_db(exc):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db():
    """Initialize database from schema.sql"""
    db = sqlite3.connect(DB_PATH)
    schema_path = os.path.join(os.path.dirname(__file__), "schema.sql")
    with open(schema_path, "r") as f:
        db.executescript(f.read())
    db.close()


# ─── Global Settings & Server Feature Controls ────────────────────────────────
def get_global_setting(key: str, default: str = "") -> str:
    db = get_db()
    row = db.execute("SELECT value FROM global_config WHERE key = ?", (key,)).fetchone()
    return row["value"] if row else default


def set_global_setting(key: str, value: str):
    db = get_db()
    db.execute("INSERT OR REPLACE INTO global_config (key, value) VALUES (?, ?)", (key, value))
    db.commit()


def get_server_features() -> dict:
    default_features = {
        "server_esp": True,
        "server_box": True,
        "server_line": True,
        "server_name": True,
        "server_distance": True,
        "server_health": True,
        "server_skeleton": True,
        "server_aim": True,
        "server_headshot": True,
    }
    raw = get_global_setting("server_features", "")
    if not raw:
        return default_features
    try:
        loaded = json.loads(raw)
        default_features.update(loaded)
        return default_features
    except Exception:
        return default_features


# ─── Crypto helpers ───────────────────────────────────────────────────────────
import struct

TOKEN_SECRET_KEY = bytes([0x58, 0x75, 0x61, 0x6E, 0x54, 0x72, 0x75, 0x6E, 0x5F, 0x56, 0x69, 0x70, 0x32, 0x30, 0x32, 0x36]) # XuanTrun_Vip2026

def fnv1a_32(data: bytes, key: bytes) -> int:
    h = 0x811c9dc5
    for b in data:
        h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF
    for b in key:
        h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF
    return h

def generate_encrypted_token(ts: int, status: int, features_mask: int, nonce: int = None) -> str:
    if nonce is None:
        nonce = secrets.randbits(32)
    feat_low = features_mask & 0xFF
    feat_high = (features_mask >> 8) & 0xFF
    payload = struct.pack("<IBBBBI", ts & 0xFFFFFFFF, status & 0xFF, feat_low, feat_high, 0x7E, nonce & 0xFFFFFFFF)
    checksum = fnv1a_32(payload, TOKEN_SECRET_KEY)
    block = bytearray(payload + struct.pack("<I", checksum))
    for r in range(4):
        for i in range(16):
            k = TOKEN_SECRET_KEY[(i + r * 3) % 16]
            block[i] = ((block[i] ^ k) + (i * 7 + r * 13)) & 0xFF
            block[i] = ((block[i] << 3) | (block[i] >> 5)) & 0xFF
    return block.hex()

def features_dict_to_mask(features: dict) -> int:
    mask = 0
    if features.get("server_esp", True): mask |= (1 << 0)
    if features.get("server_box", True): mask |= (1 << 1)
    if features.get("server_line", True): mask |= (1 << 2)
    if features.get("server_name", True): mask |= (1 << 3)
    if features.get("server_distance", True): mask |= (1 << 4)
    if features.get("server_health", True): mask |= (1 << 5)
    if features.get("server_skeleton", True): mask |= (1 << 6)
    if features.get("server_aim", True): mask |= (1 << 7)
    if features.get("server_aim", True): mask |= (1 << 8)
    if features.get("server_headshot", True): mask |= (1 << 9)
    mask |= (1 << 10)
    return mask

def generate_meomeo(device_id: str, session_token: str, timestamp: int) -> str:
    """Generate a meomeo hash bound to device + session + time window."""
    raw = f"{device_id}:{session_token}:{timestamp}:{APP_SECRET}"
    return hashlib.md5(raw.encode()).hexdigest()


def generate_sig(meomeo: str, ts: int, device_id: str) -> str:
    """
    Generate a signature for the config file.
    This sig is verified by the C# patch to ensure the config wasn't forged.
    """
    raw = f"{meomeo}|{ts}|{device_id}|{APP_SECRET}"
    return hashlib.md5(raw.encode()).hexdigest()


def generate_license_key() -> str:
    """Generate a random license key: XXXX-XXXX-XXXX-XXXX"""
    parts = [secrets.token_hex(2).upper() for _ in range(4)]
    return "-".join(parts)


# ─── Admin auth decorator ────────────────────────────────────────────────────
def require_admin(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        data = request.get_json(silent=True) or {}
        password = data.get("password") or request.args.get("password", "")
        if password != ADMIN_PASSWORD:
            return jsonify({"error": "unauthorized"}), 403
        return f(*args, **kwargs)
    return decorated


# ─── Logging helper ──────────────────────────────────────────────────────────
def log_auth(device_id: str, action: str, result: str):
    db = get_db()
    ip = request.remote_addr or ""
    db.execute(
        "INSERT INTO auth_log (device_id, action, result, ip_address) VALUES (?, ?, ?, ?)",
        (device_id, action, result, ip),
    )
    db.commit()


# ─── System status check ─────────────────────────────────────────────────────
def is_system_active() -> bool:
    val = get_global_setting("system_active", "1")
    return val == "1"


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC ENDPOINTS
# ═══════════════════════════════════════════════════════════════════════════════


@app.route("/api/auth", methods=["POST"])
def auth():
    """
    Authenticate a device with a license key.
    Returns a session token + meomeo + sig for localConfig.json.

    Body: { "device_id": "...", "key": "XXXX-XXXX-XXXX-XXXX" }
    """
    data = request.get_json(silent=True) or {}
    device_id = (data.get("device_id") or "").strip()
    key = (data.get("key") or "").strip()

    if not device_id or not key:
        return jsonify({"error": "missing device_id or key"}), 400

    if not is_system_active():
        log_auth(device_id, "auth", "system_off")
        return jsonify({"error": "system_offline", "active": False}), 503

    db = get_db()

    # Find license key
    lk = db.execute(
        "SELECT * FROM license_keys WHERE license_key = ? AND active = 1", (key,)
    ).fetchone()

    if lk is None:
        log_auth(device_id, "auth", "invalid_key")
        return jsonify({"error": "invalid_key"}), 401

    # Check if device already registered
    device = db.execute(
        "SELECT * FROM devices WHERE device_id = ?", (device_id,)
    ).fetchone()

    now = datetime.utcnow()

    if device is None:
        # Check max devices for this license
        device_count = db.execute(
            "SELECT COUNT(*) as cnt FROM devices WHERE license_key_id = ?",
            (lk["id"],),
        ).fetchone()["cnt"]

        if device_count >= lk["max_devices"]:
            log_auth(device_id, "auth", "max_devices")
            return jsonify({"error": "max_devices_reached"}), 403

        # Register new device
        expires_at = now + timedelta(days=lk["duration_days"])
        db.execute(
            "INSERT INTO devices (device_id, license_key_id, expires_at) VALUES (?, ?, ?)",
            (device_id, lk["id"], expires_at.isoformat()),
        )
        db.commit()
        device = db.execute(
            "SELECT * FROM devices WHERE device_id = ?", (device_id,)
        ).fetchone()
    else:
        # Check if device license matches
        if device["license_key_id"] != lk["id"]:
            log_auth(device_id, "auth", "wrong_key_for_device")
            return jsonify({"error": "device_bound_to_different_key"}), 403

        # Check device active
        if not device["active"]:
            log_auth(device_id, "auth", "device_disabled")
            return jsonify({"error": "device_disabled"}), 403

        # Check expiry
        expires_at = datetime.fromisoformat(device["expires_at"])
        if now > expires_at:
            log_auth(device_id, "auth", "expired")
            return jsonify({"error": "license_expired", "expires_at": device["expires_at"]}), 403

    # Create session
    session_token = secrets.token_hex(16)
    current_time_epoch = int(time.time())
    ts = current_time_epoch + (SESSION_TTL_MINUTES * 60)
    meomeo = generate_meomeo(device_id, session_token, ts)
    sig = generate_sig(meomeo, ts, device_id)
    session_expires = (now + timedelta(minutes=SESSION_TTL_MINUTES)).isoformat()

    # Clean old sessions for this device
    db.execute("DELETE FROM sessions WHERE device_id = ?", (device_id,))
    db.execute(
        "INSERT INTO sessions (device_id, session_token, meomeo, sig, expires_at) VALUES (?, ?, ?, ?, ?)",
        (device_id, session_token, meomeo, sig, session_expires),
    )
    db.commit()

    log_auth(device_id, "auth", "ok")

    feat_mask = features_dict_to_mask(get_server_features())
    token = generate_encrypted_token(ts, 1 if is_system_active() else 0, feat_mask)

    return jsonify({
        "status": "active",
        "meomeo": meomeo,
        "sig": sig,
        "ts": ts,
        "token": token,
        "session_token": session_token,
        "expires_at": session_expires,
        "device_expires": device["expires_at"],
        "system_active": True,
        "features": get_server_features(),
    })


@app.route("/api/verify", methods=["POST"])
def verify():
    """
    Verify a session is still valid.
    Called periodically by the Swift app to refresh token.

    Body: { "device_id": "...", "session_token": "...", "meomeo": "..." }
    """
    data = request.get_json(silent=True) or {}
    device_id = (data.get("device_id") or "").strip()
    session_token = (data.get("session_token") or "").strip()
    meomeo = (data.get("meomeo") or "").strip()

    if not device_id or not session_token:
        return jsonify({"valid": False, "error": "missing_params"}), 400

    if not is_system_active():
        return jsonify({"valid": False, "error": "system_offline"}), 503

    db = get_db()

    # Check device
    device = db.execute(
        "SELECT * FROM devices WHERE device_id = ? AND active = 1", (device_id,)
    ).fetchone()
    if device is None:
        return jsonify({"valid": False, "error": "device_not_found"})

    # Check device expiry
    if datetime.utcnow() > datetime.fromisoformat(device["expires_at"]):
        return jsonify({"valid": False, "error": "license_expired"})

    # Check session
    session = db.execute(
        "SELECT * FROM sessions WHERE device_id = ? AND session_token = ?",
        (device_id, session_token),
    ).fetchone()

    if session is None:
        return jsonify({"valid": False, "error": "invalid_session"})

    if datetime.utcnow() > datetime.fromisoformat(session["expires_at"]):
        # Session expired — generate new one
        now = datetime.utcnow()
        new_token = secrets.token_hex(16)
        ts = int(time.time()) + (SESSION_TTL_MINUTES * 60)
        new_meomeo = generate_meomeo(device_id, new_token, ts)
        new_sig = generate_sig(new_meomeo, ts, device_id)
        new_expires = (now + timedelta(minutes=SESSION_TTL_MINUTES)).isoformat()

        feat_mask = features_dict_to_mask(get_server_features())
        enc_token = generate_encrypted_token(ts, 1 if is_system_active() else 0, feat_mask)

        db.execute("DELETE FROM sessions WHERE device_id = ?", (device_id,))
        db.execute(
            "INSERT INTO sessions (device_id, session_token, meomeo, sig, expires_at) VALUES (?, ?, ?, ?, ?)",
            (device_id, new_token, new_meomeo, new_sig, new_expires),
        )
        db.commit()

        return jsonify({
            "valid": True,
            "renewed": True,
            "meomeo": new_meomeo,
            "sig": new_sig,
            "ts": ts,
            "token": enc_token,
            "session_token": new_token,
        })

    return jsonify({"valid": True, "renewed": False})


@app.route("/api/heartbeat", methods=["POST"])
def heartbeat():
    """
    Heartbeat from the Swift app while game is injected.
    Extends session TTL and returns live feature permissions.

    Body: { "device_id": "...", "session_token": "..." }
    """
    data = request.get_json(silent=True) or {}
    device_id = (data.get("device_id") or "").strip()
    session_token = (data.get("session_token") or "").strip()

    features = get_server_features()
    system_on = is_system_active()

    if not device_id or not session_token:
        return jsonify({"ok": False, "system_active": system_on, "features": features}), 400

    now = datetime.utcnow()
    current_time_epoch = int(time.time())
    ts = current_time_epoch + (SESSION_TTL_MINUTES * 60)

    if not system_on:
        log_auth(device_id, "heartbeat", "system_offline")
        token = generate_encrypted_token(current_time_epoch, 0, 0)
        return jsonify({
            "ok": False,
            "active": False,
            "system_active": False,
            "features": features,
            "token": token,
            "error": "system_offline"
        }), 200

    db = get_db()
    # Check if device is active
    device = db.execute("SELECT active, expires_at FROM devices WHERE device_id = ?", (device_id,)).fetchone()
    if device is None or not device["active"]:
        token = generate_encrypted_token(current_time_epoch, 0, 0)
        return jsonify({
            "ok": False,
            "active": False,
            "system_active": False,
            "features": features,
            "token": token,
            "error": "device_disabled"
        }), 200

    new_expires = (now + timedelta(minutes=SESSION_TTL_MINUTES)).isoformat()
    new_meomeo = generate_meomeo(device_id, session_token, ts)
    new_sig = generate_sig(new_meomeo, ts, device_id)

    feat_mask = features_dict_to_mask(features)
    token = generate_encrypted_token(ts, 1, feat_mask)

    db.execute(
        "UPDATE sessions SET meomeo = ?, sig = ?, expires_at = ? WHERE device_id = ? AND session_token = ?",
        (new_meomeo, new_sig, new_expires, device_id, session_token),
    )
    db.commit()

    log_auth(device_id, "heartbeat", "ok")

    return jsonify({
        "ok": True,
        "active": True,
        "system_active": True,
        "features": features,
        "meomeo": new_meomeo,
        "sig": new_sig,
        "ts": ts,
        "token": token,
    })


@app.route("/api/status", methods=["GET"])
def status():
    """
    Check system status and optionally device status.

    Query: ?device_id=...&meomeo=...
    """
    device_id = request.args.get("device_id", "").strip()
    meomeo_param = request.args.get("meomeo", "").strip()

    system_on = is_system_active()
    features = get_server_features()
    result = {"system_active": system_on, "features": features}

    if not system_on:
        result["ok"] = False
        return jsonify(result)

    if device_id:
        db = get_db()
        device = db.execute(
            "SELECT * FROM devices WHERE device_id = ? AND active = 1", (device_id,)
        ).fetchone()

        if device is None:
            result["ok"] = False
            result["error"] = "device_not_found"
        elif datetime.utcnow() > datetime.fromisoformat(device["expires_at"]):
            result["ok"] = False
            result["error"] = "expired"
        else:
            # Check if meomeo matches current session
            if meomeo_param:
                session = db.execute(
                    "SELECT * FROM sessions WHERE device_id = ? AND meomeo = ?",
                    (device_id, meomeo_param),
                ).fetchone()
                result["ok"] = session is not None
            else:
                result["ok"] = True
    else:
        result["ok"] = system_on

    feat_mask = features_dict_to_mask(features)
    status_bit = 1 if (system_on and result.get("ok", False)) else 0
    now_ts = int(time.time()) + (SESSION_TTL_MINUTES * 60)
    result["token"] = generate_encrypted_token(now_ts, status_bit, feat_mask)
    result["ts"] = now_ts

    return jsonify(result)


# ═══════════════════════════════════════════════════════════════════════════════
# ADMIN ENDPOINTS
# ═══════════════════════════════════════════════════════════════════════════════


@app.route("/api/admin/toggle", methods=["POST"])
@require_admin
def admin_toggle():
    """
    Toggle system on/off globally, or per-device.

    Body: { "password": "...", "active": true/false, "device_id": "..." (optional) }
    """
    data = request.get_json(silent=True) or {}
    active = data.get("active", True)
    device_id = data.get("device_id")
    db = get_db()

    if device_id:
        db.execute(
            "UPDATE devices SET active = ? WHERE device_id = ?",
            (1 if active else 0, device_id),
        )
        if not active:
            db.execute("DELETE FROM sessions WHERE device_id = ?", (device_id,))
    else:
        db.execute(
            "UPDATE global_config SET value = ? WHERE key = 'system_active'",
            ("1" if active else "0",),
        )
        if not active:
            db.execute("DELETE FROM sessions")

    db.commit()
    return jsonify({"ok": True, "active": active})


@app.route("/api/admin/add_key", methods=["POST"])
@require_admin
def admin_add_key():
    """
    Generate a new license key.

    Body: { "password": "...", "days": 30, "max_devices": 1, "key": "custom-key" (optional) }
    """
    data = request.get_json(silent=True) or {}
    days = data.get("days", 30)
    max_devices = data.get("max_devices", 1)
    custom_key = data.get("key")
    key = custom_key if custom_key else generate_license_key()

    db = get_db()
    try:
        db.execute(
            "INSERT INTO license_keys (license_key, max_devices, duration_days) VALUES (?, ?, ?)",
            (key, max_devices, days),
        )
        db.commit()
    except sqlite3.IntegrityError:
        return jsonify({"error": "key_already_exists"}), 409

    return jsonify({"ok": True, "key": key, "days": days, "max_devices": max_devices})


@app.route("/api/admin/revoke_key", methods=["POST"])
@require_admin
def admin_revoke_key():
    """
    Revoke a license key and disable all associated devices.

    Body: { "password": "...", "key": "XXXX-XXXX-XXXX-XXXX" }
    """
    data = request.get_json(silent=True) or {}
    key = data.get("key", "").strip()
    if not key:
        return jsonify({"error": "missing_key"}), 400

    db = get_db()
    lk = db.execute("SELECT id FROM license_keys WHERE license_key = ?", (key,)).fetchone()
    if lk is None:
        return jsonify({"error": "key_not_found"}), 404

    db.execute("UPDATE license_keys SET active = 0 WHERE id = ?", (lk["id"],))
    db.execute("UPDATE devices SET active = 0 WHERE license_key_id = ?", (lk["id"],))
    # Kill all sessions for devices under this key
    devices = db.execute(
        "SELECT device_id FROM devices WHERE license_key_id = ?", (lk["id"],)
    ).fetchall()
    for d in devices:
        db.execute("DELETE FROM sessions WHERE device_id = ?", (d["device_id"],))
    db.commit()

    return jsonify({"ok": True, "revoked": key})


@app.route("/api/admin/users", methods=["GET"])
@require_admin
def admin_users():
    """List all registered devices with their license and session info."""
    db = get_db()
    devices = db.execute("""
        SELECT d.device_id, d.active, d.registered_at, d.expires_at,
               lk.license_key, lk.duration_days,
               s.meomeo, s.session_token, s.expires_at as session_expires
        FROM devices d
        LEFT JOIN license_keys lk ON d.license_key_id = lk.id
        LEFT JOIN sessions s ON d.device_id = s.device_id
        ORDER BY d.registered_at DESC
    """).fetchall()

    return jsonify({
        "users": [dict(d) for d in devices],
        "total": len(devices),
    })


@app.route("/api/admin/keys", methods=["GET"])
@require_admin
def admin_keys():
    """List all license keys."""
    db = get_db()
    keys = db.execute("""
        SELECT lk.*, COUNT(d.id) as used_devices
        FROM license_keys lk
        LEFT JOIN devices d ON lk.id = d.license_key_id
        GROUP BY lk.id
        ORDER BY lk.created_at DESC
    """).fetchall()

    return jsonify({"keys": [dict(k) for k in keys]})


@app.route("/api/admin/logs", methods=["GET"])
@require_admin
def admin_logs():
    """View auth logs. ?limit=100"""
    limit = int(request.args.get("limit", 100))
    db = get_db()
    logs = db.execute(
        "SELECT * FROM auth_log ORDER BY created_at DESC LIMIT ?", (limit,)
    ).fetchall()

    return jsonify({"logs": [dict(l) for l in logs]})


@app.route("/api/admin/toggle_feature", methods=["POST"])
@require_admin
def admin_toggle_feature():
    """Toggle a specific feature on/off server-wide."""
    data = request.get_json(silent=True) or {}
    feature = (data.get("feature") or "").strip()
    val = data.get("value", True)
    features = get_server_features()
    if feature in features:
        features[feature] = bool(val)
        set_global_setting("server_features", json.dumps(features))
    return jsonify({"ok": True, "features": features})


@app.route("/api/admin/system_status", methods=["GET"])
@require_admin
def admin_system_status():
    """Get full dashboard data."""
    db = get_db()
    system_on = is_system_active()
    features = get_server_features()

    keys = db.execute("""
        SELECT lk.*, COUNT(d.id) as used_devices
        FROM license_keys lk
        LEFT JOIN devices d ON lk.id = d.license_key_id
        GROUP BY lk.id
        ORDER BY lk.created_at DESC
    """).fetchall()

    devices = db.execute("""
        SELECT d.device_id, d.active, d.registered_at, d.expires_at,
               lk.license_key, lk.duration_days,
               s.meomeo, s.session_token, s.expires_at as session_expires
        FROM devices d
        LEFT JOIN license_keys lk ON d.license_key_id = lk.id
        LEFT JOIN sessions s ON d.device_id = s.device_id
        ORDER BY d.registered_at DESC
    """).fetchall()

    logs = db.execute(
        "SELECT * FROM auth_log ORDER BY created_at DESC LIMIT 50"
    ).fetchall()

    return jsonify({
        "system_active": system_on,
        "features": features,
        "keys": [dict(k) for k in keys],
        "devices": [dict(d) for d in devices],
        "logs": [dict(l) for l in logs],
    })


# ─── Dashboard Web UI & Health Check ──────────────────────────────────────────
@app.route("/admin", methods=["GET"])
@app.route("/", methods=["GET"])
def index():
    if request.headers.get("Accept") == "application/json" and request.path == "/":
        return jsonify({
            "name": "MeoMeo License API",
            "version": "1.0.0",
            "status": "running",
            "system_active": is_system_active(),
            "port": 2007,
        })
    return render_template("index.html")


# ─── Main ─────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    init_db()
    port = int(os.environ.get("PORT", 2007))
    print(f"[MeoMeo API] DB: {DB_PATH}")
    print(f"[MeoMeo API] Starting on http://0.0.0.0:{port}")
    app.run(host="0.0.0.0", port=port, debug=True)
