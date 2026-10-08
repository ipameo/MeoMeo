import sys
sys.path.insert(0, 'api')
import app

with app.app.app_context():
    db = app.get_db()
    # Insert a dummy expired key
    db.execute("INSERT OR REPLACE INTO license_keys (id, license_key, duration_days, active) VALUES (99999, 'EXPIRED-TEST-KEY', 1, 1)")
    db.execute("INSERT OR REPLACE INTO devices (id, device_id, license_key_id, expires_at) VALUES (99999, 'EXPIRED-DEV-999', 99999, '2020-01-01T00:00:00')")
    db.execute("INSERT OR REPLACE INTO sessions (device_id, session_token, meomeo, sig, expires_at) VALUES ('EXPIRED-DEV-999', 'token999', 'm', 's', '2020-01-01T00:00:00')")
    db.commit()
    print('Before purge - Key exists:', bool(db.execute("SELECT * FROM license_keys WHERE id=99999").fetchone()))
    deleted = app.purge_expired_keys(db)
    print('Purge deleted count:', deleted)
    print('After purge - Key exists:', bool(db.execute("SELECT * FROM license_keys WHERE id=99999").fetchone()))
    print('After purge - Device exists:', bool(db.execute("SELECT * FROM devices WHERE id=99999").fetchone()))
    print('After purge - Session exists:', bool(db.execute("SELECT * FROM sessions WHERE device_id='EXPIRED-DEV-999'").fetchone()))
