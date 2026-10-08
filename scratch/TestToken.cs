using System;

class TestToken
{
    private static readonly byte[] SecretKey = new byte[] {
        0x58, 0x75, 0x61, 0x6E, 0x54, 0x72, 0x75, 0x6E,
        0x5F, 0x56, 0x69, 0x70, 0x32, 0x30, 0x32, 0x36
    }; // XuanTrun_Vip2026

    private static uint Fnv1a32(byte[] data, int offset, int length, byte[] key)
    {
        uint h = 0x811c9dc5;
        for (int i = 0; i < length; i++)
        {
            h = (h ^ data[offset + i]) * 0x01000193;
        }
        for (int i = 0; i < key.Length; i++)
        {
            h = (h ^ key[i]) * 0x01000193;
        }
        return h;
    }

    public static bool DecryptToken(string hexStr, out uint ts, out byte status, out ushort features)
    {
        ts = 0;
        status = 0;
        features = 0;

        if (string.IsNullOrEmpty(hexStr) || hexStr.Length != 32)
        {
            return false;
        }

        byte[] block = new byte[16];
        for (int i = 0; i < 16; i++)
        {
            char c1 = hexStr[i * 2];
            char c2 = hexStr[i * 2 + 1];
            int v1 = (c1 >= '0' && c1 <= '9') ? (c1 - '0') : ((c1 >= 'a' && c1 <= 'f') ? (c1 - 'a' + 10) : ((c1 >= 'A' && c1 <= 'F') ? (c1 - 'A' + 10) : -1));
            int v2 = (c2 >= '0' && c2 <= '9') ? (c2 - '0') : ((c2 >= 'a' && c2 <= 'f') ? (c2 - 'a' + 10) : ((c2 >= 'A' && c2 <= 'F') ? (c2 - 'A' + 10) : -1));
            if (v1 == -1 || v2 == -1) return false;
            block[i] = (byte)((v1 << 4) | v2);
        }

        for (int r = 3; r >= 0; r--)
        {
            for (int i = 15; i >= 0; i--)
            {
                byte k = SecretKey[(i + r * 3) % 16];
                int b = block[i];
                b = ((b >> 3) | (b << 5)) & 0xFF;
                b = ((b - (i * 7 + r * 13)) ^ k) & 0xFF;
                block[i] = (byte)b;
            }
        }

        uint storedChecksum = (uint)(block[12] | (block[13] << 8) | (block[14] << 16) | (block[15] << 24));
        uint computedChecksum = Fnv1a32(block, 0, 12, SecretKey);

        if (storedChecksum != computedChecksum)
        {
            return false;
        }

        if (block[7] != 0x7E)
        {
            return false;
        }

        ts = (uint)(block[0] | (block[1] << 8) | (block[2] << 16) | (block[3] << 24));
        status = block[4];
        features = (ushort)(block[5] | (block[6] << 8));
        return true;
    }

    public static void Main()
    {
        string token = "cb6eb9266c11a5a30726c7e015b64239";
        uint ts;
        byte status;
        ushort features;
        bool ok = DecryptToken(token, out ts, out status, out features);
        Console.WriteLine("C# Decrypt ok: " + ok);
        Console.WriteLine("ts: " + ts);
        Console.WriteLine("status: " + status);
        Console.WriteLine("features: " + features);
        if (ok && ts == 1759463999 && status == 1 && features == 1023)
        {
            Console.WriteLine("C# and Python crypto 100% MATCH!");
        }
        else
        {
            Console.WriteLine("MISMATCH!");
        }
    }
}
