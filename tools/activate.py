#!/usr/bin/env python3
"""
CLI Tool for MeoMeo License Authentication & localConfig.json Sync.
Used for testing genuine online authentication and verifying that offline access is denied.

Usage:
  python tools/activate.py --key <LICENSE_KEY> [--api <SERVER_URL>]
  python tools/activate.py --deactivate
  python tools/activate.py --status
  python tools/activate.py --heartbeat
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
import uuid

DEFAULT_API = os.environ.get("MEOMEO_API_URL", "http://127.0.0.1:2007")
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCAL_CONFIG = os.path.join(ROOT_DIR, "localConfig.json")
DONEMAKE_CONFIG = os.path.join(ROOT_DIR, "donemake", "localConfig.json")
STATE_FILE = os.path.join(ROOT_DIR, ".activate_session.json")


def load_config(path: str) -> dict:
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {}


def save_config(path: str, data: dict):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def api_post(base_url: str, endpoint: str, payload: dict) -> dict:
    url = f"{base_url.rstrip('/')}{endpoint}"
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json", "User-Agent": "MeoMeo-CLI/1.0"},
        method="POST"
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode("utf-8"))


def api_get(base_url: str, endpoint: str) -> dict:
    url = f"{base_url.rstrip('/')}{endpoint}"
    req = urllib.request.Request(
        url,
        headers={"Content-Type": "application/json", "User-Agent": "MeoMeo-CLI/1.0"},
        method="GET"
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode("utf-8"))


def deactivate():
    print("[*] Deactivating localConfig.json (Locking system)...")
    for path in [LOCAL_CONFIG, DONEMAKE_CONFIG]:
        cfg = load_config(path)
        cfg["meomeo"] = ""
        cfg["sig"] = ""
        cfg["token"] = ""
        cfg["ts"] = 0
        cfg["system_active"] = False
        save_config(path, cfg)
        print(f"[-] Locked: {path}")

    if os.path.exists(STATE_FILE):
        try:
            os.remove(STATE_FILE)
        except Exception:
            pass
    print("[+] Deactivation complete. Patch will be disabled in game.")


def main():
    parser = argparse.ArgumentParser(description="MeoMeo License Activation CLI Tool")
    parser.add_argument("--key", type=str, help="License key to authenticate with")
    parser.add_argument("--api", type=str, default=DEFAULT_API, help="Base API server URL")
    parser.add_argument("--device", type=str, help="Custom device ID (default: persistent UUID)")
    parser.add_argument("--deactivate", action="store_true", help="Clear tokens and lock localConfig.json")
    parser.add_argument("--status", action="store_true", help="Check system status")
    parser.add_argument("--heartbeat", action="store_true", help="Send heartbeat using active session")
    args = parser.parse_args()

    if args.deactivate:
        deactivate()
        return

    if args.status:
        try:
            res = api_get(args.api, "/api/status")
            print("[+] Status response:")
            print(json.dumps(res, indent=2))
        except Exception as e:
            print(f"[-] Failed to get status from {args.api}: {e}")
        return

    device_id = args.device
    session_data = {}
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                session_data = json.load(f)
                if not device_id:
                    device_id = session_data.get("device_id")
        except Exception:
            pass

    if not device_id:
        device_id = str(uuid.uuid4()).upper()

    if args.heartbeat:
        session_token = session_data.get("session_token", "")
        if not session_token:
            print("[-] No active session found. Please run with --key first to authenticate.")
            sys.exit(1)
        try:
            res = api_post(args.api, "/api/heartbeat", {"device_id": device_id, "session_token": session_token})
            print("[+] Heartbeat response:")
            print(json.dumps(res, indent=2))
            if res.get("ok") and res.get("token"):
                for path in [LOCAL_CONFIG, DONEMAKE_CONFIG]:
                    cfg = load_config(path)
                    cfg["token"] = res["token"]
                    cfg["ts"] = res.get("ts", cfg.get("ts", 0))
                    cfg["system_active"] = res.get("system_active", True)
                    save_config(path, cfg)
                print("[+] Updated localConfig.json with refreshed token.")
        except Exception as e:
            print(f"[-] Heartbeat failed (API offline?): {e}")
            deactivate()
        return

    if not args.key:
        print("[-] Please specify a license key with --key, or use --status / --deactivate / --heartbeat.")
        sys.exit(1)

    print(f"[*] Authenticating key '{args.key}' with server {args.api}...")
    try:
        res = api_post(args.api, "/api/auth", {"key": args.key, "device_id": device_id})
    except urllib.error.URLError as e:
        print(f"[-] Connection error to {args.api}: {e}")
        print("[-] API server is offline or unreachable. Cannot activate offline.")
        deactivate()
        sys.exit(1)

    if not res.get("ok"):
        print(f"[-] Authentication failed: {res.get('error', 'unknown error')}")
        deactivate()
        sys.exit(1)

    print("[+] Authentication SUCCESSFUL!")
    token = res.get("token", "")
    ts = res.get("ts", 0)
    meomeo = res.get("meomeo", "")
    sig = res.get("sig", "")
    offsets = res.get("offsets", {})

    print(f"    Token: {token[:12]}... (len={len(token)})")
    print(f"    TS: {ts}")
    print(f"    Expires: {res.get('expires_at')}")
    print(f"    Device Expires: {res.get('device_expires')}")

    # Write session state
    save_config(STATE_FILE, {
        "device_id": device_id,
        "key": args.key,
        "session_token": res.get("session_token", ""),
        "expires_at": res.get("expires_at", "")
    })

    # Update localConfig.json files
    for path in [LOCAL_CONFIG, DONEMAKE_CONFIG]:
        cfg = load_config(path)
        cfg["meomeo"] = meomeo
        cfg["sig"] = sig
        cfg["token"] = token
        cfg["ts"] = ts
        cfg["system_active"] = True
        if offsets:
            for k, v in offsets.items():
                cfg[k] = v
        save_config(path, cfg)
        print(f"[+] Updated active config: {path}")

    print("[+] Done! Mod is now authenticated and active.")


if __name__ == "__main__":
    main()
