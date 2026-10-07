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
ADMIN_PASSWORD = os.environ.get("MEOMEO_ADMIN_PASS", "nxt2007")
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


# ─── Auto-delete expired keys & devices ───────────────────────────────────────
def purge_expired_keys(db=None):
    """
    Automatically delete expired keys, their devices, and sessions from the database.
    A key is considered expired if it has registered devices and all its devices have expires_at < now.
    """
    if db is None:
        db = get_db()

    now = datetime.utcnow()
    now_iso = now.isoformat()

    # 1. Find all keys where all registered devices have expired
    expired_keys = db.execute("""
        SELECT lk.id, lk.license_key
        FROM license_keys lk
        JOIN devices d ON lk.id = d.license_key_id
        GROUP BY lk.id
        HAVING MAX(d.expires_at) < ?
    """, (now_iso,)).fetchall()

    deleted_count = len(expired_keys)
    for k in expired_keys:
        key_id = k["id"]
        # Delete sessions for devices bound to this key
        db.execute("""
            DELETE FROM sessions WHERE device_id IN (
                SELECT device_id FROM devices WHERE license_key_id = ?
            )
        """, (key_id,))
        # Delete devices bound to this key
        db.execute("DELETE FROM devices WHERE license_key_id = ?", (key_id,))
        # Delete the key itself
        db.execute("DELETE FROM license_keys WHERE id = ?", (key_id,))

    # 2. Also clean up any orphan expired devices if any exist
    orphan_devices = db.execute("SELECT device_id FROM devices WHERE expires_at < ?", (now_iso,)).fetchall()
    for d in orphan_devices:
        db.execute("DELETE FROM sessions WHERE device_id = ?", (d["device_id"],))
    if orphan_devices:
        db.execute("DELETE FROM devices WHERE expires_at < ?", (now_iso,))

    if deleted_count > 0 or orphan_devices:
        db.commit()

    return deleted_count


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
        return jsonify({"ok": False, "error": "missing device_id or key"}), 400

    if not is_system_active():
        log_auth(device_id, "auth", "system_off")
        return jsonify({"ok": False, "error": "system_offline", "active": False}), 503

    db = get_db()
    purge_expired_keys(db)

    # Find license key
    lk = db.execute(
        "SELECT * FROM license_keys WHERE license_key = ? AND active = 1", (key,)
    ).fetchone()

    if lk is None:
        log_auth(device_id, "auth", "invalid_key")
        return jsonify({"ok": False, "error": "invalid_key"}), 401

    # Check if device already registered
    device = db.execute(
        "SELECT * FROM devices WHERE device_id = ?", (device_id,)
    ).fetchone()

    now = datetime.utcnow()

    if device is None:
        # Check max devices for this license (if not unlimited)
        device_count = db.execute(
            "SELECT COUNT(*) as cnt FROM devices WHERE license_key_id = ?",
            (lk["id"],),
        ).fetchone()["cnt"]

        if lk["max_devices"] < 9999 and device_count >= lk["max_devices"]:
            log_auth(device_id, "auth", "max_devices")
            return jsonify({"ok": False, "error": "max_devices_reached"}), 403

        # Register new device
        duration_hours = lk["duration_hours"] if ("duration_hours" in lk.keys() and lk["duration_hours"] and lk["duration_hours"] > 0) else 0
        if duration_hours > 0:
            expires_at = now + timedelta(hours=duration_hours)
        else:
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
            return jsonify({"ok": False, "error": "device_bound_to_different_key"}), 403

        # Check device active
        if not device["active"]:
            log_auth(device_id, "auth", "device_disabled")
            return jsonify({"ok": False, "error": "device_disabled"}), 403

        # Check expiry
        expires_at = datetime.fromisoformat(device["expires_at"])
        if now > expires_at:
            log_auth(device_id, "auth", "expired")
            return jsonify({"ok": False, "error": "license_expired", "expires_at": device["expires_at"]}), 403

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
        "ok": True,
        "status": "active",
        "meomeo": meomeo,
        "sig": sig,
        "ts": ts,
        "token": token,
        "session_token": session_token,
        "expires_at": session_expires,
        "device_expires": device["expires_at"],
        "system_active": True,
        "testCodePatch": True,
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
    purge_expired_keys(db)

    # Check device and parent license key
    device = db.execute("""
        SELECT d.active as device_active, d.expires_at, lk.active as key_active
        FROM devices d
        JOIN license_keys lk ON d.license_key_id = lk.id
        WHERE d.device_id = ?
    """, (device_id,)).fetchone()
    if device is None:
        return jsonify({"valid": False, "error": "device_not_found"})

    if not device["device_active"] or not device["key_active"]:
        return jsonify({"valid": False, "error": "key_banned"})

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
            "testCodePatch": True,
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
            "ok": True,
            "active": False,
            "system_active": False,
            "testCodePatch": True,
            "features": features,
            "token": token,
            "ts": ts,
            "error": "system_offline"
        }), 200

    db = get_db()
    purge_expired_keys(db)
    # Check if device and license key are active and not expired
    device = db.execute("""
        SELECT d.active as device_active, d.expires_at, lk.active as key_active, lk.license_key
        FROM devices d
        JOIN license_keys lk ON d.license_key_id = lk.id
        WHERE d.device_id = ?
    """, (device_id,)).fetchone()

    if device is None:
        log_auth(device_id, "heartbeat", "device_not_found")
        token = generate_encrypted_token(current_time_epoch, 0, 0)
        return jsonify({
            "ok": False,
            "active": False,
            "system_active": False,
            "testCodePatch": True,
            "features": features,
            "token": token,
            "error": "device_not_found"
        }), 200

    if not device["device_active"] or not device["key_active"]:
        log_auth(device_id, "heartbeat", "key_banned")
        token = generate_encrypted_token(current_time_epoch, 0, 0)
        return jsonify({
            "ok": False,
            "active": False,
            "system_active": False,
            "testCodePatch": True,
            "features": features,
            "token": token,
            "error": "key_banned"
        }), 200

    # Check device expiration
    try:
        exp_dt = datetime.fromisoformat(device["expires_at"])
        if now > exp_dt:
            log_auth(device_id, "heartbeat", "license_expired")
            token = generate_encrypted_token(current_time_epoch, 0, 0)
            return jsonify({
                "ok": False,
                "active": False,
                "system_active": False,
                "testCodePatch": True,
                "features": features,
                "token": token,
                "error": "license_expired"
            }), 200
    except Exception:
        pass

    # Verify session is still valid (not purged via Reset HWID or Delete Key)
    session = db.execute(
        "SELECT id FROM sessions WHERE device_id = ? AND session_token = ?",
        (device_id, session_token),
    ).fetchone()
    if session is None:
        log_auth(device_id, "heartbeat", "session_terminated")
        token = generate_encrypted_token(current_time_epoch, 0, 0)
        return jsonify({
            "ok": False,
            "active": False,
            "system_active": False,
            "testCodePatch": True,
            "features": features,
            "token": token,
            "error": "session_terminated"
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
        "testCodePatch": True,
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
    result = {"system_active": system_on, "features": features, "testCodePatch": True}

    if not system_on:
        result["ok"] = False
        result["error"] = "system_offline"
        now_ts = int(time.time()) + (SESSION_TTL_MINUTES * 60)
        result["token"] = generate_encrypted_token(now_ts, 0, 0)
        result["ts"] = now_ts
        return jsonify(result)

    if device_id:
        db = get_db()
        device = db.execute("""
            SELECT d.active as device_active, d.expires_at, lk.active as key_active
            FROM devices d
            JOIN license_keys lk ON d.license_key_id = lk.id
            WHERE d.device_id = ?
        """, (device_id,)).fetchone()

        if device is None:
            result["ok"] = False
            result["error"] = "device_not_found"
        elif not device["device_active"] or not device["key_active"]:
            result["ok"] = False
            result["error"] = "key_banned"
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
    result["testCodePatch"] = True

    return jsonify(result)


@app.route("/api/check_key", methods=["GET", "POST"])
def check_key():
    """Kiểm tra thông tin một license key công khai cho người dùng tra cứu an toàn."""
    if request.method == "POST":
        data = request.get_json(silent=True) or {}
        key = (data.get("key") or "").strip()
    else:
        key = request.args.get("key", "").strip()

    if not key:
        return jsonify({"ok": False, "error": "Vui lòng nhập License Key cần kiểm tra"}), 400

    db = get_db()
    purge_expired_keys(db)
    lk = db.execute("SELECT * FROM license_keys WHERE license_key = ?", (key,)).fetchone()
    if not lk:
        return jsonify({"ok": False, "error": "License Key không tồn tại hoặc đã hết hạn bị tự động xoá"}), 404

    devices = db.execute("SELECT device_id, expires_at, active FROM devices WHERE license_key_id = ?", (lk["id"],)).fetchall()
    used_count = len(devices)

    now = datetime.utcnow()
    is_banned = (lk["active"] == 0)

    expires_str = "Chưa kích hoạt trên máy"
    is_expired = False
    if devices:
        exp_dt_raw = devices[0]["expires_at"]
        try:
            exp_dt = datetime.fromisoformat(exp_dt_raw)
            expires_str = exp_dt.strftime("%d/%m/%Y %H:%M:%S")
            if now > exp_dt:
                is_expired = True
        except Exception:
            expires_str = str(exp_dt_raw)

    status_label = "Hoạt động"
    if is_banned:
        status_label = "Bị khóa (Banned)"
    elif is_expired:
        status_label = "Đã hết hạn"

    is_unlimited_hwid = (lk["max_devices"] >= 9999)
    device_summary = f"{used_count} máy (Không giới hạn)" if is_unlimited_hwid else f"{used_count} / {lk['max_devices']} máy"

    duration_h = lk["duration_hours"] if ("duration_hours" in lk.keys() and lk["duration_hours"] and lk["duration_hours"] > 0) else 0
    if duration_h > 0:
        duration_text = f"{int(duration_h) if duration_h.is_integer() else duration_h} Giờ"
    elif lk["duration_days"] >= 9999:
        duration_text = "Vĩnh viễn"
    else:
        duration_text = f"{lk['duration_days']} ngày"

    return jsonify({
        "ok": True,
        "key": lk["license_key"],
        "duration_days": lk["duration_days"],
        "duration_hours": duration_h,
        "duration_text": duration_text,
        "max_devices": lk["max_devices"],
        "max_devices_text": "Không giới hạn" if is_unlimited_hwid else f"{lk['max_devices']} máy",
        "used_devices": used_count,
        "device_summary": device_summary,
        "status": status_label,
        "active": (not is_banned) and (not is_expired),
        "expires_at": expires_str,
        "created_at": lk["created_at"]
    })


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
    else:
        db.execute(
            "UPDATE global_config SET value = ? WHERE key = 'system_active'",
            ("1" if active else "0",),
        )

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
    seller_id = data.get("seller_id")
    key = custom_key if custom_key else generate_license_key()

    db = get_db()
    try:
        db.execute(
            "INSERT INTO license_keys (license_key, max_devices, duration_days, seller_id) VALUES (?, ?, ?, ?)",
            (key, max_devices, days, seller_id),
        )
        db.commit()
    except sqlite3.IntegrityError:
        return jsonify({"error": "key_already_exists"}), 409

    return jsonify({"ok": True, "key": key, "days": days, "max_devices": max_devices, "seller_id": seller_id})


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


@app.route("/api/admin/reset_hwid", methods=["POST"])
@require_admin
def admin_reset_hwid():
    """
    Reset HWID binding for a license key or specific device.
    Body: { "password": "...", "key": "..." } or { "password": "...", "device_id": "..." }
    """
    data = request.get_json(silent=True) or {}
    key = (data.get("key") or "").strip()
    device_id = (data.get("device_id") or "").strip()
    db = get_db()

    if key:
        lk = db.execute("SELECT id FROM license_keys WHERE license_key = ?", (key,)).fetchone()
        if not lk:
            return jsonify({"error": "key_not_found"}), 404
        devices = db.execute("SELECT device_id FROM devices WHERE license_key_id = ?", (lk["id"],)).fetchall()
        for d in devices:
            db.execute("DELETE FROM sessions WHERE device_id = ?", (d["device_id"],))
        db.execute("DELETE FROM devices WHERE license_key_id = ?", (lk["id"],))
        db.commit()
        return jsonify({"ok": True, "message": f"Đã reset HWID cho key {key}"})

    if device_id:
        db.execute("DELETE FROM sessions WHERE device_id = ?", (device_id,))
        db.execute("DELETE FROM devices WHERE device_id = ?", (device_id,))
        db.commit()
        return jsonify({"ok": True, "message": f"Đã xoá thiết bị {device_id}"})

    return jsonify({"error": "missing_key_or_device_id"}), 400


@app.route("/api/admin/delete_key", methods=["POST"])
@require_admin
def admin_delete_key():
    """
    Permanently delete a license key, all bound devices, and sessions.
    Body: { "password": "...", "key": "..." }
    """
    data = request.get_json(silent=True) or {}
    key = (data.get("key") or "").strip()
    if not key:
        return jsonify({"error": "missing_key"}), 400
    db = get_db()
    lk = db.execute("SELECT id FROM license_keys WHERE license_key = ?", (key,)).fetchone()
    if not lk:
        return jsonify({"error": "key_not_found"}), 404

    devices = db.execute("SELECT device_id FROM devices WHERE license_key_id = ?", (lk["id"],)).fetchall()
    for d in devices:
        db.execute("DELETE FROM sessions WHERE device_id = ?", (d["device_id"],))
    db.execute("DELETE FROM devices WHERE license_key_id = ?", (lk["id"],))
    db.execute("DELETE FROM license_keys WHERE id = ?", (lk["id"],))
    db.commit()
    return jsonify({"ok": True, "deleted": key})


@app.route("/api/admin/ban_key", methods=["POST"])
@require_admin
def admin_ban_key():
    """
    Ban or unban a license key and all associated devices.
    Body: { "password": "...", "key": "...", "banned": true/false }
    """
    data = request.get_json(silent=True) or {}
    key = (data.get("key") or "").strip()
    banned = data.get("banned", True)
    if not key:
        return jsonify({"error": "missing_key"}), 400
    db = get_db()
    lk = db.execute("SELECT id FROM license_keys WHERE license_key = ?", (key,)).fetchone()
    if not lk:
        return jsonify({"error": "key_not_found"}), 404

    new_active = 0 if banned else 1
    db.execute("UPDATE license_keys SET active = ? WHERE id = ?", (new_active, lk["id"]))
    db.execute("UPDATE devices SET active = ? WHERE license_key_id = ?", (new_active, lk["id"]))
    if banned:
        devices = db.execute("SELECT device_id FROM devices WHERE license_key_id = ?", (lk["id"],)).fetchall()
        for d in devices:
            db.execute("DELETE FROM sessions WHERE device_id = ?", (d["device_id"],))
    db.commit()
    return jsonify({"ok": True, "key": key, "active": new_active, "banned": bool(banned)})


@app.route("/api/admin/ban_device", methods=["POST"])
@require_admin
def admin_ban_device():
    """
    Ban or unban a specific device HWID.
    Body: { "password": "...", "device_id": "...", "active": true/false }
    """
    data = request.get_json(silent=True) or {}
    device_id = (data.get("device_id") or "").strip()
    active = data.get("active", False)
    if not device_id:
        return jsonify({"error": "missing_device_id"}), 400
    db = get_db()
    db.execute("UPDATE devices SET active = ? WHERE device_id = ?", (1 if active else 0, device_id))
    if not active:
        db.execute("DELETE FROM sessions WHERE device_id = ?", (device_id,))
    db.commit()
    return jsonify({"ok": True, "device_id": device_id, "active": bool(active)})


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


@app.route("/api/admin/clean_expired", methods=["POST"])
@require_admin
def admin_clean_expired():
    """Manually trigger auto-delete of expired keys and devices."""
    db = get_db()
    deleted = purge_expired_keys(db)
    return jsonify({"ok": True, "deleted_keys": deleted})


@app.route("/api/admin/system_status", methods=["GET"])
@require_admin
def admin_system_status():
    """Get full dashboard data."""
    db = get_db()
    purge_expired_keys(db)
    system_on = is_system_active()
    features = get_server_features()

    keys = db.execute("""
        SELECT lk.*, COUNT(d.id) as used_devices, s.name as seller_name
        FROM license_keys lk
        LEFT JOIN devices d ON lk.id = d.license_key_id
        LEFT JOIN sellers s ON lk.seller_id = s.id
        GROUP BY lk.id
        ORDER BY lk.created_at DESC
    """).fetchall()

    sellers = db.execute("""
        SELECT s.*, COUNT(lk.id) as key_count
        FROM sellers s
        LEFT JOIN license_keys lk ON s.id = lk.seller_id
        GROUP BY s.id
        ORDER BY s.created_at DESC
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
        "sellers": [dict(s) for s in sellers],
        "devices": [dict(d) for d in devices],
        "logs": [dict(l) for l in logs],
    })


# ═══════════════════════════════════════════════════════════════════════════════
# ADMIN SELLER MANAGEMENT ENDPOINTS
# ═══════════════════════════════════════════════════════════════════════════════

@app.route("/api/admin/add_seller", methods=["POST"])
@require_admin
def admin_add_seller():
    """Create a new seller account with dedicated token."""
    data = request.get_json(silent=True) or {}
    name = (data.get("name") or "").strip()
    custom_token = (data.get("token") or "").strip()
    max_devices_limit = int(data.get("max_devices_limit") or 99999)
    note = (data.get("note") or "").strip()

    if not name:
        return jsonify({"ok": False, "error": "Vui lòng nhập tên Seller"}), 400

    token = custom_token if custom_token else secrets.token_hex(8)
    db = get_db()
    try:
        db.execute(
            "INSERT INTO sellers (name, token, active, max_devices_limit, note) VALUES (?, ?, 1, ?, ?)",
            (name, token, max_devices_limit, note)
        )
        db.commit()
    except sqlite3.IntegrityError:
        return jsonify({"ok": False, "error": "Token seller đã tồn tại"}), 409

    seller = db.execute("SELECT * FROM sellers WHERE token = ?", (token,)).fetchone()
    return jsonify({"ok": True, "seller": dict(seller)})


@app.route("/api/admin/delete_seller", methods=["POST"])
@require_admin
def admin_delete_seller():
    """Delete a seller and unassign or delete their keys."""
    data = request.get_json(silent=True) or {}
    seller_id = data.get("seller_id")
    if not seller_id:
        return jsonify({"ok": False, "error": "missing_seller_id"}), 400

    db = get_db()
    db.execute("UPDATE license_keys SET seller_id = NULL WHERE seller_id = ?", (seller_id,))
    db.execute("DELETE FROM sellers WHERE id = ?", (seller_id,))
    db.commit()
    return jsonify({"ok": True, "message": "Đã xoá Seller thành công"})


@app.route("/api/admin/toggle_seller", methods=["POST"])
@require_admin
def admin_toggle_seller():
    """Toggle a seller active status."""
    data = request.get_json(silent=True) or {}
    seller_id = data.get("seller_id")
    active = data.get("active", True)
    if not seller_id:
        return jsonify({"ok": False, "error": "missing_seller_id"}), 400

    db = get_db()
    db.execute("UPDATE sellers SET active = ? WHERE id = ?", (1 if active else 0, seller_id))
    db.commit()
    return jsonify({"ok": True, "active": active})


# ═══════════════════════════════════════════════════════════════════════════════
# SELLER PORTAL API ENDPOINTS (/api/seller/...)
# ═══════════════════════════════════════════════════════════════════════════════

def get_seller_by_token(token: str):
    if not token:
        return None
    db = get_db()
    return db.execute("SELECT * FROM sellers WHERE token = ? AND active = 1", (token,)).fetchone()


def require_seller(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        data = request.get_json(silent=True) or {}
        token = data.get("token") or request.args.get("token", "")
        if not token and "token" in kwargs:
            token = kwargs["token"]
        seller = get_seller_by_token(token)
        if not seller:
            return jsonify({"ok": False, "error": "Token Seller không hợp lệ hoặc đã bị khoá"}), 403
        g.seller = seller
        return f(*args, **kwargs)
    return decorated


@app.route("/api/seller/dashboard", methods=["GET"])
@require_seller
def seller_dashboard():
    """Get dashboard stats and keys belonging strictly to this seller."""
    seller = g.seller
    db = get_db()
    purge_expired_keys(db)

    keys = db.execute("""
        SELECT lk.*, COUNT(d.id) as used_devices
        FROM license_keys lk
        LEFT JOIN devices d ON lk.id = d.license_key_id
        WHERE lk.seller_id = ?
        GROUP BY lk.id
        ORDER BY lk.created_at DESC
    """, (seller["id"],)).fetchall()

    return jsonify({
        "ok": True,
        "seller": {
            "id": seller["id"],
            "name": seller["name"],
            "token": seller["token"],
            "created_at": seller["created_at"]
        },
        "keys": [dict(k) for k in keys],
        "total_keys": len(keys),
        "active_keys": len([k for k in keys if k["active"] == 1])
    })


@app.route("/api/seller/create_key", methods=["POST"])
@require_seller
def seller_create_key():
    """Seller creates a new license key (1, 3, 5, 7, 30 days, custom devices)."""
    seller = g.seller
    data = request.get_json(silent=True) or {}
    days = int(data.get("days", 30))
    max_devices = int(data.get("max_devices", 1))
    custom_key = (data.get("key") or "").strip()

    # Supported seller durations: 1, 3, 5, 7, 30 days (or flexible)
    allowed_days = [1, 3, 5, 7, 30, 90, 365, 9999]
    if days not in allowed_days:
        days = 30

    if max_devices < 1:
        max_devices = 1

    key = custom_key if custom_key else generate_license_key()
    db = get_db()
    try:
        db.execute(
            "INSERT INTO license_keys (license_key, max_devices, duration_days, seller_id) VALUES (?, ?, ?, ?)",
            (key, max_devices, days, seller["id"])
        )
        db.commit()
    except sqlite3.IntegrityError:
        return jsonify({"ok": False, "error": "Mã Key đã tồn tại, vui lòng đổi mã khác"}), 409

    return jsonify({"ok": True, "key": key, "days": days, "max_devices": max_devices})


@app.route("/api/seller/reset_hwid", methods=["POST"])
@require_seller
def seller_reset_hwid():
    """Seller resets HWID for their own keys only."""
    seller = g.seller
    data = request.get_json(silent=True) or {}
    key = (data.get("key") or "").strip()
    if not key:
        return jsonify({"ok": False, "error": "Vui lòng nhập License Key cần reset"}), 400

    db = get_db()
    lk = db.execute("SELECT id FROM license_keys WHERE license_key = ? AND seller_id = ?", (key, seller["id"])).fetchone()
    if not lk:
        return jsonify({"ok": False, "error": "Key không tồn tại hoặc không thuộc quyền quản lý của bạn"}), 404

    devices = db.execute("SELECT device_id FROM devices WHERE license_key_id = ?", (lk["id"],)).fetchall()
    for d in devices:
        db.execute("DELETE FROM sessions WHERE device_id = ?", (d["device_id"],))
    db.execute("DELETE FROM devices WHERE license_key_id = ?", (lk["id"],))
    db.commit()
    return jsonify({"ok": True, "message": f"Đã reset HWID cho key {key}"})


@app.route("/api/seller/delete_key", methods=["POST"])
@require_seller
def seller_delete_key():
    """Seller deletes their own license key."""
    seller = g.seller
    data = request.get_json(silent=True) or {}
    key = (data.get("key") or "").strip()
    if not key:
        return jsonify({"ok": False, "error": "Vui lòng nhập License Key cần xoá"}), 400

    db = get_db()
    lk = db.execute("SELECT id FROM license_keys WHERE license_key = ? AND seller_id = ?", (key, seller["id"])).fetchone()
    if not lk:
        return jsonify({"ok": False, "error": "Key không tồn tại hoặc không thuộc quyền quản lý của bạn"}), 404

    devices = db.execute("SELECT device_id FROM devices WHERE license_key_id = ?", (lk["id"],)).fetchall()
    for d in devices:
        db.execute("DELETE FROM sessions WHERE device_id = ?", (d["device_id"],))
    db.execute("DELETE FROM devices WHERE license_key_id = ?", (lk["id"],))
    db.execute("DELETE FROM license_keys WHERE id = ?", (lk["id"],))
    db.commit()
    return jsonify({"ok": True, "message": f"Đã xoá vĩnh viễn key {key}"})


# ═══════════════════════════════════════════════════════════════════════════════
# GETKEY SYSTEM (/hoagetkey) — VUOTLINK.XYZ INTEGRATION
# ═══════════════════════════════════════════════════════════════════════════════

import urllib.request
import urllib.parse

VUOTLINK_API_KEY = "7685e29d1067fdcd8331781c81801d912ebfb882"


def purge_expired_getkey_sessions(db=None):
    """Clean up old getkey sessions older than 3 hours."""
    if db is None:
        db = get_db()
    now_iso = datetime.utcnow().isoformat()
    db.execute("DELETE FROM getkey_sessions WHERE expires_at < ?", (now_iso,))
    db.commit()


def generate_getkey_sig(session_token: str, claim_secret: str, hwid: str) -> str:
    """Generate tamper-proof HMAC signature for GetKey session verification."""
    payload = f"vuotlink:{session_token}:{claim_secret}:{hwid}"
    return hmac.new(APP_SECRET.encode(), payload.encode(), hashlib.sha256).hexdigest()[:24]


def create_vuotlink_shorturl(target_url: str) -> str:
    """
    Call vuotlink.xyz official API to generate real shortened link.
    If the API call fails or times out, fallback to /st? query.
    """
    endpoint = f"https://vuotlink.xyz/api?api={VUOTLINK_API_KEY}&url={urllib.parse.quote(target_url)}"
    try:
        req = urllib.request.Request(
            endpoint,
            headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
        )
        with urllib.request.urlopen(req, timeout=7) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if data.get("status") == "success" and data.get("shortenedUrl"):
                return data["shortenedUrl"]
    except Exception as e:
        print(f"[VuotLink API] Warning: API request failed ({e}), using direct link format")
    return f"https://vuotlink.xyz/st?api={VUOTLINK_API_KEY}&url={urllib.parse.quote(target_url)}"


@app.route("/hoagetkey", methods=["GET"])
def getkey_page():
    """
    Dedicated GetKey Web Interface.
    Hidden from index / client view.
    Accepts st, claim, sig query parameters upon successful bypass redirection.
    """
    st = request.args.get("st", "").strip()
    claim = request.args.get("claim", "").strip()
    sig = request.args.get("sig", "").strip()
    return render_template("getkey.html", st=st, claim=claim, sig=sig)


@app.route("/api/getkey/init", methods=["POST"])
def getkey_init():
    """
    Step 1: User enters HWID on /hoagetkey.
    Anti-bot / Anti-bypass checks:
      - Validates HWID format & length (at least 8 chars).
      - Strict Rate Limiting: Max 10 pending sessions per IP per 30 minutes to prevent API flooding/scanning.
      - Generates cryptographically secure session_token and claim_secret.
      - Creates HMAC signature 'sig' bound to APP_SECRET, session_token, claim_secret, and hwid.
      - Generates the callback destination URL:
          http://<host>/hoagetkey?st=<session_token>&claim=<claim_secret>&sig=<sig>
      - Calls vuotlink.xyz API to shorten that destination URL.
      - Returns ONLY { "ok": True, "vuotlink_url": shortened_url }.
      - Does NOT return session_token, claim_secret, sig, or any key!
    """
    data = request.get_json(silent=True) or {}
    hwid = (data.get("hwid") or "").strip().upper()

    if not hwid or len(hwid) < 8:
        return jsonify({"ok": False, "error": "Vui lòng nhập đúng mã HWID của thiết bị bạn!"}), 400

    db = get_db()
    purge_expired_getkey_sessions(db)
    now = datetime.utcnow()
    ip_addr = request.remote_addr or ""

    # Rate limiting: Maximum 10 pending sessions per IP per 30 minutes to prevent scanning/flooding
    recent_sessions = db.execute(
        "SELECT COUNT(*) as cnt FROM getkey_sessions WHERE ip_address = ? AND created_at > datetime('now', '-30 minutes')",
        (ip_addr,)
    ).fetchone()["cnt"]

    if recent_sessions >= 12:
        return jsonify({
            "ok": False,
            "error": "Bạn đã gửi quá nhiều yêu cầu vượt link! Vui lòng hoàn thành link hiện tại hoặc thử lại sau 30 phút."
        }), 429

    # Generate cryptographically secure tokens
    session_token = secrets.token_hex(16)
    claim_secret = secrets.token_hex(16)
    sig = generate_getkey_sig(session_token, claim_secret, hwid)
    expires_at = (now + timedelta(hours=2)).isoformat()
    created_at = now.isoformat()

    db.execute(
        "INSERT INTO getkey_sessions (token, claim_secret, hwid, ip_address, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?)",
        (session_token, claim_secret, hwid, ip_addr, created_at, expires_at)
    )
    db.commit()

    # Determine public host (use request host or configured public server IP:port)
    host = request.host
    scheme = "http"
    if request.is_secure or request.headers.get("X-Forwarded-Proto") == "https":
        scheme = "https"

    # Callback target URL that vuotlink will redirect to once user finishes countdown
    target_url = f"{scheme}://{host}/hoagetkey?st={session_token}&claim={claim_secret}&sig={sig}"

    # Get real shortened URL from vuotlink.xyz
    short_link = create_vuotlink_shorturl(target_url)

    # Return ONLY the short link to force user to go through vuotlink.xyz
    return jsonify({
        "ok": True,
        "vuotlink_url": short_link
    })


@app.route("/api/getkey/claim", methods=["POST"])
def getkey_claim():
    """
    Step 2: User finishes vuotlink.xyz and is redirected back to:
      /hoagetkey?st=<st>&claim=<claim>&sig=<sig>
    This endpoint strictly verifies:
      - 'st', 'claim', 'sig' are all provided
      - Session exists in DB and is unexpired
      - 'claim' matches DB 'claim_secret'
      - 'sig' matches server HMAC (cannot be forged by bot or scanner)
      - Anti-instant-bypass check: Human must take at least 8 seconds to bypass vuotlink!
        If time elapsed since session creation < 8 seconds, reject.
      - If already claimed in this session, return existing key.
      - If new claim:
          - Generate 5-hour key: MEO-5H-XXXX-XXXX (duration_hours=5, max_devices=1)
          - Bind HWID to devices table with expires_at = now + 5 hours
          - Mark session completed = 1, license_key = key
          - Return key to user
    """
    data = request.get_json(silent=True) or {}
    st = (data.get("st") or "").strip()
    claim = (data.get("claim") or "").strip()
    sig = (data.get("sig") or "").strip()

    if not st or not claim or not sig:
        return jsonify({
            "ok": False,
            "error": "Thiếu thông tin xác thực vượt link! Bạn phải vượt link vuotlink.xyz để nhận mã xác thực."
        }), 400

    db = get_db()
    session = db.execute("SELECT * FROM getkey_sessions WHERE token = ?", (st,)).fetchone()
    if not session:
        return jsonify({
            "ok": False,
            "error": "Phiên GetKey không tồn tại hoặc đã hết hạn. Vui lòng bấm Bắt Đầu Lấy Link Vượt để thực hiện lại!"
        }), 404

    now = datetime.utcnow()
    try:
        exp_dt = datetime.fromisoformat(session["expires_at"])
        if now > exp_dt:
            return jsonify({"ok": False, "error": "Phiên GetKey đã hết hạn. Vui lòng lấy link mới!"}), 400
    except Exception:
        pass

    # Verify claim_secret matches
    if not hmac.compare_digest(session["claim_secret"], claim):
        return jsonify({"ok": False, "error": "Mã xác thực không khớp! Bạn phải vượt link thật qua vuotlink.xyz."}), 403

    # Verify cryptographic signature
    expected_sig = generate_getkey_sig(session["token"], claim, session["hwid"])
    if not hmac.compare_digest(sig, expected_sig):
        return jsonify({"ok": False, "error": "Chữ ký bảo mật không hợp lệ! Vui lòng không sử dụng tool bypass hoặc scan API."}), 403

    # Anti-instant-bypass / Anti-bot check:
    # A human going through vuotlink.xyz takes at least 10-15 seconds (countdown is 15s).
    # If the claim is submitted in under 8 seconds, it is definitely a bot or script attempting to bypass.
    try:
        created_dt = datetime.fromisoformat(session["created_at"])
        elapsed_sec = (now - created_dt).total_seconds()
        if elapsed_sec < 8:
            return jsonify({
                "ok": False,
                "error": "Thao tác quá nhanh (dưới 8 giây)! Hệ thống phát hiện bot scan hoặc công cụ bypass. Vui lòng vượt link bình thường!"
            }), 400
    except Exception:
        pass

    # If already claimed in this session, return the generated key
    if session["completed"] == 1 and session["license_key"]:
        return jsonify({
            "ok": True,
            "key": session["license_key"],
            "hwid": session["hwid"],
            "duration": "5 Giờ",
            "message": "Key của bạn đã được cấp thành công!"
        })

    # Generate dedicated 5-hour key: MEO-5H-XXXX-XXXX
    hwid = session["hwid"]
    part1 = secrets.token_hex(2).upper()
    part2 = secrets.token_hex(2).upper()
    new_key = f"MEO-5H-{part1}-{part2}"

    # Insert key into license_keys with duration_hours=5, max_devices=1
    try:
        db.execute(
            "INSERT INTO license_keys (license_key, max_devices, duration_days, duration_hours, active) VALUES (?, 1, 1, 5, 1)",
            (new_key,)
        )
    except sqlite3.IntegrityError:
        new_key = generate_license_key()
        db.execute(
            "INSERT INTO license_keys (license_key, max_devices, duration_days, duration_hours, active) VALUES (?, 1, 1, 5, 1)",
            (new_key,)
        )

    # Pre-bind the device to this key directly so it cannot be used on another device
    lk = db.execute("SELECT id FROM license_keys WHERE license_key = ?", (new_key,)).fetchone()
    if lk:
        device_expires = (now + timedelta(hours=5)).isoformat()
        db.execute("DELETE FROM devices WHERE device_id = ?", (hwid,))
        db.execute(
            "INSERT INTO devices (device_id, license_key_id, expires_at) VALUES (?, ?, ?)",
            (hwid, lk["id"], device_expires)
        )

    # Mark session completed
    db.execute(
        "UPDATE getkey_sessions SET completed = 1, license_key = ? WHERE id = ?",
        (new_key, session["id"])
    )
    db.commit()

    return jsonify({
        "ok": True,
        "key": new_key,
        "hwid": hwid,
        "duration": "5 Giờ",
        "message": "Chúc mừng bạn đã vượt link thành công! Key có thời hạn 5 giờ cho 1 máy."
    })



# ─── Dashboard Web UI & Seller Portal Route ───────────────────────────────────
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


@app.route("/<path:seller_path>", methods=["GET"])
def seller_page(seller_path):
    """
    Dedicated Seller Web Interface.
    Matches paths like /seuvip-tokenxxxxx, /seller-token123, or any custom path token.
    If the path matches a seller token or prefix, it serves the dedicated Seller UI.
    """
    token = seller_path.strip()
    if token == "hoagetkey":
        return render_template("getkey.html", token="")

    # Check if format is prefix-token (e.g. seuvip-3ce84676a3567f00 or seller-xxxxx)
    if "-" in token:
        prefix, possible_token = token.split("-", 1)
    else:
        possible_token = token

    db = get_db()
    seller = db.execute(
        "SELECT * FROM sellers WHERE token = ? OR token = ? AND active = 1",
        (token, possible_token)
    ).fetchone()

    if seller:
        return render_template("seller.html", seller=dict(seller), seller_token=seller["token"])

    # Fallback to index if not a seller route
    return render_template("index.html")


# ─── Main ─────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    init_db()
    port = int(os.environ.get("PORT", 2007))
    print(f"[MeoMeo API] DB: {DB_PATH}")
    print(f"[MeoMeo API] Starting on http://0.0.0.0:{port}")
    app.run(host="0.0.0.0", port=port, debug=True)
