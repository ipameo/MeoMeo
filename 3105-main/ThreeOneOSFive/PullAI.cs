// ============================================================
//  PullAI.cs  —  ILFix patch source for 3105-main
//  Build target: Assembly-CSharp-patch.bytes (NOT encrypted)
//  Feature: Pull AI Player (magnetism aim-assist)
//  Config keys: PullAIEnabled / PullAIFov / PullAIStrength / PullAIBone
//  No-lỗi-dame guard: skip pull when world dist < MIN_SAFE_DIST (2.5m)
// ============================================================

using System;
using System.Collections.Generic;
using IFix.Core;
using UnityEngine;

namespace MeoPatch
{
    // ── Config reader ─────────────────────────────────────────
    // Reads JSON config written by libmeo.a into the game container
    // (same JSON used for EspMaster, FovSize, AimEnabled, etc.)
    internal static class PullAIConfig
    {
        internal static bool  Enabled   = false;
        internal static float Fov       = 80f;
        internal static float Strength  = 60f;
        internal static int   Bone      = 0;    // 0=head 1=neck 2=spine

        internal static void Refresh(string json)
        {
            if (string.IsNullOrEmpty(json)) return;
            Enabled  = json.Contains("\"PullAIEnabled\":true");
            Fov      = ParseFloat(json, "\"PullAIFov\":",      80f);
            Strength = ParseFloat(json, "\"PullAIStrength\":", 60f);
            Bone     = ParseInt  (json, "\"PullAIBone\":",     0);
        }

        static float ParseFloat(string json, string key, float def)
        {
            int idx = json.IndexOf(key, StringComparison.Ordinal);
            if (idx < 0) return def;
            int s = idx + key.Length, e = s;
            while (e < json.Length && (json[e] == '.' || (json[e] >= '0' && json[e] <= '9'))) e++;
            float v; return float.TryParse(json.Substring(s, e - s), out v) ? v : def;
        }

        static int ParseInt(string json, string key, int def)
        {
            int idx = json.IndexOf(key, StringComparison.Ordinal);
            if (idx < 0) return def;
            int s = idx + key.Length, e = s;
            while (e < json.Length && json[e] >= '0' && json[e] <= '9') e++;
            int v; return int.TryParse(json.Substring(s, e - s), out v) ? v : def;
        }
    }

    // ── Main Pull AI logic ────────────────────────────────────
    internal static class PullAIPlayer
    {
        // World-distance threshold under which pull is suppressed.
        // Enemy too close → server dame validation fails → lỗi dame.
        // 2.5 m is safe for all weapon types tested.
        const float MIN_SAFE_DIST = 2.5f;

        internal static void Tick(
            List<COW.GamePlay.Player> players,
            COW.GamePlay.Player       localPlayer,
            CGKJLKPMGDJ              aimSys,
            string                    configJson)
        {
            PullAIConfig.Refresh(configJson);

            if (!PullAIConfig.Enabled || players == null || localPlayer == null || aimSys == null)
            {
                aimSys.LockedAimingCollider = null;
                return;
            }

            Camera cam = Camera.main;
            if (cam == null) { aimSys.LockedAimingCollider = null; return; }

            float cx = Screen.width  * 0.5f;
            float cy = Screen.height * 0.5f;
            float fov = PullAIConfig.Fov;

            Collider bestCol  = null;
            float    bestDist = float.MaxValue;

            Vector3 origin = localPlayer.RootTransform != null
                ? localPlayer.RootTransform.position : Vector3.zero;

            foreach (var p in players)
            {
                if (p == null)           continue;
                if (p.IsLocalPlayer())   continue;
                if (p.IsLocalTeammate()) continue;
                if (p.CurHP <= 0f)       continue;

                // ── Target bone position ──────────────────────
                Transform boneTF;
                switch (PullAIConfig.Bone)
                {
                    case 1:  boneTF = p.NeckBone;           break;
                    case 2:  boneTF = p.SpineBoneTransform; break;
                    default: boneTF = p.GetHeadTF();        break;
                }
                if (boneTF == null) continue;

                Vector3 bonePos = boneTF.position;

                // ── Close-range dame guard ────────────────────
                if (Vector3.Distance(origin, bonePos) < MIN_SAFE_DIST) continue;

                // ── World → screen ────────────────────────────
                Vector3 sp = cam.WorldToScreenPoint(bonePos);
                if (sp.z <= 0f) continue;   // behind camera

                float dx = sp.x - cx;
                float dy = (Screen.height - sp.y) - cy;   // flip Y
                float d2d = Mathf.Sqrt(dx * dx + dy * dy);

                if (d2d >= fov || d2d >= bestDist) continue;

                // ── Pick closest FireCollider to target bone ──
                var cols = p.FireColliders;
                if (cols == null || cols.Count == 0) continue;

                Collider picked = null;
                float    pd     = float.MaxValue;
                foreach (var c in cols)
                {
                    if (c == null) continue;
                    float cd = Vector3.Distance(c.bounds.center, bonePos);
                    if (cd < pd) { pd = cd; picked = c; }
                }
                if (picked == null) continue;

                bestDist = d2d;
                bestCol  = picked;
            }

            // Apply pull — game lerps reticle toward LockedAimingCollider automatically
            aimSys.LockedAimingCollider = bestCol;
        }
    }

    // ── ILFix hook ────────────────────────────────────────────
    // Patches CGKJLKPMGDJ.Update() (the aim-system tick).
    // Existing silent-aim / aimbot logic runs AFTER Pull AI.
    [Patch]
    static class __PullAI_Hook
    {
        [IFix.Interpret]
        static void Update(CGKJLKPMGDJ __this)
        {
            // Read config from persistent storage (same path as rest of mod)
            string cfgJson = "";
            try
            {
                string path = Application.persistentDataPath + "/meo_config.json";
                if (System.IO.File.Exists(path))
                    cfgJson = System.IO.File.ReadAllText(path);
            }
            catch { }

            var match       = ILPNGCMEFFI.CurrentMatch;
            var localPlayer = ILPNGCMEFFI.CurrentLocalPlayer;
            var players     = match != null ? match.GetAllPlayers() : null;

            // Pull AI runs first — locks collider before original silent-aim reads it
            PullAIPlayer.Tick(players, localPlayer, __this, cfgJson);

            // Chain to original Update() body (silent-aim + aimbot)
            __this.ILPNGCMEFFI();
        }
    }
}
