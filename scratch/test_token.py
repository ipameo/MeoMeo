"""
Test token encryption in Python and verify it produces the exact same result in C#.
"""
import struct
import binascii

SECRET_KEY = bytes([0x58, 0x75, 0x61, 0x6E, 0x54, 0x72, 0x75, 0x6E, 0x5F, 0x56, 0x69, 0x70, 0x32, 0x30, 0x32, 0x36]) # XuanTrun_Vip2026

def fnv1a_32(data: bytes, key: bytes) -> int:
    h = 0x811c9dc5
    for b in data:
        h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF
    for b in key:
        h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF
    return h

def encrypt_token(ts: int, status: int, features_mask: int, nonce: int) -> str:
    # 12 bytes payload:
    # ts: 4 bytes (uint32 LE)
    # status: 1 byte
    # features_low: 1 byte
    # features_high: 1 byte
    # marker: 1 byte (0x7E)
    # nonce: 4 bytes (uint32 LE)
    feat_low = features_mask & 0xFF
    feat_high = (features_mask >> 8) & 0xFF
    payload = struct.pack("<IBBBBI", ts, status, feat_low, feat_high, 0x7E, nonce)
    
    # 4 bytes checksum
    checksum = fnv1a_32(payload, SECRET_KEY)
    block = bytearray(payload + struct.pack("<I", checksum))
    
    # Encrypt 16 bytes with multi-round XOR + rotation using SECRET_KEY
    for r in range(4):
        for i in range(16):
            k = SECRET_KEY[(i + r * 3) % 16]
            block[i] = ((block[i] ^ k) + (i * 7 + r * 13)) & 0xFF
            block[i] = ((block[i] << 3) | (block[i] >> 5)) & 0xFF
            
    return block.hex()

def decrypt_token(hex_str: str):
    if len(hex_str) != 32:
        return None
    try:
        block = bytearray(bytes.fromhex(hex_str))
    except Exception:
        return None
        
    for r in range(3, -1, -1):
        for i in range(15, -1, -1):
            k = SECRET_KEY[(i + r * 3) % 16]
            b = block[i]
            b = ((b >> 3) | (b << 5)) & 0xFF
            b = ((b - (i * 7 + r * 13)) ^ k) & 0xFF
            block[i] = b
            
    payload = bytes(block[:12])
    stored_checksum = struct.unpack("<I", block[12:16])[0]
    computed_checksum = fnv1a_32(payload, SECRET_KEY)
    if stored_checksum != computed_checksum:
        return None
        
    ts, status, feat_low, feat_high, marker, nonce = struct.unpack("<IBBBBI", payload)
    if marker != 0x7E:
        return None
    features = feat_low | (feat_high << 8)
    return {
        "ts": ts,
        "status": status,
        "features": features,
        "nonce": nonce
    }

if __name__ == "__main__":
    ts = 1759463999
    status = 1
    features = 0x03FF # all features on
    nonce = 0x12345678
    
    token = encrypt_token(ts, status, features, nonce)
    print("Generated token:", token)
    dec = decrypt_token(token)
    print("Decrypted in Python:", dec)
    assert dec["ts"] == ts
    assert dec["status"] == status
    assert dec["features"] == features
    print("Python crypto test passed!")
