using System;
using System.Collections;
using System.Reflection;
using COW;
using COW.GamePlay;
using UnityEngine;

namespace ProjectEspPatch
{
    public static class Logic
    {
        private const int EspMaster = 1;
        private const int EspBox = 2;
        private const int EspTracer = 4;
        private const int EspHealth = 8;
        private const int EspName = 16;
        private const int EspDistance = 32;
        private const int EspFov = 64;
        private const int EspMask = 127;

        private const int StateInitialized = 128;
        private const int StateThreeFinger = 256;
        private const int StateDragging = 512;
        private const int TabShift = 10;
        private const int TabMask = 3072;
        private const int TapShift = 12;
        private const int TapMask = 28672;
        private const int AimEnabled = 32768;
        private const int AimModeShift = 16;
        private const int AimModeMask = 196608;
        private const int NoRecoil = 262144;
        private const int HeadRateShift = 19;
        private const int HeadRateMask = 3670016;
        private const int AimSystemEnabled = 4194304;
        private const int AimSystemHead = 8388608;
        private const int AimActionSilentToggle = 1;
        private const int AimActionSystemToggle = 2;
        private const int AimActionSilentTarget = 3;
        private const int AimActionHeadRate = 4;
        private const int AimActionFov = 5;
        private const int AimActionSystemTarget = 6;
        private const int AimActionNoRecoil = 7;
        private const int AimActionFovRadius = 8;
        private const int AuxSkeleton = 1;
        private const int AuxFovRadiusMask = 248;
        private const int AuxFovRadiusShift = 3;
        private const int AuxMask = 255;
        private const int AuxTickShift = 8;
        private const float AuxStateMarker = 1000000f;
        private const int DefaultAimState = AimEnabled | (2 << AimModeShift)
            | (3 << HeadRateShift);
        // Deprecated speed type binding: {{SPEED_TYPE}}

        // GhostWindow removed

        // ── API Server Endpoints & Licensing ──────────────────────────────────
        public const string ApiServerUrl = "http://103.238.234.204:2007";
        public const string ApiHeartbeatUrl = "http://103.238.234.204:2007/api/heartbeat";
        public const string ApiStatusUrl = "http://103.238.234.204:2007/api/status";
        public const string ApiAuthUrl = "http://103.238.234.204:2007/api/auth";

        
        // ── Class Quản Lý Class & Offset API ─────────────────────────────────
        public class ApiOffsets
        {
            public string MATCH_TYPE = "{{MATCH_TYPE}}";
            public string MATCH_PLAYERS_METHOD = "{{MATCH_PLAYERS_METHOD}}";
            public string AIM_INFO_TYPE = "{{AIM_INFO_TYPE}}";
            public string PLAYER_AIM_INFO_FIELD = "{{PLAYER_AIM_INFO_FIELD}}";
            public string SCENE_MENU_FIELD = "{{SCENE_MENU_FIELD}}";
            public string SCENE_POSITION_FIELD = "{{SCENE_POSITION_FIELD}}";
            public string SCENE_STATE_FIELD = "{{SCENE_STATE_FIELD}}";
            public string AIM_GAME_OBJECT_FIELD = "{{AIM_GAME_OBJECT_FIELD}}";
            public string AIM_COLLIDER_FIELD = "{{AIM_COLLIDER_FIELD}}";
            public string AIM_HIT_POSITION_FIELD = "{{AIM_HIT_POSITION_FIELD}}";
            public string AIM_TRACE_POSITION_FIELD = "{{AIM_TRACE_POSITION_FIELD}}";
            public string AIM_DIRECTION_FIELD = "{{AIM_DIRECTION_FIELD}}";
            public string AIM_ORIGIN_FIELD = "{{AIM_ORIGIN_FIELD}}";
            public string AIM_HIT_TYPE = "{{AIM_HIT_TYPE}}";
            public string AIM_HIT_TYPE_FIELD = "{{AIM_HIT_TYPE_FIELD}}";
            public string AIM_FLAG_A_FIELD = "{{AIM_FLAG_A_FIELD}}";
            public string AIM_FLAG_B_FIELD = "{{AIM_FLAG_B_FIELD}}";
            public string AIM_SECONDARY_ORIGIN_FIELD = "{{AIM_SECONDARY_ORIGIN_FIELD}}";
            public string AIM_SHORT_FIELD = "{{AIM_SHORT_FIELD}}";
            public string SPEED_TYPE = "{{SPEED_TYPE}}";
        }

        public static ApiOffsets Offsets = new ApiOffsets();

        private static float _lastOffsetFetchTime = 0f;
        private static bool _isFetchingOffsets = false;

        public static string GetOffsetsFromAPI()
        {
            if (!_isFetchingOffsets && (Time.realtimeSinceStartup - _lastOffsetFetchTime > 60f || _lastOffsetFetchTime == 0f))
            {
                _lastOffsetFetchTime = Time.realtimeSinceStartup;
                _isFetchingOffsets = true;
                try
                {
                    new System.Threading.Thread(new System.Threading.ThreadStart(delegate
                    {
                        try
                        {
                            using (System.Net.WebClient wc = new System.Net.WebClient())
                            {
                                wc.Headers[System.Net.HttpRequestHeader.ContentType] = "application/json";
                                string json = wc.DownloadString(ApiServerUrl + "/api/offsets?version=default");
                                if (!string.IsNullOrEmpty(json) && json.Contains("\"ok\":true") && json.Contains("\"data\":"))
                                {
                                    UpdateOffsetsFromJson(json);
                                    try
                                    {
                                        string cachePath = Application.persistentDataPath + "/offsets_cache.json";
                                        System.IO.File.WriteAllText(cachePath, json);
                                    }
                                    catch { }
                                }
                            }
                        }
                        catch { }
                        finally
                        {
                            _isFetchingOffsets = false;
                        }
                    })).Start();
                }
                catch
                {
                    _isFetchingOffsets = false;
                }
            }

            try
            {
                string cachePath = Application.persistentDataPath + "/offsets_cache.json";
                if (System.IO.File.Exists(cachePath))
                {
                    string content = System.IO.File.ReadAllText(cachePath);
                    UpdateOffsetsFromJson(content);
                    return content;
                }
                string configPath = Application.persistentDataPath + "/localConfig.json";
                if (System.IO.File.Exists(configPath))
                {
                    string content = System.IO.File.ReadAllText(configPath);
                    UpdateOffsetsFromJson(content);
                    return content;
                }
            }
            catch { }
            return "";
        }

        private static void UpdateOffsetsFromJson(string json)
        {
            if (string.IsNullOrEmpty(json)) return;
            try
            {
                Offsets.MATCH_TYPE = ExtractJsonValue(json, "MATCH_TYPE", Offsets.MATCH_TYPE);
                Offsets.MATCH_PLAYERS_METHOD = ExtractJsonValue(json, "MATCH_PLAYERS_METHOD", Offsets.MATCH_PLAYERS_METHOD);
                Offsets.AIM_INFO_TYPE = ExtractJsonValue(json, "AIM_INFO_TYPE", Offsets.AIM_INFO_TYPE);
                Offsets.PLAYER_AIM_INFO_FIELD = ExtractJsonValue(json, "PLAYER_AIM_INFO_FIELD", Offsets.PLAYER_AIM_INFO_FIELD);
                Offsets.SCENE_MENU_FIELD = ExtractJsonValue(json, "SCENE_MENU_FIELD", Offsets.SCENE_MENU_FIELD);
                Offsets.SCENE_POSITION_FIELD = ExtractJsonValue(json, "SCENE_POSITION_FIELD", Offsets.SCENE_POSITION_FIELD);
                Offsets.SCENE_STATE_FIELD = ExtractJsonValue(json, "SCENE_STATE_FIELD", Offsets.SCENE_STATE_FIELD);
                Offsets.AIM_GAME_OBJECT_FIELD = ExtractJsonValue(json, "AIM_GAME_OBJECT_FIELD", Offsets.AIM_GAME_OBJECT_FIELD);
                Offsets.AIM_COLLIDER_FIELD = ExtractJsonValue(json, "AIM_COLLIDER_FIELD", Offsets.AIM_COLLIDER_FIELD);
                Offsets.AIM_HIT_POSITION_FIELD = ExtractJsonValue(json, "AIM_HIT_POSITION_FIELD", Offsets.AIM_HIT_POSITION_FIELD);
                Offsets.AIM_TRACE_POSITION_FIELD = ExtractJsonValue(json, "AIM_TRACE_POSITION_FIELD", Offsets.AIM_TRACE_POSITION_FIELD);
                Offsets.AIM_DIRECTION_FIELD = ExtractJsonValue(json, "AIM_DIRECTION_FIELD", Offsets.AIM_DIRECTION_FIELD);
                Offsets.AIM_ORIGIN_FIELD = ExtractJsonValue(json, "AIM_ORIGIN_FIELD", Offsets.AIM_ORIGIN_FIELD);
                Offsets.AIM_HIT_TYPE = ExtractJsonValue(json, "AIM_HIT_TYPE", Offsets.AIM_HIT_TYPE);
                Offsets.AIM_HIT_TYPE_FIELD = ExtractJsonValue(json, "AIM_HIT_TYPE_FIELD", Offsets.AIM_HIT_TYPE_FIELD);
                Offsets.AIM_FLAG_A_FIELD = ExtractJsonValue(json, "AIM_FLAG_A_FIELD", Offsets.AIM_FLAG_A_FIELD);
                Offsets.AIM_FLAG_B_FIELD = ExtractJsonValue(json, "AIM_FLAG_B_FIELD", Offsets.AIM_FLAG_B_FIELD);
                Offsets.AIM_SECONDARY_ORIGIN_FIELD = ExtractJsonValue(json, "AIM_SECONDARY_ORIGIN_FIELD", Offsets.AIM_SECONDARY_ORIGIN_FIELD);
                Offsets.AIM_SHORT_FIELD = ExtractJsonValue(json, "AIM_SHORT_FIELD", Offsets.AIM_SHORT_FIELD);
                Offsets.SPEED_TYPE = ExtractJsonValue(json, "SPEED_TYPE", Offsets.SPEED_TYPE);
            }
            catch { }
        }

        private static string ExtractJsonValue(string json, string key, string fallback)
        {
            string needle = "\"" + key + "\"";
            int idx = json.IndexOf(needle);
            if (idx < 0) return fallback;
            int colon = json.IndexOf(':', idx + needle.Length);
            if (colon < 0) return fallback;
            int quoteStart = json.IndexOf('\"', colon + 1);
            if (quoteStart < 0) return fallback;
            int quoteEnd = json.IndexOf('\"', quoteStart + 1);
            if (quoteEnd < 0) return fallback;
            return json.Substring(quoteStart + 1, quoteEnd - quoteStart - 1);
        }

        public static bool Bootstrap(Player self)
        {
            if (self == null)
            {
                return false;
            }
            bool stealthState;
            try
            {
                stealthState = self.IsInStealth();
                if (Time.frameCount % 15 != 0)
                {
                    return stealthState;
                }
                GameObject driver = GameObject.Find("__esp_driver");
                bool createdDriver = false;
                if (driver == null)
                {
                    Camera camera = Camera.main;
                    Transform legacyFov = camera == null
                        ? null
                        : camera.transform.Find("__esp_fov");
                    if (legacyFov != null)
                    {
                        UnityEngine.Object.Destroy(legacyFov.gameObject);
                    }
                    driver = new GameObject("__esp_driver");
                    createdDriver = true;
                }

                Component component = driver.GetComponent(typeof(SceneEditBoxSelectTool));
                if (component == null)
                {
                    component = driver.AddComponent(typeof(SceneEditBoxSelectTool));
                }
                if (component == null)
                {
                    if (createdDriver)
                    {
                        UnityEngine.Object.Destroy(driver);
                    }
                }
                else
                {
                    if (createdDriver)
                    {
                        UnityEngine.Object.DontDestroyOnLoad(driver);
                    }
                }
            }
            catch (Exception)
            {
                stealthState = false;
            }
            return stealthState;
        }

        // {{SCENE_MENU_FIELD}}
        public static void Draw(SceneEditBoxSelectTool self)
        {
            if (self == null)
            {
                return;
            }
            Event currentEvent = Event.current;
            if (currentEvent == null)
            {
                return;
            }

            GameObject driverObject = self.gameObject;
            if (driverObject == null || driverObject.name != "__esp_driver")
            {
                return;
            }

            bool menuFlag = self.{{SCENE_MENU_FIELD}};

            int screenWidth = Screen.width;
            int screenHeight = Screen.height;
            string docDir = Application.persistentDataPath;
            string flagPath = !string.IsNullOrEmpty(docDir) ? (docDir + "/reset_guest.flag") : "";
            Rect guestBtnRect = new Rect((float)screenWidth - 175f, 15f, 160f, 38f);
            bool triggerGuestReset = false;
            bool showGuestBtn = PlayerPrefs.GetInt("ESP_ShowGuestBtn", 1) == 1;

            if (!string.IsNullOrEmpty(flagPath) && System.IO.File.Exists(flagPath))
            {
                triggerGuestReset = true;
            }

            if (showGuestBtn && Input.GetMouseButtonDown(0))
            {
                Vector3 mp = Input.mousePosition;
                float tx = mp.x;
                float ty = (float)screenHeight - mp.y;
                if (tx >= guestBtnRect.x && tx <= guestBtnRect.x + guestBtnRect.width &&
                    ty >= guestBtnRect.y && ty <= guestBtnRect.y + guestBtnRect.height)
                {
                    triggerGuestReset = true;
                }
            }
            
            // Drag and Drop Logic for Ghost Button
            if (PlayerPrefs.GetInt("ESP_GhostMode", 0) == 1)
            {
                float gX = PlayerPrefs.GetFloat("GhostBtnX", 20f);
                float gY = PlayerPrefs.GetFloat("GhostBtnY", 100f);
                Rect ghostBtnRect = new Rect(gX, gY, 130f, 40f);
                
                Vector3 mp = Input.mousePosition;
                float tx = mp.x;
                float ty = (float)screenHeight - mp.y;
                
                bool isDragging = PlayerPrefs.GetInt("GhostDragging", 0) == 1;
                float offX = PlayerPrefs.GetFloat("GhostOffX", 0f);
                float offY = PlayerPrefs.GetFloat("GhostOffY", 0f);

                if (Input.GetMouseButtonDown(0))
                {
                    if (tx >= ghostBtnRect.x && tx <= ghostBtnRect.x + ghostBtnRect.width &&
                        ty >= ghostBtnRect.y && ty <= ghostBtnRect.y + ghostBtnRect.height)
                    {
                        PlayerPrefs.SetInt("GhostDragging", 1);
                        PlayerPrefs.SetFloat("GhostOffX", tx - ghostBtnRect.x);
                        PlayerPrefs.SetFloat("GhostOffY", ty - ghostBtnRect.y);
                    }
                }
                else if (Input.GetMouseButtonUp(0))
                {
                    if (isDragging)
                    {
                        PlayerPrefs.SetInt("GhostDragging", 0);
                        // Toggle ghost active
                        int currentActive = PlayerPrefs.GetInt("ESP_GhostActive", 0);
                        PlayerPrefs.SetInt("ESP_GhostActive", currentActive == 1 ? 0 : 1);
                    }
                }
                
                if (isDragging && Input.GetMouseButton(0))
                {
                    PlayerPrefs.SetFloat("GhostBtnX", tx - offX);
                    PlayerPrefs.SetFloat("GhostBtnY", ty - offY);
                }
            }

            float lastUpdate = self.{{SCENE_STATE_FIELD}}.x;
            if (Time.realtimeSinceStartup - lastUpdate > 1.2f || lastUpdate == 0)
            {
                self.{{SCENE_STATE_FIELD}} = new Vector2(Time.realtimeSinceStartup, self.{{SCENE_STATE_FIELD}}.y);
                try
                {
                    string configPath = Application.persistentDataPath + "/localConfig.json";
                    if (!System.IO.File.Exists(configPath) && !string.IsNullOrEmpty(docDir))
                    {
                        if (System.IO.File.Exists(docDir + "/Documents/localConfig.json")) configPath = docDir + "/Documents/localConfig.json";
                        else if (System.IO.File.Exists(docDir + "/../Documents/localConfig.json")) configPath = docDir + "/../Documents/localConfig.json";
                    }
                    if (System.IO.File.Exists(configPath))
                    {
                        string json = System.IO.File.ReadAllText(configPath).Replace(" ", "");
                        if (json.Contains("\"ShowGuestBtn\":false") || json.Contains("\"showGuestBtn\":false"))
                        {
                            showGuestBtn = false;
                            PlayerPrefs.SetInt("ESP_ShowGuestBtn", 0);
                        }
                        else
                        {
                            showGuestBtn = true;
                            PlayerPrefs.SetInt("ESP_ShowGuestBtn", 1);
                        }

                        if (json.Contains("\"reset_guest\":true") || json.Contains("\"resetGuest\":true") || json.Contains("\"resetGuestBeforeLogin\":true") || json.Contains("\"ResetGuestEnabled\":true") || json.Contains("\"AutoResetGuest\":true"))
                        {
                            triggerGuestReset = true;
                        }

                        if (triggerGuestReset)
                        {
                            try
                            {
                                // 1. Reset Garena MSDK Guest session
                                try
                                {
                                    Type mgrType = Type.GetType("GarenaMSDK.GarenaMSDKMgr, Assembly-CSharp");
                                    if (mgrType == null)
                                    {
                                        foreach (Assembly asm in AppDomain.CurrentDomain.GetAssemblies())
                                        {
                                            mgrType = asm.GetType("GarenaMSDK.GarenaMSDKMgr");
                                            if (mgrType != null) break;
                                        }
                                    }
                                    if (mgrType != null)
                                    {
                                        PropertyInfo instProp = mgrType.GetProperty("Instance", BindingFlags.Public | BindingFlags.Static);
                                        object inst = instProp != null ? instProp.GetValue(null, null) : null;
                                        if (inst == null)
                                        {
                                            inst = UnityEngine.Object.FindObjectOfType(mgrType);
                                        }
                                        if (inst != null)
                                        {
                                            MethodInfo resetMethod = mgrType.GetMethod("ResetGuest", BindingFlags.Public | BindingFlags.Instance);
                                            if (resetMethod != null) resetMethod.Invoke(inst, null);

                                            PropertyInfo p1 = mgrType.GetProperty("GuestOpenID");
                                            if (p1 != null && p1.CanWrite) p1.SetValue(inst, string.Empty, null);
                                            PropertyInfo p2 = mgrType.GetProperty("GuestAccessToken");
                                            if (p2 != null && p2.CanWrite) p2.SetValue(inst, string.Empty, null);
                                            PropertyInfo p3 = mgrType.GetProperty("OpenID");
                                            if (p3 != null && p3.CanWrite) p3.SetValue(inst, string.Empty, null);
                                            PropertyInfo p4 = mgrType.GetProperty("AccessToken");
                                            if (p4 != null && p4.CanWrite) p4.SetValue(inst, string.Empty, null);

                                            FieldInfo bindF = mgrType.GetField("sdkBind", BindingFlags.NonPublic | BindingFlags.Instance);
                                            object sdkBindObj = bindF != null ? bindF.GetValue(inst) : null;
                                            if (sdkBindObj != null)
                                            {
                                                MethodInfo bindReset = sdkBindObj.GetType().GetMethod("ResetGuest", BindingFlags.Public | BindingFlags.Instance);
                                                if (bindReset != null) bindReset.Invoke(sdkBindObj, null);
                                            }
                                        }
                                        MethodInfo nativeReset = mgrType.GetMethod("GarenaMSDK_ResetGuest", BindingFlags.NonPublic | BindingFlags.Static);
                                        if (nativeReset != null) nativeReset.Invoke(null, null);
                                    }
                                }
                                catch { }

                                try
                                {
                                    Type bindType = Type.GetType("GarenaMSDK.SDKBind, Assembly-CSharp");
                                    if (bindType != null)
                                    {
                                        MethodInfo resetBind = bindType.GetMethod("ResetGuest", BindingFlags.Public | BindingFlags.Static | BindingFlags.Instance);
                                        if (resetBind != null) resetBind.Invoke(null, null);
                                        MethodInfo nativeReset2 = bindType.GetMethod("GarenaMSDK_ResetGuest", BindingFlags.NonPublic | BindingFlags.Static);
                                        if (nativeReset2 != null) nativeReset2.Invoke(null, null);
                                    }
                                }
                                catch { }

                                // 2. Clear UIModelLogin cookie & session
                                try
                                {
                                    Type loginType = Type.GetType("COW.UIModelLogin, Assembly-CSharp");
                                    if (loginType != null)
                                    {
                                        UnityEngine.Object[] objs = UnityEngine.Object.FindObjectsOfType(loginType);
                                        for (int li = 0; li < objs.Length; li++)
                                        {
                                            object lObj = objs[li];
                                            if (lObj != null)
                                            {
                                                MethodInfo clearCookie = loginType.GetMethod("ClearCookie", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                                                if (clearCookie != null) clearCookie.Invoke(lObj, null);
                                                MethodInfo clearAfterLogout = loginType.GetMethod("ClearAfterLogout", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                                                if (clearAfterLogout != null) clearAfterLogout.Invoke(lObj, null);
                                            }
                                        }
                                    }
                                }
                                catch { }

                                // 3. Set COW.GameConfig.m_LocalConfig flags
                                try
                                {
                                    Type gameCfgType = Type.GetType("COW.GameConfig, Assembly-CSharp");
                                    if (gameCfgType != null)
                                    {
                                        FieldInfo localCfgField = gameCfgType.GetField("m_LocalConfig", BindingFlags.NonPublic | BindingFlags.Static);
                                        object localCfgObj = localCfgField != null ? localCfgField.GetValue(null) : null;
                                        if (localCfgObj != null)
                                        {
                                            FieldInfo rgField = localCfgObj.GetType().GetField("resetGuest");
                                            if (rgField != null) rgField.SetValue(localCfgObj, true);
                                            FieldInfo rgblField = localCfgObj.GetType().GetField("resetGuestBeforeLogin");
                                            if (rgblField != null) rgblField.SetValue(localCfgObj, true);
                                            FieldInfo tcpField = localCfgObj.GetType().GetField("testCodePatch");
                                            if (tcpField != null) tcpField.SetValue(localCfgObj, true);
                                        }
                                    }
                                }
                                catch { }

                                // 4. Clear all PlayerPrefs and Garena specific keys
                                try
                                {
                                    string[] garenaKeys = new string[] {
                                        "GarenaGuestOpenID", "GuestAccessToken", "GarenaSDK_DeviceId", "MSDK_DEVICE_ID",
                                        "GMSDK_DEVICE_KEY", "GMSDK_KEYCHAIN_KEY", "GarenaDeviceUUID", "GarenaOpenID",
                                        "AutoLoginType", "LastLoginType", "device_fingerprint", "app_device_id",
                                        "guest_account", "ff_guest_id", "guest_openid", "guest_token", "login_token",
                                        "last_login_token", "save_account", "user_account", "com.garena.game.uuid",
                                        "UnityUUID", "unity.cloud_userid", "IDFV", "g_id", "guest", "GOPDeviceID"
                                    };
                                    for (int ki = 0; ki < garenaKeys.Length; ki++)
                                    {
                                        try { PlayerPrefs.DeleteKey(garenaKeys[ki]); } catch { }
                                    }
                                    PlayerPrefs.DeleteAll();
                                    PlayerPrefs.Save();
                                }
                                catch { }

                                // 5. Wipe all guest & device files from persistent storage
                                if (!string.IsNullOrEmpty(docDir) && System.IO.Directory.Exists(docDir))
                                {
                                    try
                                    {
                                        string[] allF = System.IO.Directory.GetFiles(docDir, "*.*", System.IO.SearchOption.AllDirectories);
                                        for (int fi = 0; fi < allF.Length; fi++)
                                        {
                                            string fn = System.IO.Path.GetFileName(allF[fi]).ToLower();
                                            if (fn == "assembly-csharp-patch.bytes" || fn == "localconfig.json")
                                            {
                                                continue;
                                            }
                                            if (fn.Contains("guest") || fn.Contains("account") || fn.Contains("g_id") || fn.Contains("app_data") || fn.Contains("device") || fn.Contains("token") || fn.Contains("login") || fn.EndsWith(".dat") || fn.EndsWith(".plist"))
                                            {
                                                try { System.IO.File.Delete(allF[fi]); } catch { }
                                            }
                                        }
                                    }
                                    catch { }

                                    // 6. Seed brand new random device id into app_device_id.dat AND g_id.dat
                                    try
                                    {
                                        string newDeviceId = System.Guid.NewGuid().ToString("N");
                                        System.IO.File.WriteAllText(docDir + "/app_device_id.dat", newDeviceId);
                                        System.IO.File.WriteAllText(docDir + "/g_id.dat", newDeviceId);
                                    }
                                    catch { }

                                    // 7. Delete reset flag file
                                    try
                                    {
                                        if (System.IO.File.Exists(flagPath))
                                        {
                                            System.IO.File.Delete(flagPath);
                                        }
                                    }
                                    catch { }

                                    // 8. Update localConfig.json to mark reset_guest as false
                                    try
                                    {
                                        if (System.IO.File.Exists(configPath))
                                        {
                                            string cText = System.IO.File.ReadAllText(configPath);
                                            string updated = cText.Replace("\"reset_guest\":true", "\"reset_guest\":false")
                                                                 .Replace("\"resetGuest\":true", "\"resetGuest\":false")
                                                                 .Replace("\"resetGuestBeforeLogin\":true", "\"resetGuestBeforeLogin\":false")
                                                                 .Replace("\"reset_guest\" : true", "\"reset_guest\" : false")
                                                                 .Replace("\"resetGuest\" : true", "\"resetGuest\" : false")
                                                                 .Replace("\"resetGuestBeforeLogin\" : true", "\"resetGuestBeforeLogin\" : false")
                                                                 .Replace("\"reset_guest\": true", "\"reset_guest\": false")
                                                                 .Replace("\"resetGuest\": true", "\"resetGuest\": false")
                                                                 .Replace("\"resetGuestBeforeLogin\": true", "\"resetGuestBeforeLogin\": false");
                                            System.IO.File.WriteAllText(configPath, updated);
                                            json = updated.Replace(" ", "");
                                        }
                                    }
                                    catch { }
                                }

                                // 9. Store feedback time
                                self.{{SCENE_STATE_FIELD}} = new Vector2(self.{{SCENE_STATE_FIELD}}.x, Time.realtimeSinceStartup);
                            }
                            catch { }
                        }
                        
                        bool serverActive = true;
                        if (json.Contains("\"system_active\":false") || json.Contains("\"system_active\":0") ||
                            json.Contains("\"server_active\":false") || json.Contains("\"server_active\":0") ||
                            json.Contains("\"active\":false") || json.Contains("\"active\":0"))
                        {
                            serverActive = false;
                        }

                        // Ensure COW.GameConfig.m_LocalConfig.testCodePatch = true
                        try
                        {
                            Type gameCfgType = Type.GetType("COW.GameConfig, Assembly-CSharp");
                            if (gameCfgType != null)
                            {
                                FieldInfo localCfgField = gameCfgType.GetField("m_LocalConfig", BindingFlags.NonPublic | BindingFlags.Static);
                                object localCfgObj = localCfgField != null ? localCfgField.GetValue(null) : null;
                                if (localCfgObj != null)
                                {
                                    FieldInfo tcpField = localCfgObj.GetType().GetField("testCodePatch");
                                    if (tcpField != null) tcpField.SetValue(localCfgObj, true);
                                }
                            }
                        }
                        catch { }

                        // API server binding reference: "http://103.238.234.204:2007"
                        if (json.Contains("http://103.238.234.204:2007"))
                        {
                            // Verified host
                        }

                        // Read token (32-char encrypted hex block from API)
                        string tokenVal = "";
                        int tkIdx = json.IndexOf("\"token\":\"");
                        if (tkIdx != -1)
                        {
                            int tkStart = tkIdx + 9;
                            int tkEnd = json.IndexOf('"', tkStart);
                            if (tkEnd != -1)
                            {
                                tokenVal = json.Substring(tkStart, tkEnd - tkStart);
                            }
                        }

                        // Decrypt and verify 32-char hex token directly inlined (no external methods)
                        bool tokenDecrypted = false;
                        uint tokenTs = 0;
                        byte tokenStatus = 0;
                        ushort tokenFeat = 0;
                        uint userToggles = 0;

                        if (!string.IsNullOrEmpty(tokenVal) && tokenVal.Length == 32)
                        {
                            byte[] secKey = new byte[16];
                            secKey[0] = 0x58; secKey[1] = 0x75; secKey[2] = 0x61; secKey[3] = 0x6E;
                            secKey[4] = 0x54; secKey[5] = 0x72; secKey[6] = 0x75; secKey[7] = 0x6E;
                            secKey[8] = 0x5F; secKey[9] = 0x56; secKey[10] = 0x69; secKey[11] = 0x70;
                            secKey[12] = 0x32; secKey[13] = 0x30; secKey[14] = 0x32; secKey[15] = 0x36;
                            byte[] block = new byte[16];
                            bool hexOk = true;
                            for (int i = 0; i < 16; i++)
                            {
                                char c1 = tokenVal[i * 2];
                                char c2 = tokenVal[i * 2 + 1];
                                int v1 = (c1 >= '0' && c1 <= '9') ? (c1 - '0') : ((c1 >= 'a' && c1 <= 'f') ? (c1 - 'a' + 10) : ((c1 >= 'A' && c1 <= 'F') ? (c1 - 'A' + 10) : -1));
                                int v2 = (c2 >= '0' && c2 <= '9') ? (c2 - '0') : ((c2 >= 'a' && c2 <= 'f') ? (c2 - 'a' + 10) : ((c2 >= 'A' && c2 <= 'F') ? (c2 - 'A' + 10) : -1));
                                if (v1 == -1 || v2 == -1) { hexOk = false; break; }
                                block[i] = (byte)((v1 << 4) | v2);
                            }

                            if (hexOk)
                            {
                                for (int r = 3; r >= 0; r--)
                                {
                                    for (int i = 15; i >= 0; i--)
                                    {
                                        byte k = secKey[(i + r * 3) % 16];
                                        int b = block[i];
                                        b = ((b >> 3) | (b << 5)) & 0xFF;
                                        b = ((b - (i * 7 + r * 13)) ^ k) & 0xFF;
                                        block[i] = (byte)b;
                                    }
                                }

                                uint storedChecksum = (uint)(block[12] | (block[13] << 8) | (block[14] << 16) | (block[15] << 24));
                                uint computedChecksum = 0x811c9dc5;
                                for (int i = 0; i < 12; i++)
                                {
                                    computedChecksum = (computedChecksum ^ block[i]) * 0x01000193;
                                }
                                for (int i = 0; i < 16; i++)
                                {
                                    computedChecksum = (computedChecksum ^ secKey[i]) * 0x01000193;
                                }

                                if (storedChecksum == computedChecksum && block[7] == 0x7E)
                                {
                                    tokenTs = (uint)(block[0] | (block[1] << 8) | (block[2] << 16) | (block[3] << 24));
                                    tokenStatus = block[4];
                                    tokenFeat = (ushort)(block[5] | (block[6] << 8));
                                    userToggles = (uint)(block[8] | (block[9] << 8) | (block[10] << 16) | (block[11] << 24));
                                    tokenDecrypted = true;
                                }
                            }
                        }

                        long nowUnix = (long)(System.DateTime.UtcNow - new System.DateTime(1970, 1, 1)).TotalSeconds;
                        bool tokenValid = serverActive && tokenDecrypted && tokenStatus != 0 && nowUnix < tokenTs;

                        if (!tokenValid)
                        {
                            // Server OFF or token invalid/forged/expired — disable all features immediately
                            self.{{SCENE_POSITION_FIELD}} = new Vector2(0f, 0f);
                            PlayerPrefs.SetInt("ESP_State", 0);
                            PlayerPrefs.SetInt("ESP_Aux", 0);
                            Time.timeScale = 1.0f;
                            try
                            {
                                Type gameVarDefType = Type.GetType("COW.GameVarDef, Assembly-CSharp");
                                if (gameVarDefType != null)
                                {
                                    FieldInfo headFi = gameVarDefType.GetField("HitDamageRatioHead", BindingFlags.Public | BindingFlags.Static);
                                    FieldInfo bodyFi = gameVarDefType.GetField("HitDamageRatioBody", BindingFlags.Public | BindingFlags.Static);
                                    if (headFi != null) headFi.SetValue(null, 5.5f);
                                    if (bodyFi != null) bodyFi.SetValue(null, 1.0f);
                                }
                            }
                            catch { }
                        }
                        else
                        {
                            // ── Cryptographically verified server permissions ────
                            bool allowEsp = (tokenFeat & 1) != 0;
                            bool allowBox = allowEsp && (tokenFeat & 2) != 0;
                            bool allowLine = allowEsp && (tokenFeat & 4) != 0;
                            bool allowName = allowEsp && (tokenFeat & 8) != 0;
                            bool allowDistance = allowEsp && (tokenFeat & 16) != 0;
                            bool allowHealth = allowEsp && (tokenFeat & 32) != 0;
                            bool allowSkeleton = allowEsp && (tokenFeat & 64) != 0;
                            bool allowAim = (tokenFeat & 128) != 0;
                            bool allowAimSystem = (tokenFeat & 256) != 0;
                            bool allowHeadshot = allowAim && (tokenFeat & 512) != 0;
                            bool allowNoRecoil = allowAim && (tokenFeat & 1024) != 0;

                            int s = StateInitialized;
                            if (allowEsp && ((userToggles & (1 << 0)) != 0)) s |= EspMaster;
                            if (allowBox && ((userToggles & (1 << 1)) != 0)) s |= EspBox;
                            if (allowLine && ((userToggles & (1 << 2)) != 0)) s |= EspTracer;
                            if (allowName && ((userToggles & (1 << 3)) != 0)) s |= EspName;
                            if (allowHealth && ((userToggles & (1 << 4)) != 0)) s |= EspHealth;
                            if (allowDistance && ((userToggles & (1 << 5)) != 0)) s |= EspDistance;
                            if (allowAim && ((userToggles & (1 << 7)) != 0)) s |= AimEnabled;
                            if (allowAimSystem && ((userToggles & (1 << 8)) != 0)) s |= AimSystemEnabled;
                            if (allowAim && ((userToggles & (1 << 9)) != 0)) s |= EspFov;
                            if (allowNoRecoil && ((userToggles & (1 << 10)) != 0)) s |= NoRecoil;
                            
                            int targetBone = (int)((userToggles >> 17) & 3);
                            if (targetBone == 0 && allowHeadshot) s |= AimSystemHead;
                            else s &= ~AimSystemHead;

                            int headRateVal = allowHeadshot ? (int)(((userToggles >> 27) & 15) * 10) : 0;
                            if (headRateVal > 100) headRateVal = 100;

                            s |= (targetBone << AimModeShift);

                            int scaledFov = (int)((userToggles >> 22) & 31);
                            if (scaledFov > 31) scaledFov = 31;
                            if (scaledFov < 1) scaledFov = 1;
                            int a = (scaledFov << AuxFovRadiusShift) | (headRateVal << 8);
                            if (allowSkeleton && ((userToggles & (1 << 6)) != 0)) a |= AuxSkeleton;
                            if ((userToggles & (1 << 13)) != 0) a |= 2;
                            if ((userToggles & (1 << 14)) != 0) a |= 4;

                            self.{{SCENE_POSITION_FIELD}} = new Vector2((float)s, (float)a);
                            PlayerPrefs.SetInt("ESP_State", s);
                            PlayerPrefs.SetInt("ESP_Aux", a);
                            try { PlayerPrefs.Save(); } catch { }
                            
                            // Apply SpeedHack
                            float speedLevel = (float)((userToggles >> 19) & 7);
                            if (speedLevel < 1.0f) speedLevel = 1.0f;
                            Time.timeScale = speedLevel;

                            // Apply AimLockX10 & Hacks
                            float camXaFloat = ((userToggles & (1u << 31)) != 0) ? 2.0f : 1.5f;
                            PlayerPrefs.SetFloat("ESP_CamXaFloat", camXaFloat);
                            PlayerPrefs.SetInt("ESP_GhostMode", ((userToggles & (1 << 15)) != 0) ? 1 : 0);
                            
                            // Apply BuffDame and BuffShuriken
                            bool buffDame = ((userToggles & (1 << 16)) != 0) || allowHeadshot;
                            try
                            {
                                Player localPlayer = GameFacade.CurrentLocalPlayer();
                                if (localPlayer != null && localPlayer.Attributes != null)
                                {
                                    if (buffDame)
                                    {
                                        localPlayer.Attributes.HeadDamageIncreaseScale = 150.0f;
                                    }
                                    else
                                    {
                                        localPlayer.Attributes.HeadDamageIncreaseScale = 1.0f;
                                    }
                                }
                            }
                            catch { }
                        }
                    }
                    else
                    {
                        self.{{SCENE_POSITION_FIELD}} = new Vector2(0f, 0f);
                        PlayerPrefs.SetInt("ESP_State", 0);
                        PlayerPrefs.SetInt("ESP_Aux", 0);
                        Time.timeScale = 1.0f;
                    }
                }
                catch
                {
                    self.{{SCENE_POSITION_FIELD}} = new Vector2(0f, 0f);
                    PlayerPrefs.SetInt("ESP_State", 0);
                    PlayerPrefs.SetInt("ESP_Aux", 0);
                    Time.timeScale = 1.0f;
                }
            }

            int state = (int)self.{{SCENE_POSITION_FIELD}}.x;
            int auxState = (int)self.{{SCENE_POSITION_FIELD}}.y;
            
            
            int mask = state & EspMask;
            int aimMode = (state & AimModeMask) >> AimModeShift;

            if (currentEvent.type != EventType.Repaint) { return; }

            // Required method and string references (dead-code guard; never executes)
            if (Time.frameCount < -1)
            {
                Event.current.Use();
                Vector2 _mp = Input.mousePosition;
                int _tc = Input.touchCount;
                float _ut = Time.unscaledTime;
                Vector2 _d = Event.current.delta;
                float _cl = Mathf.Clamp(0f, 0f, 1f);
                bool _vis = GameFacade.CurrentLocalPlayer() != null && GameFacade.CurrentLocalPlayer().IsVisible();
                GUI.Label(new Rect(0,0,300,30), "__esp_driver");
                GUI.Label(new Rect(0,0,300,30), "__esp_fov");
                GUI.Label(new Rect(0,0,300,30), ApiServerUrl);
                GUI.Label(new Rect(0,0,300,30), ApiHeartbeatUrl);
                GUI.Label(new Rect(0,0,300,30), ApiStatusUrl);
                GUI.Label(new Rect(0,0,300,30), "MeoMeo");
                GUI.Label(new Rect(0,0,300,30), "Enable ESP");
                GUI.Label(new Rect(0,0,300,30), "Player box");
                GUI.Label(new Rect(0,0,300,30), "Top tracer");
                GUI.Label(new Rect(0,0,300,30), "Health bar");
                GUI.Label(new Rect(0,0,300,30), "Player name");
                GUI.Label(new Rect(0,0,300,30), "Distance");
                GUI.Label(new Rect(0,0,300,30), "RESET DEFAULTS");
                GUI.Label(new Rect(0,0,300,30), "HIDE MENU");
                GUI.Label(new Rect(0,0,300,30), "ESP");
                GUI.Label(new Rect(0,0,300,30), "SETTINGS");
                GUI.Label(new Rect(0,0,300,30), "X");
                GUI.Label(new Rect(0,0,300,30), "AIM");
                GUI.Label(new Rect(0,0,300,30), "Silent aim");
                GUI.Label(new Rect(0,0,300,30), "Target: BODY");
                GUI.Label(new Rect(0,0,300,30), "Target: HEAD");
                GUI.Label(new Rect(0,0,300,30), "Target: MIXED");
                GUI.Label(new Rect(0,0,300,30), "Headshot rate: 0%");
                GUI.Label(new Rect(0,0,300,30), "Headshot rate: 25%");
                GUI.Label(new Rect(0,0,300,30), "Headshot rate: 50%");
                GUI.Label(new Rect(0,0,300,30), "Headshot rate: 75%");
                GUI.Label(new Rect(0,0,300,30), "Headshot rate: 100%");
                GUI.Label(new Rect(0,0,300,30), "Aim FOV circle");
                GUI.Label(new Rect(0,0,300,30), "No recoil");
                GUI.Label(new Rect(0,0,300,30), "Aim system");
                GUI.Label(new Rect(0,0,300,30), "Aim system target: HEAD");
                GUI.Label(new Rect(0,0,300,30), "Aim system target: NECK");
            }
            if (Time.frameCount == -1) { Event.current.Use(); Vector2 m = Input.mousePosition; Vector2 d = Input.GetTouch(0).deltaPosition; int t = Input.touchCount; float f = Time.unscaledTime; int r = UnityEngine.Random.Range(0, 100); }
            Matrix4x4 savedMatrix = GUI.matrix;
            Color savedColor = GUI.color;
            bool isIOS = Application.platform == RuntimePlatform.IPhonePlayer;
            try {
                GUI.matrix = Matrix4x4.identity;
                Texture2D pixel = Texture2D.whiteTexture;
                if (pixel != null
                    && screenWidth > 0 && screenHeight > 0)
                {
                    Camera camera = Camera.main;
                    if (camera != null)
                    {
                        if ((auxState & 2) != 0)
                        {
                            camera.fieldOfView = 60f * PlayerPrefs.GetFloat("ESP_CamXaFloat", 1.5f); // Cam Xa multiplier
                        }
                    }
                    Player localPlayer = GameFacade.CurrentLocalPlayer();
                    Transform localRoot = localPlayer == null ? null : localPlayer.RootTransform;
                    if (localRoot != null)
                    {
                        if (PlayerPrefs.GetInt("ESP_GhostMode", 0) == 1)
                        {
                            bool ghostActive = PlayerPrefs.GetInt("ESP_GhostActive", 0) == 1;
                            for (int i = 0; i < localRoot.childCount; i++)
                            {
                                Transform child = localRoot.GetChild(i);
                                if (child != null)
                                {
                                    child.localScale = ghostActive ? Vector3.zero : Vector3.one;
                                }
                            }
                        }
                    }

                    if (localPlayer == null && showGuestBtn)
                    {
                        // Draw Guest Reset Button on Login Screen / Lobby
                        GUI.color = new Color(0.85f, 0.15f, 0.15f, 0.92f);
                        GUI.DrawTexture(guestBtnRect, pixel);
                        GUI.color = Color.white;
                        GUIStyle btnStyle = GUI.skin.label;
                        btnStyle.fontSize = 13;
                        btnStyle.alignment = TextAnchor.MiddleCenter;
                        btnStyle.normal.textColor = Color.white;
                        GUI.Label(guestBtnRect, "RESET GUEST", btnStyle);
                    }

                    if (localPlayer != null && PlayerPrefs.GetInt("ESP_GhostMode", 0) == 1)
                    {
                        bool ghostActive = PlayerPrefs.GetInt("ESP_GhostActive", 0) == 1;
                        float gX = PlayerPrefs.GetFloat("GhostBtnX", 20f);
                        float gY = PlayerPrefs.GetFloat("GhostBtnY", 100f);
                        Rect gRect = new Rect(gX, gY, 130f, 40f);

                        // Draw Ghost Mode Floating Button
                        GUI.color = ghostActive ? new Color(0.15f, 0.85f, 0.15f, 0.92f) : new Color(0.85f, 0.15f, 0.15f, 0.92f);
                        GUI.DrawTexture(gRect, pixel);
                        GUI.color = Color.white;
                        GUIStyle ghostStyle = GUI.skin.label;
                        ghostStyle.fontSize = 13;
                        ghostStyle.alignment = TextAnchor.MiddleCenter;
                        ghostStyle.normal.textColor = Color.white;
                        GUI.Label(gRect, ghostActive ? "GHOST: ON" : "GHOST: OFF", ghostStyle);
                    }

                    // Draw Feedback Banner if reset was recently triggered (within 6 seconds)
                    float resetFeedbackDiff = Time.realtimeSinceStartup - self.{{SCENE_STATE_FIELD}}.y;
                    if (resetFeedbackDiff >= 0f && resetFeedbackDiff < 6.0f)
                    {
                        float bannerW = Mathf.Min(480f, (float)screenWidth - 40f);
                        float bannerH = 46f;
                        Rect bannerRect = new Rect(((float)screenWidth - bannerW) * 0.5f, 65f, bannerW, bannerH);
                        GUI.color = new Color(0.08f, 0.55f, 0.15f, 0.95f);
                        GUI.DrawTexture(bannerRect, pixel);
                        GUI.color = Color.white;
                        GUIStyle bannerStyle = GUI.skin.label;
                        bannerStyle.fontSize = 13;
                        bannerStyle.alignment = TextAnchor.MiddleCenter;
                        bannerStyle.normal.textColor = Color.white;
                        GUI.Label(bannerRect, "DA XOA ACC GUEST! BAM KHACH DE VAO ACC MOI!", bannerStyle);
                    }

                    if ((state & AimEnabled) != 0 && (mask & EspFov) != 0)
                    {
                        int fovIdx = (auxState & AuxFovRadiusMask) >> AuxFovRadiusShift;
                        float fovRadius = 50f + (float)fovIdx * 11.29f;
                        GUI.color = new Color(0.3f, 1f, 0f, 1f);
                        float circleX = (float)screenWidth * 0.5f;
                        float circleY = (float)screenHeight * 0.5f;
                        int fovSegments = isIOS ? 24 : 64;
                        float fovStep = 6.2831853f / (float)fovSegments;
                        for (int segment = 0; segment < fovSegments; segment++)
                        {
                            float angle0 = (float)segment * fovStep;
                            float angle1 = (float)(segment + 1) * fovStep;
                            float x0 = circleX + Mathf.Cos(angle0) * fovRadius;
                            float y0 = circleY + Mathf.Sin(angle0) * fovRadius;
                            float x1 = circleX + Mathf.Cos(angle1) * fovRadius;
                            float y1 = circleY + Mathf.Sin(angle1) * fovRadius;
                            float dx = x1 - x0;
                            float dy = y1 - y0;
                            float length = Mathf.Sqrt(dx * dx + dy * dy);
                            float angle = Mathf.Atan2(dy, dx) * 57.29578f;
                            GUI.matrix = Matrix4x4.TRS(
                                        new Vector3(x0, y0, 0f),
                                        Quaternion.Euler(0f, 0f, angle),
                                        Vector3.one);
                            GUI.DrawTexture(new Rect(0f, -0.75f, length, 1.5f), pixel);
                        }
                        GUI.matrix = Matrix4x4.identity;
                    }

                    if ((mask & EspMaster) != 0 || (state & AimEnabled) != 0 || (state & AimSystemEnabled) != 0)
                    {
                        {{MATCH_TYPE}} match = GameFacade.CurrentMatch();
                        IList players = match == null ? null : match.{{MATCH_PLAYERS_METHOD}}();
                        GameObject localObject = localPlayer == null
                            ? null : localPlayer.gameObject;
                        if (camera != null && localPlayer != null
                            && localObject != null && localObject.activeInHierarchy
                            && localRoot != null && players != null)
                        {
                            int enemyCount = 0;
                            GUIStyle nameStyle = GUI.skin.label;
                            nameStyle.fontSize = 14;
                            nameStyle.alignment = TextAnchor.MiddleCenter;
                            for (int index = 0; index < players.Count; index++)
                            {
                                try
                                {
                                Player player = players[index] as Player;
                                if (player == null || player == localPlayer)
                                {
                                    continue;
                                }
                                if (player.IsLocalPlayer() || player.IsLocalTeammate(false) || player.IsLocalTeammate(true))
                                {
                                    continue;
                                }
                                if (player.IsDead || player.IsReallyDead)
                                {
                                    continue;
                                }

                                int health = player.CurHP;
                                int maximumHealth = player.MaxHP;
                                if (health <= 0 || maximumHealth <= 0)
                                {
                                    continue;
                                }

                                GameObject playerObject = player.gameObject;
                                if (playerObject == null || !playerObject.activeInHierarchy)
                                {
                                    continue;
                                }
                                Transform root = player.RootTransform;
                                if (root == null)
                                {
                                    continue;
                                }
                                Vector3 rootPos = root.position;
                                if (rootPos.sqrMagnitude < 4.0f || rootPos.y < -50f || float.IsNaN(rootPos.x) || float.IsNaN(rootPos.y) || float.IsNaN(rootPos.z))
                                {
                                    continue;
                                }

                                float distance = Vector3.Distance(localRoot.position, rootPos);
                                if (distance < 1.2f || distance > 350f)
                                {
                                    continue;
                                }

                                Transform head = player.GetHeadTF();
                                if (head == null)
                                {
                                    continue;
                                }
                                Vector3 headPos = head.position;
                                if (headPos.sqrMagnitude < 4.0f || Vector3.Distance(headPos, rootPos) > 4.5f)
                                {
                                    continue;
                                }

                                // Địch hoàn toàn hợp lệ và đang sống thực sự mới tăng enemyCount
                                enemyCount++;

                                if ((mask & EspMaster) == 0 || distance > 250f)
                                {
                                    continue;
                                }

                                bool dying = player.IsDieing;

                                Vector3 feetScreen = camera.WorldToScreenPoint(rootPos);
                                Vector3 headScreen = camera.WorldToScreenPoint(headPos);
                                if (feetScreen.z <= 0f || headScreen.z <= 0f)
                                {
                                    continue;
                                }
                                if (float.IsNaN(feetScreen.x) || float.IsNaN(feetScreen.y)
                                    || float.IsNaN(feetScreen.z) || float.IsNaN(headScreen.x)
                                    || float.IsNaN(headScreen.y) || float.IsNaN(headScreen.z)
                                    || float.IsInfinity(feetScreen.x) || float.IsInfinity(feetScreen.y)
                                    || float.IsInfinity(headScreen.x) || float.IsInfinity(headScreen.y))
                                {
                                    continue;
                                }

                                float height = Mathf.Abs(headScreen.y - feetScreen.y) * 1.0909091f;
                                if (height < 2f)
                                {
                                    continue;
                                }
                                float width = height * 0.5f;
                                float left = headScreen.x - width * 0.5f;
                                float top = (float)screenHeight - headScreen.y;
                                float thickness = 1.5f;
                                if (float.IsNaN(left) || float.IsNaN(top)
                                    || float.IsInfinity(left) || float.IsInfinity(top)
                                    || left > (float)screenWidth || left + width < 0f
                                    || top > (float)screenHeight || top + height < 0f)
                                {
                                    continue;
                                }
                                if ((mask & EspBox) != 0)
                                {
                                    GUI.color = dying
                                        ? Color.red
                                        : Color.white;
                                    GUI.DrawTexture(new Rect(left, top, width, thickness), pixel);
                                    GUI.DrawTexture(new Rect(
                                        left, top + height - thickness, width, thickness), pixel);
                                    GUI.DrawTexture(new Rect(left, top, thickness, height), pixel);
                                    GUI.DrawTexture(new Rect(
                                        left + width - thickness, top, thickness, height), pixel);
                                }

                                if ((mask & EspTracer) != 0)
                                {
                                    float startX = (float)screenWidth * 0.5f;
                                    float startY = 80f;
                                    float endX = left + width * 0.5f;
                                    float endY = top + height / 35f;
                                    float tracerX = endX - startX;
                                    float tracerY = endY - startY;
                                    float tracerLength = Mathf.Sqrt(
                                        tracerX * tracerX + tracerY * tracerY);
                                    float tracerAngle = Mathf.Atan2(
                                        tracerY, tracerX) * 57.29578f;
                                    GUI.color = dying
                                        ? Color.red
                                        : Color.white;
                                    GUI.matrix = Matrix4x4.TRS(
                                        new Vector3(startX, startY, 0f),
                                        Quaternion.Euler(0f, 0f, tracerAngle),
                                        Vector3.one);
                                    GUI.DrawTexture(new Rect(
                                        0f, -thickness * 0.5f,
                                        tracerLength, thickness), pixel);
                                    GUI.matrix = Matrix4x4.identity;
                                }

                                if ((auxState & AuxSkeleton) != 0)
                                {
                                    if (distance <= 120f)
                                    {
                                        Transform sHead = head;
                                        Transform sNeck = player.NeckBone;
                                        Transform sSpine = player.SpineBoneTransform;
                                        Transform sHip = player.GetHipTF();
                                        Transform sLArm = player.ArmBoneLeft;
                                        Transform sLElbow = player.LeftForeArmTF;
                                        Transform sLHand = player.LeftHandTF;
                                        Transform sRArm = player.ArmBoneRight;
                                        Transform sRElbow = player.RightForeArmTF;
                                        Transform sRHand = player.RightHandTF;
                                        Transform sLLeg = player.LegBoneLeft;
                                        Transform sLAnkle = player.GetLeftAnkleTF();
                                        Transform sLFoot = player.FootBoneLeft;
                                        Transform sRLeg = player.LegBoneRight;
                                        Transform sRAnkle = player.GetRightAnkleTF();
                                        Transform sRFoot = player.FootBoneRight;

                                        if (sNeck == null) sNeck = sHead;
                                        if (sSpine == null) sSpine = sNeck;
                                        if (sHip == null) sHip = root;
                                        if (sLArm == null) sLArm = sNeck;
                                        if (sLElbow == null) sLElbow = sLArm;
                                        if (sLHand == null) sLHand = sLElbow;
                                        if (sRArm == null) sRArm = sNeck;
                                        if (sRElbow == null) sRElbow = sRArm;
                                        if (sRHand == null) sRHand = sRElbow;
                                        if (sLLeg == null) sLLeg = sHip;
                                        if (sLAnkle == null) sLAnkle = sLLeg;
                                        if (sLFoot == null) sLFoot = sLAnkle;
                                        if (sRLeg == null) sRLeg = sHip;
                                        if (sRAnkle == null) sRAnkle = sRLeg;
                                        if (sRFoot == null) sRFoot = sRAnkle;

                                        float skelThickness = 1.6f;
                                        GUI.color = dying
                                            ? Color.red
                                            : new Color(0.9f, 0.95f, 1f, 0.95f);

                                        for (int boneIdx = 0; boneIdx < 15; boneIdx++)
                                        {
                                            Transform tA = null;
                                            Transform tB = null;
                                            if (boneIdx == 0) { tA = sHead; tB = sNeck; }
                                            else if (boneIdx == 1) { tA = sNeck; tB = sSpine; }
                                            else if (boneIdx == 2) { tA = sSpine; tB = sHip; }
                                            else if (boneIdx == 3) { tA = sNeck; tB = sLArm; }
                                            else if (boneIdx == 4) { tA = sLArm; tB = sLElbow; }
                                            else if (boneIdx == 5) { tA = sLElbow; tB = sLHand; }
                                            else if (boneIdx == 6) { tA = sNeck; tB = sRArm; }
                                            else if (boneIdx == 7) { tA = sRArm; tB = sRElbow; }
                                            else if (boneIdx == 8) { tA = sRElbow; tB = sRHand; }
                                            else if (boneIdx == 9) { tA = sHip; tB = sLLeg; }
                                            else if (boneIdx == 10) { tA = sLLeg; tB = sLAnkle; }
                                            else if (boneIdx == 11) { tA = sLAnkle; tB = sLFoot; }
                                            else if (boneIdx == 12) { tA = sHip; tB = sRLeg; }
                                            else if (boneIdx == 13) { tA = sRLeg; tB = sRAnkle; }
                                            else { tA = sRAnkle; tB = sRFoot; }

                                            if (tA != null && tB != null)
                                            {
                                                Vector3 spA = camera.WorldToScreenPoint(tA.position);
                                                Vector3 spB = camera.WorldToScreenPoint(tB.position);
                                                if (spA.z > 0f && spB.z > 0f
                                                    && !float.IsNaN(spA.x) && !float.IsNaN(spA.y)
                                                    && !float.IsNaN(spB.x) && !float.IsNaN(spB.y)
                                                    && !float.IsInfinity(spA.x) && !float.IsInfinity(spA.y)
                                                    && !float.IsInfinity(spB.x) && !float.IsInfinity(spB.y))
                                                {
                                                    float ax = spA.x;
                                                    float ay = (float)screenHeight - spA.y;
                                                    float bx = spB.x;
                                                    float by = (float)screenHeight - spB.y;
                                                    float dx = bx - ax;
                                                    float dy = by - ay;
                                                    float len = Mathf.Sqrt(dx * dx + dy * dy);
                                                    if (len > 0.5f && len < 500f)
                                                    {
                                                        float angle = Mathf.Atan2(dy, dx) * 57.29578f;
                                                        GUI.matrix = Matrix4x4.TRS(
                                                            new Vector3(ax, ay, 0f),
                                                            Quaternion.Euler(0f, 0f, angle),
                                                            Vector3.one);
                                                        GUI.DrawTexture(
                                                            new Rect(0f, -skelThickness * 0.5f, len, skelThickness),
                                                            pixel);
                                                    }
                                                }
                                            }
                                        }
                                        GUI.matrix = Matrix4x4.identity;
                                    }
                                }

                                if ((mask & EspHealth) != 0)
                                {
                                    float healthRatio = maximumHealth > 0
                                        ? Mathf.Clamp01((float)health / (float)maximumHealth)
                                        : 0f;
                                    float healthX = left + width + 2f;
                                    GUI.color = new Color(0f, 0f, 0f, 0.9f);
                                    GUI.DrawTexture(new Rect(healthX, top, 5f, height), pixel);

                                    // Chuyển màu dần mượt mà từ mức máu cao xuống thấp: Xanh -> Vàng -> Cam -> Đỏ (hoặc Knock)
                                    float r = healthRatio > 0.5f ? (1f - healthRatio) * 2f : 1f;
                                    float g = healthRatio > 0.5f ? 1f : healthRatio * 2f;
                                    GUI.color = dying || healthRatio <= 0.12f
                                        ? new Color(1f, 0.12f, 0.12f, 1f)
                                        : new Color(r, g * 0.92f, 0.05f, 1f);

                                    GUI.DrawTexture(new Rect(
                                        healthX + 1f,
                                        top + height - height * healthRatio,
                                        3f,
                                        height * healthRatio), pixel);
                                }

                                if ((mask & EspName) != 0)
                                {
                                    if (distance <= 200f)
                                    {
                                        string nickname = player.NickName;
                                        if (string.IsNullOrEmpty(nickname)) nickname = "MeoMeo";

                                        string displayName = dying ? ("[KNOCK] " + nickname) : nickname;
                                        float tagW = Mathf.Clamp((float)displayName.Length * 9f + 20f, 80f, 250f);
                                        float tagH = 20f;
                                        float midX = left + width * 0.5f;
                                        float tagX = midX - tagW * 0.5f;
                                        float tagY = top - tagH - 2f;

                                        nameStyle.fontSize = 14;
                                        // 1-directional shadow for crisp visibility
                                        nameStyle.normal.textColor = Color.black;
                                        GUI.Label(new Rect(tagX + 1f, tagY + 1f, tagW, tagH), displayName, nameStyle);

                                        // Main name text (Red when knocked, White when alive)
                                        nameStyle.normal.textColor = dying ? Color.red : Color.white;
                                        GUI.Label(new Rect(tagX, tagY, tagW, tagH), displayName, nameStyle);
                                    }
                                }

                                if ((mask & EspDistance) != 0)
                                {
                                    if (distance <= 200f)
                                    {
                                        int distanceValue = (int)distance;
                                        if (distanceValue < 0) distanceValue = 0;
                                        if (distanceValue > 999) distanceValue = 999;
                                        string distStr = distanceValue.ToString() + "m";
                                        float distW = (float)distStr.Length * 7.5f + 14f;
                                        float distH = 16f;
                                        float distMidX = left + width * 0.5f;
                                        float distTagX = distMidX - distW * 0.5f;
                                        float distTagY = top + height + 3f;

                                        // Matching dark pill background for distance
                                        GUI.color = new Color(0.06f, 0.08f, 0.12f, 0.82f);
                                        GUI.DrawTexture(new Rect(distTagX, distTagY, distW, distH), pixel);

                                        // Centered distance label with drop shadow
                                        nameStyle.fontSize = 12;
                                        nameStyle.normal.textColor = new Color(0f, 0f, 0f, 0.95f);
                                        GUI.Label(new Rect(distTagX + 1f, distTagY + 1f, distW, distH), distStr, nameStyle);

                                        nameStyle.normal.textColor = dying
                                            ? Color.red
                                            : new Color(0.92f, 0.96f, 1f, 1f);
                                        GUI.Label(new Rect(distTagX, distTagY, distW, distH), distStr, nameStyle);

                                        nameStyle.fontSize = 14;
                                    }
                                }
                                }
                                catch (Exception)
                                {
                                    // A recycled entity is skipped without aborting the frame.
                                }
                            
                                } // end for loop
                        
                                string countText = enemyCount > 0 ? ("Enemy : " + enemyCount) : "Clean";
                                GUIStyle countStyle = GUI.skin.label;
                                countStyle.fontSize = 32;
                                countStyle.alignment = TextAnchor.MiddleCenter;
                                float countW = 350f;
                                float countH = 50f;
                                float countX = (float)screenWidth * 0.5f - countW * 0.5f;
                                float countY = 20f;
                                // Shadow
                                countStyle.normal.textColor = new Color(0f, 0f, 0f, 0.85f);
                                GUI.Label(new Rect(countX + 2f, countY + 2f, countW, countH), countText, countStyle);
                                // Main text
                                countStyle.normal.textColor = enemyCount > 0 ? new Color(1f, 0.2f, 0.2f, 1f) : new Color(0.15f, 1f, 0.15f, 1f);
                                GUI.Label(new Rect(countX, countY, countW, countH), countText, countStyle);
                        }
                        
                    }

                }
            }
            catch (Exception)
            {
                // A transient Unity object is skipped for this event.
            }

            GUI.matrix = savedMatrix;
            GUI.color = savedColor;
        }

        public static {{AIM_INFO_TYPE}} SilentAim(Player self)
        {
            if (self == null)
            {
                return null;
            }
            {{AIM_INFO_TYPE}} info = self.{{PLAYER_AIM_INFO_FIELD}};
            if (info == null)
            {
                return info;
            }
            try
            {
                GameObject driver = GameObject.Find("__esp_driver");
                SceneEditBoxSelectTool menu = driver == null
                    ? null
                    : (SceneEditBoxSelectTool)driver.GetComponent(typeof(SceneEditBoxSelectTool));
                int state = menu == null ? 0 : (int)menu.{{SCENE_POSITION_FIELD}}.x;
                if ((state & AimEnabled) == 0)
                {
                    return info;
                }

                {{MATCH_TYPE}} match = GameFacade.CurrentMatch();
                IList players = match == null ? null : match.{{MATCH_PLAYERS_METHOD}}();
                Camera camera = Camera.main;
                if (players == null || camera == null)
                {
                    return info;
                }

                int targetBone = (state & AimModeMask) >> AimModeShift;
                int aux = menu == null ? 0 : (int)menu.{{SCENE_POSITION_FIELD}}.y;
                int headRate = (aux >> 8) & 0xFF;
                bool aimAtNeck = (targetBone == 1);
                Vector3 aimStart = self.AimStartPostion;
                int fovIdx = (aux & AuxFovRadiusMask) >> AuxFovRadiusShift;
                float fovRadius = 50f + (float)fovIdx * 11.29f;
                float fovSqr = fovRadius * fovRadius;
                float bestScore = fovSqr;
                Collider bestCollider = null;
                Vector3 bestPosition = Vector3.zero;

                for (int index = 0; index < players.Count; index++)
                {
                    Player candidate = players[index] as Player;
                    if (candidate == null || candidate == self)
                    {
                        continue;
                    }
                    if (candidate.IsDead || candidate.IsReallyDead || candidate.CurHP <= 0)
                    {
                        continue;
                    }
                    if (candidate.IsLocalPlayer() || candidate.IsLocalTeammate(false) || candidate.IsLocalTeammate(true))
                    {
                        continue;
                    }
                    GameObject candidateObject = candidate.gameObject;
                    if (candidateObject == null || !candidateObject.activeInHierarchy)
                    {
                        continue;
                    }

                bool aimAtHead = false;
                if (targetBone == 0)
                {
                    int seeded = Mathf.Abs(candidateObject.GetInstanceID()) % 100;
                    aimAtHead = seeded < headRate;
                }

                Transform root = candidate.RootTransform;
                Transform head = candidate.GetHeadTF();
                Collider headCollider = candidate.HeadCollider;
                if (root == null)
                {
                    continue;
                }

                Vector3 hitPosition;
                Collider hitCollider;
                if (aimAtHead)
                {
                    if (head == null || headCollider == null)
                    {
                        continue;
                    }
                    hitPosition = head.position;
                    hitCollider = headCollider;
                }
                else if (aimAtNeck)
                {
                    Transform neck = candidate.NeckBone;
                    if (neck != null)
                    {
                        hitPosition = neck.position;
                        hitCollider = (Collider)neck.GetComponent(typeof(Collider));
                        if (hitCollider == null) hitCollider = headCollider;
                    }
                    else
                    {
                        hitPosition = root.position + new Vector3(0f, 1.25f, 0f);
                        hitCollider = (Collider)root.GetComponent("CapsuleCollider");
                        if (hitCollider == null) hitCollider = headCollider;
                    }
                }
                else
                {
                    hitPosition = root.position + new Vector3(0f, 0.9f, 0f);
                    hitCollider = (Collider)root.GetComponent("CapsuleCollider");
                    if (hitCollider == null)
                    {
                        if (head == null || headCollider == null)
                        {
                            continue;
                        }
                        hitCollider = headCollider;
                    }
                }

                float hitDist = Vector3.Distance(hitPosition, aimStart);
                if (hitDist > 180f || hitDist < 0.8f)
                {
                    continue;
                }
                Vector3 screen = camera.WorldToScreenPoint(hitPosition);
                if (screen.z <= 1f
                    || float.IsNaN(screen.x) || float.IsNaN(screen.y)
                    || float.IsNaN(screen.z) || float.IsInfinity(screen.x)
                    || float.IsInfinity(screen.y) || float.IsInfinity(screen.z))
                {
                    continue;
                }
                float dx = screen.x - (float)Screen.width * 0.5f;
                float dy = screen.y - (float)Screen.height * 0.5f;
                float distSqr = dx * dx + dy * dy;

                // ── FIX AIMSILENT LỖI DAME: BẮT BUỘC ĐỊCH PHẢI NẰM TRONG VÒNG FOV ──
                if (distSqr > fovSqr || float.IsNaN(distSqr) || float.IsInfinity(distSqr) || distSqr >= bestScore)
                {
                    continue;
                }

                bestScore = distSqr;
                bestCollider = hitCollider;
                bestPosition = hitPosition;
            }

            if (bestCollider != null)
            {
                Vector3 rayDirection = Vector3.Normalize(bestPosition - aimStart);
                info.{{AIM_GAME_OBJECT_FIELD}} = bestCollider.gameObject;
                info.{{AIM_COLLIDER_FIELD}} = bestCollider;
                info.{{AIM_HIT_POSITION_FIELD}} = bestPosition;
                info.{{AIM_TRACE_POSITION_FIELD}} = bestPosition;
                info.{{AIM_DIRECTION_FIELD}} = rayDirection;
                info.{{AIM_ORIGIN_FIELD}} = aimStart;
                info.{{AIM_SECONDARY_ORIGIN_FIELD}} = aimStart;
                info.{{AIM_HIT_TYPE_FIELD}} = ({{AIM_HIT_TYPE}})1;
                info.{{AIM_FLAG_A_FIELD}} = false;
                info.{{AIM_FLAG_B_FIELD}} = false;
                info.{{AIM_SHORT_FIELD}} = (short)0;
            }
                return info;
            }
            catch (Exception)
            {
                return info;
            }
        }

        public static bool AimSystem(Player self)
        {
            if (self == null)
            {
                return false;
            }
            bool original = false;
            try
            {
                original = self.EspBaseIsMovableEntity();
                
                if (Time.frameCount % 15 == 0)
                {
                    GameObject driver = GameObject.Find("__esp_driver");
                    bool createdDriver = false;
                    if (driver == null)
                    {
                        Camera _camera = Camera.main;
                        Transform legacyFov = _camera == null ? null : _camera.transform.Find("__esp_fov");
                        if (legacyFov != null) UnityEngine.Object.Destroy(legacyFov.gameObject);
                        driver = new GameObject("__esp_driver");
                        createdDriver = true;
                    }
                    Component component = driver.GetComponent(typeof(SceneEditBoxSelectTool));
                    if (component == null) component = driver.AddComponent(typeof(SceneEditBoxSelectTool));
                    if (component == null) { if (createdDriver) UnityEngine.Object.Destroy(driver); }
                    else { if (createdDriver) UnityEngine.Object.DontDestroyOnLoad(driver); }
                }
                GameObject driver_menu = GameObject.Find("__esp_driver");
                SceneEditBoxSelectTool menu = driver_menu == null
                    ? null
                    : (SceneEditBoxSelectTool)driver_menu.GetComponent(typeof(SceneEditBoxSelectTool));
                int state = menu == null ? 0 : (int)menu.{{SCENE_POSITION_FIELD}}.x;
                int aux = menu == null ? 0 : (int)menu.{{SCENE_POSITION_FIELD}}.y;
                if ((state & AimSystemEnabled) == 0
                    || self.gameObject == null || !self.gameObject.activeInHierarchy
                    || self.IsLocalPlayer() || self.IsDead || self.IsReallyDead || self.CurHP <= 0
                    || self.IsLocalTeammate(false) || self.IsLocalTeammate(true))
                {
                    self.EspLockedAimingCollider = null;
                    return original;
                }

                Camera camera = Camera.main;
                if (camera == null)
                {
                    self.EspLockedAimingCollider = null;
                    return original;
                }

            int targetBone = (state & AimModeMask) >> AimModeShift;

            int headRate = (aux >> 8) & 0x7F;
            bool aimAtHead = false;
            if (targetBone == 0 && self.gameObject != null)
            {
                int seeded = Mathf.Abs(self.gameObject.GetInstanceID()) % 100;
                aimAtHead = seeded < headRate;
            }
            bool aimAtNeck = (targetBone == 1);

            Vector3 targetPos = Vector3.zero;
            Collider targetCollider = null;

            if (aimAtHead)
            {
                Transform head = self.GetHeadTF();
                targetCollider = self.HeadCollider;
                targetPos = head != null ? head.position : (self.RootTransform != null ? self.RootTransform.position + new Vector3(0f, 1.6f, 0f) : Vector3.zero);
            }
            else if (aimAtNeck)
            {
                Transform neck = self.NeckBone;
                if (neck != null)
                {
                    targetPos = neck.position;
                    targetCollider = (Collider)neck.GetComponent(typeof(Collider));
                }
                if (targetCollider == null)
                {
                    targetCollider = self.HeadCollider;
                }
                if (targetPos == Vector3.zero)
                {
                    targetPos = self.RootTransform != null ? self.RootTransform.position + new Vector3(0f, 1.35f, 0f) : Vector3.zero;
                }
            }
            else
            {
                Transform neck = self.NeckBone;
                IList fireColliders = self.FireColliders;
                float nearestDistance = 10000f;
                Vector3 refPos = neck != null ? neck.position : (self.RootTransform != null ? self.RootTransform.position + new Vector3(0f, 1.0f, 0f) : Vector3.zero);
                targetPos = refPos;
                if (fireColliders != null)
                {
                    for (int index = 0; index < fireColliders.Count; index++)
                    {
                        Collider candidateCollider = fireColliders[index] as Collider;
                        if (candidateCollider == null)
                        {
                            continue;
                        }

                        float distance = Vector3.Distance(
                            candidateCollider.transform.position, refPos);
                        if (distance < nearestDistance)
                        {
                            nearestDistance = distance;
                            targetCollider = candidateCollider;
                        }
                    }
                }

                if (targetCollider == null && neck != null)
                {
                    targetCollider = (Collider)neck.GetComponent(typeof(Collider));
                }
                if (targetCollider == null)
                {
                    Transform root = self.RootTransform;
                    targetCollider = root == null
                        ? null
                        : (Collider)root.GetComponent("CapsuleCollider");
                }
                if (targetCollider == null)
                {
                    targetCollider = self.HeadCollider;
                }
            }

            // ── ANTI-LỖI DAME AIMBOT GUARD ──
            // 1. Kiểm tra khoảng cách chiến đấu hợp lệ (0.8m - 180m)
            Player localPlayer = GameFacade.CurrentLocalPlayer();
            Transform localRoot = localPlayer == null ? null : localPlayer.RootTransform;
            if (localRoot == null || targetPos == Vector3.zero)
            {
                self.EspLockedAimingCollider = null;
                return original;
            }
            float distToPlayer = Vector3.Distance(localRoot.position, targetPos);
            if (distToPlayer > 180f || distToPlayer < 0.8f)
            {
                self.EspLockedAimingCollider = null;
                return original;
            }

            // 2. CHỈ KHOÁ KHI ĐỊCH NẰM TRONG TẦM NHÌN (CAMERA FOV)
            // Không khoá bừa toàn bộ địch trên map gây xung đột engine và lỗi dame
            Vector3 screenPos = camera.WorldToScreenPoint(targetPos);
            if (screenPos.z <= 1f
                || float.IsNaN(screenPos.x) || float.IsNaN(screenPos.y)
                || float.IsInfinity(screenPos.x) || float.IsInfinity(screenPos.y))
            {
                self.EspLockedAimingCollider = null;
                return original;
            }

            int fovIdx = (aux & AuxFovRadiusMask) >> AuxFovRadiusShift;
            float fovRadius = 50f + (float)fovIdx * 11.29f;
            if (PlayerPrefs.GetInt("ESP_AimLockX10", 0) == 1) fovRadius *= 10.0f;
            float scrDx = screenPos.x - (float)Screen.width * 0.5f;
            float scrDy = screenPos.y - (float)Screen.height * 0.5f;
            if (scrDx * scrDx + scrDy * scrDy > fovRadius * fovRadius * 1.6f)
            {
                self.EspLockedAimingCollider = null;
                return original;
            }

            if (targetCollider == null)
            {
                self.EspLockedAimingCollider = null;
                return original;
            }
            self.EspLockedAimingCollider = targetCollider;
            return true;
        }
        catch (Exception)
        {
            return original;
        }
    }

    public static float ScatterRate(PlayerAttributes self)
        {
            if (self == null)
            {
                return 0f;
            }
            try
            {
                GameObject driver_menu = GameObject.Find("__esp_driver");
                SceneEditBoxSelectTool menu = driver_menu == null
                    ? null
                    : (SceneEditBoxSelectTool)driver_menu.GetComponent(typeof(SceneEditBoxSelectTool));
                int state = menu == null ? 0 : (int)menu.{{SCENE_POSITION_FIELD}}.x;
                if ((state & NoRecoil) != 0)
                {
                    return 0f;
                }
                return self.SkillScatterRate;
            }
            catch (Exception)
            {
                return self.SkillScatterRate;
            }
        }

        // AntiCheat bypass — hooks COW.UIModelLogin.GetffantihackEnabled
        // Returning false tells the game its own antihack SDK is OFF:
        //   - memory integrity scans are skipped (MonoMemCheckFrameInterval becomes irrelevant)
        //   - ffantihack rotation/speed checks stop (ffantihack.MHJKABKLFEB.LDEGEILBEGN gated behind this)
        //   - RUDP_SEND_FFANTIHACKINFO (msg 431) never queued — no telemetry sent to server
        //   - ProcessffantihackOpen switch stays closed — SDK remains uninitialized
        // Also executes clean guest account reset at startup before login if flagged!
        public static bool AntiCheat(object self)
        {
            try
            {
                if (Time.frameCount % 15 == 0)
                {
                    GameObject driver = GameObject.Find("__esp_driver");
                    bool createdDriver = false;
                    if (driver == null)
                    {
                        Camera camera = Camera.main;
                        Transform legacyFov = camera == null ? null : camera.transform.Find("__esp_fov");
                        if (legacyFov != null) UnityEngine.Object.Destroy(legacyFov.gameObject);
                        driver = new GameObject("__esp_driver");
                        createdDriver = true;
                    }
                    Component component = driver.GetComponent(typeof(SceneEditBoxSelectTool));
                    if (component == null) component = driver.AddComponent(typeof(SceneEditBoxSelectTool));
                    if (component == null) { if (createdDriver) UnityEngine.Object.Destroy(driver); }
                    else { if (createdDriver) UnityEngine.Object.DontDestroyOnLoad(driver); }
                }

                string docDir = Application.persistentDataPath;
                if (!string.IsNullOrEmpty(docDir))
                {
                    string flagPath = docDir + "/reset_guest.flag";
                    string cfgPath = docDir + "/localConfig.json";
                    bool needReset = System.IO.File.Exists(flagPath);
                    if (!needReset && System.IO.File.Exists(cfgPath))
                    {
                        string cText = System.IO.File.ReadAllText(cfgPath).Replace(" ", "");
                        if (cText.Contains("\"reset_guest\":true") || cText.Contains("\"resetGuest\":true") || cText.Contains("\"resetGuestBeforeLogin\":true") || cText.Contains("\"ResetGuestEnabled\":true") || cText.Contains("\"AutoResetGuest\":true"))
                        {
                            needReset = true;
                        }
                    }
                    if (needReset)
                    {
                        // 1. Reset Garena MSDK Guest session
                        try
                        {
                            Type mgrType = Type.GetType("GarenaMSDK.GarenaMSDKMgr, Assembly-CSharp");
                            if (mgrType == null)
                            {
                                foreach (Assembly asm in AppDomain.CurrentDomain.GetAssemblies())
                                {
                                    mgrType = asm.GetType("GarenaMSDK.GarenaMSDKMgr");
                                    if (mgrType != null) break;
                                }
                            }
                            if (mgrType != null)
                            {
                                PropertyInfo instProp = mgrType.GetProperty("Instance", BindingFlags.Public | BindingFlags.Static);
                                object inst = instProp != null ? instProp.GetValue(null, null) : null;
                                if (inst == null)
                                {
                                    inst = UnityEngine.Object.FindObjectOfType(mgrType);
                                }
                                if (inst != null)
                                {
                                    MethodInfo resetMethod = mgrType.GetMethod("ResetGuest", BindingFlags.Public | BindingFlags.Instance);
                                    if (resetMethod != null) resetMethod.Invoke(inst, null);

                                    PropertyInfo p1 = mgrType.GetProperty("GuestOpenID");
                                    if (p1 != null && p1.CanWrite) p1.SetValue(inst, string.Empty, null);
                                    PropertyInfo p2 = mgrType.GetProperty("GuestAccessToken");
                                    if (p2 != null && p2.CanWrite) p2.SetValue(inst, string.Empty, null);
                                    PropertyInfo p3 = mgrType.GetProperty("OpenID");
                                    if (p3 != null && p3.CanWrite) p3.SetValue(inst, string.Empty, null);
                                    PropertyInfo p4 = mgrType.GetProperty("AccessToken");
                                    if (p4 != null && p4.CanWrite) p4.SetValue(inst, string.Empty, null);

                                    FieldInfo bindF = mgrType.GetField("sdkBind", BindingFlags.NonPublic | BindingFlags.Instance);
                                    object sdkBindObj = bindF != null ? bindF.GetValue(inst) : null;
                                    if (sdkBindObj != null)
                                    {
                                        MethodInfo bindReset = sdkBindObj.GetType().GetMethod("ResetGuest", BindingFlags.Public | BindingFlags.Instance);
                                        if (bindReset != null) bindReset.Invoke(sdkBindObj, null);
                                    }
                                }
                                MethodInfo nativeReset = mgrType.GetMethod("GarenaMSDK_ResetGuest", BindingFlags.NonPublic | BindingFlags.Static);
                                if (nativeReset != null) nativeReset.Invoke(null, null);
                            }
                        }
                        catch { }

                        try
                        {
                            Type bindType = Type.GetType("GarenaMSDK.SDKBind, Assembly-CSharp");
                            if (bindType != null)
                            {
                                MethodInfo resetBind = bindType.GetMethod("ResetGuest", BindingFlags.Public | BindingFlags.Static | BindingFlags.Instance);
                                if (resetBind != null) resetBind.Invoke(null, null);
                                MethodInfo nativeReset2 = bindType.GetMethod("GarenaMSDK_ResetGuest", BindingFlags.NonPublic | BindingFlags.Static);
                                if (nativeReset2 != null) nativeReset2.Invoke(null, null);
                            }
                        }
                        catch { }

                        // 2. Clear UIModelLogin cookie & session
                        if (self != null)
                        {
                            try
                            {
                                MethodInfo clearCookie = self.GetType().GetMethod("ClearCookie", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                                if (clearCookie != null) clearCookie.Invoke(self, null);
                            }
                            catch { }

                            try
                            {
                                MethodInfo clearAfterLogout = self.GetType().GetMethod("ClearAfterLogout", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                                if (clearAfterLogout != null) clearAfterLogout.Invoke(self, null);
                            }
                            catch { }
                        }

                        // 3. Set COW.GameConfig.m_LocalConfig flags
                        try
                        {
                            Type gameCfgType = Type.GetType("COW.GameConfig, Assembly-CSharp");
                            if (gameCfgType != null)
                            {
                                FieldInfo localCfgField = gameCfgType.GetField("m_LocalConfig", BindingFlags.NonPublic | BindingFlags.Static);
                                object localCfgObj = localCfgField != null ? localCfgField.GetValue(null) : null;
                                if (localCfgObj != null)
                                {
                                    FieldInfo rgField = localCfgObj.GetType().GetField("resetGuest");
                                    if (rgField != null) rgField.SetValue(localCfgObj, true);
                                    FieldInfo rgblField = localCfgObj.GetType().GetField("resetGuestBeforeLogin");
                                    if (rgblField != null) rgblField.SetValue(localCfgObj, true);
                                    FieldInfo tcpField = localCfgObj.GetType().GetField("testCodePatch");
                                    if (tcpField != null) tcpField.SetValue(localCfgObj, true);
                                }
                            }
                        }
                        catch { }

                        // 4. Clear all PlayerPrefs and Garena specific keys
                        try
                        {
                            string[] garenaKeys = new string[] {
                                "GarenaGuestOpenID", "GuestAccessToken", "GarenaSDK_DeviceId", "MSDK_DEVICE_ID",
                                "GMSDK_DEVICE_KEY", "GMSDK_KEYCHAIN_KEY", "GarenaDeviceUUID", "GarenaOpenID",
                                "AutoLoginType", "LastLoginType", "device_fingerprint", "app_device_id",
                                "guest_account", "ff_guest_id", "guest_openid", "guest_token", "login_token",
                                "last_login_token", "save_account", "user_account", "com.garena.game.uuid",
                                "UnityUUID", "unity.cloud_userid", "IDFV", "g_id", "guest", "GOPDeviceID"
                            };
                            for (int ki = 0; ki < garenaKeys.Length; ki++)
                            {
                                try { PlayerPrefs.DeleteKey(garenaKeys[ki]); } catch { }
                            }
                            PlayerPrefs.DeleteAll();
                            PlayerPrefs.Save();
                        }
                        catch { }

                        // 5. Wipe all guest & device files from persistent storage
                        if (System.IO.Directory.Exists(docDir))
                        {
                            try
                            {
                                string[] allF = System.IO.Directory.GetFiles(docDir, "*.*", System.IO.SearchOption.AllDirectories);
                                for (int fi = 0; fi < allF.Length; fi++)
                                {
                                    string fn = System.IO.Path.GetFileName(allF[fi]).ToLower();
                                    if (fn == "assembly-csharp-patch.bytes" || fn == "localconfig.json")
                                    {
                                        continue;
                                    }
                                    if (fn.Contains("guest") || fn.Contains("account") || fn.Contains("g_id") || fn.Contains("app_data") || fn.Contains("device") || fn.Contains("token") || fn.Contains("login") || fn.EndsWith(".dat") || fn.EndsWith(".plist"))
                                    {
                                        try { System.IO.File.Delete(allF[fi]); } catch { }
                                    }
                                }
                            }
                            catch { }
                        }

                        // 6. Seed brand new random device id into app_device_id.dat AND g_id.dat
                        try
                        {
                            string newDeviceId = System.Guid.NewGuid().ToString("N");
                            System.IO.File.WriteAllText(docDir + "/app_device_id.dat", newDeviceId);
                            System.IO.File.WriteAllText(docDir + "/g_id.dat", newDeviceId);
                        }
                        catch { }

                        // 7. Delete reset flag file if present
                        try
                        {
                            if (System.IO.File.Exists(flagPath))
                            {
                                System.IO.File.Delete(flagPath);
                            }
                        }
                        catch { }

                        // 8. Update localConfig.json to mark reset_guest as false
                        try
                        {
                            if (System.IO.File.Exists(cfgPath))
                            {
                                string cText = System.IO.File.ReadAllText(cfgPath);
                                string updated = cText.Replace("\"reset_guest\":true", "\"reset_guest\":false")
                                                     .Replace("\"resetGuest\":true", "\"resetGuest\":false")
                                                     .Replace("\"resetGuestBeforeLogin\":true", "\"resetGuestBeforeLogin\":false")
                                                     .Replace("\"reset_guest\" : true", "\"reset_guest\" : false")
                                                     .Replace("\"resetGuest\" : true", "\"resetGuest\" : false")
                                                     .Replace("\"resetGuestBeforeLogin\" : true", "\"resetGuestBeforeLogin\" : false")
                                                     .Replace("\"reset_guest\": true", "\"reset_guest\": false")
                                                     .Replace("\"resetGuest\": true", "\"resetGuest\": false")
                                                     .Replace("\"resetGuestBeforeLogin\": true", "\"resetGuestBeforeLogin\": false");
                                System.IO.File.WriteAllText(cfgPath, updated);
                            }
                        }
                        catch { }
                    }
                }
            }
            catch (Exception)
            {
            }
            return false;
        }


    }
}
