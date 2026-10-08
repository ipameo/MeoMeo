using System;
using System.Collections;
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
        // Deprecated speed type binding: KGCCMFBFCAC

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
                // Rendering setup must not break the queried player state.
                stealthState = false;
            }
            return stealthState;
        }

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

            int screenWidth = Screen.width;
            int screenHeight = Screen.height;
            bool isIOS = Application.platform == RuntimePlatform.IPhonePlayer;
            float panelWidth = Mathf.Clamp((float)screenWidth * 0.42f, 360f, 500f);
            float panelHeight = 430f;
            int state = (int)self.DIGCJIKHGJP.x;
            bool menuOpen = self.AFHAOIAPPNB;

            if ((state & StateInitialized) == 0)
            {
                state = StateInitialized | EspMask | DefaultAimState;
                int defaultAux = (13 << AuxFovRadiusShift) | AuxSkeleton;
                int initPackedAux = defaultAux & AuxMask;
                self.OHPFLEDNOJK = new Vector2(
                    ((float)screenWidth - panelWidth) * 0.5f,
                    ((float)screenHeight - panelHeight) * 0.5f);
                self.DIGCJIKHGJP = new Vector2(
                    (float)state,
                    -AuxStateMarker - (float)initPackedAux);
                menuOpen = false;
            }

            int mask = state & EspMask;
            int activeTab = (state & TabMask) >> TabShift;
            if (activeTab > 2)
            {
                activeTab = 0;
            }
            int tapCount = (state & TapMask) >> TapShift;
            int aimMode = (state & AimModeMask) >> AimModeShift;
            int headRateIndex = (state & HeadRateMask) >> HeadRateShift;
            float encodedAuxState = self.DIGCJIKHGJP.y;
            int auxState;
            int lastTapTick;
            if (encodedAuxState <= -AuxStateMarker)
            {
                int packedAuxState = (int)(-encodedAuxState - AuxStateMarker);
                auxState = packedAuxState & AuxMask;
                lastTapTick = packedAuxState >> AuxTickShift;
            }
            else
            {
                auxState = 0;
                lastTapTick = (int)(Mathf.Abs(encodedAuxState) * 4f);
            }
            if ((state & AimEnabled) != 0 && (state & AimSystemEnabled) != 0)
            {
                state &= ~AimSystemEnabled;
            }
            bool threeFingerActive = (state & StateThreeFinger) != 0;
            bool threeFingersDown = Input.touchCount >= 3;

            if (threeFingersDown && !threeFingerActive)
            {
                state |= StateThreeFinger;
            }
            else if (!threeFingersDown && threeFingerActive)
            {
                state &= ~StateThreeFinger;
                int nowTick = (int)(Time.unscaledTime * 4f);
                if (lastTapTick > 0 && nowTick - lastTapTick > 16)
                {
                    tapCount = 0;
                }
                tapCount++;
                if (tapCount >= 5)
                {
                    tapCount = 0;
                    menuOpen = true;
                }
                state = (state & ~TapMask) | (tapCount << TapShift);
                lastTapTick = nowTick;
            }

            float maxPanelX = (float)screenWidth - panelWidth - 8f;
            float maxPanelY = (float)screenHeight - panelHeight - 8f;
            if (maxPanelX < 8f) maxPanelX = 8f;
            if (maxPanelY < 8f) maxPanelY = 8f;
            float panelX = Mathf.Clamp(self.OHPFLEDNOJK.x, 8f, maxPanelX);
            float panelY = Mathf.Clamp(self.OHPFLEDNOJK.y, 8f, maxPanelY);
            float rowHeight = 43f;
            float firstRowY = panelY + 58f;
            float footerY = panelY + panelHeight - 55f;
            Rect panelRect = new Rect(panelX, panelY, panelWidth, panelHeight);
            Rect headerRect = new Rect(panelX, panelY, panelWidth, 49f);
            Rect closeRect = new Rect(panelX + panelWidth - 43f, panelY + 9f, 32f, 30f);
            Rect row1Rect = new Rect(panelX + 18f, firstRowY, panelWidth - 36f, 40f);
            Rect row2Rect = new Rect(panelX + 18f, firstRowY + rowHeight, panelWidth - 36f, 40f);
            Rect row3Rect = new Rect(panelX + 18f, firstRowY + rowHeight * 2f, panelWidth - 36f, 40f);
            Rect row4Rect = new Rect(panelX + 18f, firstRowY + rowHeight * 3f, panelWidth - 36f, 40f);
            Rect row5Rect = new Rect(panelX + 18f, firstRowY + rowHeight * 4f, panelWidth - 36f, 40f);
            Rect row6Rect = new Rect(panelX + 18f, firstRowY + rowHeight * 5f, panelWidth - 36f, 40f);
            Rect row7Rect = new Rect(panelX + 18f, firstRowY + rowHeight * 6f, panelWidth - 36f, 40f);
            float tabWidth = (panelWidth - 32f) / 3f;
            Rect espTab = new Rect(panelX + 12f, footerY, tabWidth, 42f);
            Rect aimTab = new Rect(panelX + 16f + tabWidth, footerY, tabWidth, 42f);
            Rect settingsTab = new Rect(panelX + 20f + tabWidth * 2f, footerY, tabWidth, 42f);

            int rowCount = 0;
            if (menuOpen)
            {
                if (activeTab == 0)
                {
                    rowCount = 7;
                }
                else if (activeTab == 1)
                {
                    rowCount = 2;
                    if ((state & AimEnabled) != 0)
                    {
                        rowCount = 7;
                    }
                    else if ((state & AimSystemEnabled) != 0)
                    {
                        rowCount = 4;
                    }
                    else
                    {
                        rowCount = 3;
                    }
                }
                else
                {
                    rowCount = 2;
                }
            }

            bool dragging = (state & StateDragging) != 0;
            bool releasedDrag = false;
            Vector2 pointer = currentEvent.mousePosition;
            if (menuOpen && currentEvent.type == EventType.MouseDown
                && headerRect.Contains(pointer) && !closeRect.Contains(pointer))
            {
                state |= StateDragging;
                dragging = true;
                currentEvent.Use();
            }
            else if (menuOpen && currentEvent.type == EventType.MouseDrag && dragging)
            {
                Vector2 delta = currentEvent.delta;
                panelX = Mathf.Clamp(panelX + delta.x, 8f, maxPanelX);
                panelY = Mathf.Clamp(panelY + delta.y, 8f, maxPanelY);
                self.OHPFLEDNOJK = new Vector2(panelX, panelY);
                currentEvent.Use();
            }
            else if (currentEvent.type == EventType.MouseUp && dragging)
            {
                state &= ~StateDragging;
                dragging = false;
                releasedDrag = true;
                currentEvent.Use();
            }

            if (menuOpen && currentEvent.type == EventType.MouseDrag
                && (state & AimEnabled) != 0 && activeTab == 1)
            {
                Rect sRow = row6Rect;
                float sTrackX = sRow.x + 130f;
                float sTrackW = sRow.width - 144f;
                if (pointer.x >= sRow.x && pointer.x <= sRow.x + sRow.width
                    && pointer.y >= sRow.y && pointer.y <= sRow.y + sRow.height)
                {
                    float rel = Mathf.Clamp01(
                        (pointer.x - sTrackX) / sTrackW);
                    int newIdx = Mathf.Clamp(
                        Mathf.RoundToInt(rel * 31f), 0, 31);
                    auxState = (auxState & ~AuxFovRadiusMask)
                        | (newIdx << AuxFovRadiusShift);
                    currentEvent.Use();
                }
            }

            if (menuOpen && currentEvent.type == EventType.MouseDown
                && (state & AimEnabled) != 0 && activeTab == 1)
            {
                Rect sRow = row6Rect;
                float sTrackX = sRow.x + 130f;
                float sTrackW = sRow.width - 144f;
                if (pointer.x >= sRow.x && pointer.x <= sRow.x + sRow.width
                    && pointer.y >= sRow.y && pointer.y <= sRow.y + sRow.height)
                {
                    float rel = Mathf.Clamp01(
                        (pointer.x - sTrackX) / sTrackW);
                    int newIdx = Mathf.Clamp(
                        Mathf.RoundToInt(rel * 31f), 0, 31);
                    auxState = (auxState & ~AuxFovRadiusMask)
                        | (newIdx << AuxFovRadiusShift);
                    currentEvent.Use();
                }
            }

            if (menuOpen && currentEvent.type == EventType.MouseUp
                && !dragging && !releasedDrag)
            {
                if (closeRect.Contains(pointer))
                {
                    menuOpen = false;
                }
                else if (espTab.Contains(pointer))
                {
                    activeTab = 0;
                }
                else if (aimTab.Contains(pointer))
                {
                    activeTab = 1;
                }
                else if (settingsTab.Contains(pointer))
                {
                    activeTab = 2;
                }
                else
                {
                    int selectedRow = -1;
                    if (row1Rect.Contains(pointer)) selectedRow = 0;
                    else if (row2Rect.Contains(pointer)) selectedRow = 1;
                    else if (row3Rect.Contains(pointer)) selectedRow = 2;
                    else if (row4Rect.Contains(pointer)) selectedRow = 3;
                    else if (row5Rect.Contains(pointer)) selectedRow = 4;
                    else if (row6Rect.Contains(pointer)) selectedRow = 5;
                    else if (row7Rect.Contains(pointer)) selectedRow = 6;

                    if (selectedRow >= 0 && selectedRow < rowCount)
                    {
                        if (activeTab == 0)
                        {
                            if (selectedRow == 6)
                            {
                                auxState ^= AuxSkeleton;
                            }
                            else
                            {
                                int espBit = selectedRow == 0 ? EspMaster
                                    : (selectedRow == 1 ? EspBox
                                    : (selectedRow == 2 ? EspTracer
                                    : (selectedRow == 3 ? EspHealth
                                    : (selectedRow == 4 ? EspName : EspDistance))));
                                mask ^= espBit;
                            }
                        }
                        else if (activeTab == 1)
                        {
                            int action = 0;
                            if (selectedRow == 0) action = AimActionSilentToggle;
                            else if (selectedRow == 1) action = AimActionSystemToggle;
                            else if ((state & AimEnabled) != 0)
                            {
                                if (selectedRow == 2) action = AimActionSilentTarget;
                                else if (selectedRow == 3) action = AimActionHeadRate;
                                else if (selectedRow == 4) action = AimActionFov;
                                else if (selectedRow == 5) action = AimActionFovRadius;
                                else if (selectedRow == 6) action = AimActionNoRecoil;
                            }
                            else if ((state & AimSystemEnabled) != 0)
                            {
                                if (selectedRow == 2) action = AimActionSystemTarget;
                                else if (selectedRow == 3) action = AimActionNoRecoil;
                            }
                            else if (selectedRow == 2)
                            {
                                action = AimActionNoRecoil;
                            }
                            if (action == AimActionSilentToggle)
                            {
                                state ^= AimEnabled;
                                if ((state & AimEnabled) != 0)
                                {
                                    state &= ~AimSystemEnabled;
                                }
                            }
                            else if (action == AimActionSystemToggle)
                            {
                                state ^= AimSystemEnabled;
                                if ((state & AimSystemEnabled) != 0)
                                {
                                    state &= ~AimEnabled;
                                }
                            }
                            else if (action == AimActionSilentTarget)
                            {
                                aimMode = (aimMode + 1) % 3;
                                state = (state & ~AimModeMask)
                                    | (aimMode << AimModeShift);
                            }
                            else if (action == AimActionHeadRate)
                            {
                                headRateIndex = (headRateIndex + 1) % 5;
                                state = (state & ~HeadRateMask)
                                    | (headRateIndex << HeadRateShift);
                            }
                            else if (action == AimActionFov)
                            {
                                mask ^= EspFov;
                            }
                            else if (action == AimActionFovRadius)
                            {
                                Rect rowRect = selectedRow == 0 ? row1Rect
                                    : (selectedRow == 1 ? row2Rect
                                    : (selectedRow == 2 ? row3Rect
                                    : (selectedRow == 3 ? row4Rect
                                    : (selectedRow == 4 ? row5Rect
                                    : (selectedRow == 5 ? row6Rect : row7Rect)))));
                                float trackX = rowRect.x + 130f;
                                float trackW = rowRect.width - 144f;
                                float rel = Mathf.Clamp01(
                                    (pointer.x - trackX) / trackW);
                                int newIdx = Mathf.Clamp(
                                    Mathf.RoundToInt(rel * 31f), 0, 31);
                                auxState = (auxState & ~AuxFovRadiusMask)
                                    | (newIdx << AuxFovRadiusShift);
                            }
                            else if (action == AimActionSystemTarget)
                            {
                                state ^= AimSystemHead;
                            }
                            else if (action == AimActionNoRecoil)
                            {
                                state ^= NoRecoil;
                            }
                        }
                        else if (selectedRow == 0)
                        {
                            mask = EspMask;
                            state &= ~(AimEnabled | AimModeMask | NoRecoil
                                | HeadRateMask | AimSystemEnabled
                                | AimSystemHead);
                            state |= DefaultAimState;
                            auxState = (13 << AuxFovRadiusShift) | AuxSkeleton;
                            aimMode = 2;
                            headRateIndex = 3;
                        }
                        else if (selectedRow == 1)
                        {
                            menuOpen = false;
                        }
                    }
                }
                if (panelRect.Contains(pointer))
                {
                    currentEvent.Use();
                }
            }

            state = (state & ~EspMask) | mask;
            state = (state & ~TabMask) | (activeTab << TabShift);
            self.AFHAOIAPPNB = menuOpen;
            self.OHPFLEDNOJK = new Vector2(panelX, panelY);
            int packedAux = (lastTapTick << AuxTickShift) | (auxState & AuxMask);
            self.DIGCJIKHGJP = new Vector2(
                (float)state,
                -AuxStateMarker - (float)packedAux);

            if (currentEvent.type != EventType.Repaint)
            {
                return;
            }

            Matrix4x4 savedMatrix = GUI.matrix;
            Color savedColor = GUI.color;
            try
            {
                GUI.matrix = Matrix4x4.identity;
                // iOS: Periodic proactive GC sweep to continuously flush temporary heap objects/strings and prevent Jetsam OOM
                if (isIOS && (Time.frameCount % 240 == 0))
                {
                    GC.Collect();
                }
                Texture2D pixel = Texture2D.whiteTexture;
                if (pixel != null
                    && screenWidth > 0 && screenHeight > 0)
                {
                    Camera camera = Camera.main;
                    Player localPlayer = GameFacade.CurrentLocalPlayer();
                    Transform localRoot = localPlayer == null ? null : localPlayer.RootTransform;

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

                    if ((mask & EspMaster) != 0)
                    {
                        JMAGGLCNGIG match = GameFacade.CurrentMatch();
                        IList players = match == null ? null : match.ILPNGCMEFFI();
                        GameObject localObject = localPlayer == null
                            ? null : localPlayer.gameObject;
                        if (camera != null && localPlayer != null
                            && localObject != null && localObject.activeInHierarchy
                            && localRoot != null && players != null)
                        {
                            for (int index = 0; index < players.Count; index++)
                            {
                                try
                                {
                                Player player = players[index] as Player;
                                if (player == null)
                                {
                                    continue;
                                }
                                GameObject playerObject = player.gameObject;
                                if (playerObject == null || !playerObject.activeInHierarchy)
                                {
                                    continue;
                                }
                                Transform root = player.RootTransform;
                                if (player.IsLocalPlayer()
                                    || player.IsLocalTeammate(false) || !player.IsVisible())
                                {
                                    continue;
                                }

                                bool dying = player.IsDieing;
                                int health = player.CurHP;
                                int maximumHealth = player.MaxHP;
                                if (health <= 0 && !dying)
                                {
                                    continue;
                                }
                                Transform head = player.GetHeadTF();
                                if (root == null || head == null)
                                {
                                    continue;
                                }

                                float distance = Vector3.Distance(localRoot.position, root.position);
                                if (distance > 250f)
                                {
                                    continue;
                                }
                                Vector3 feetScreen = camera.WorldToScreenPoint(root.position);
                                Vector3 headScreen = camera.WorldToScreenPoint(head.position);
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
                                        ? new Color(1f, 0.15f, 0.15f, 1f)
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
                                        ? new Color(1f, 0.15f, 0.15f, 1f)
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
                                    if (isIOS)
                                    {
                                        // iOS: Distance culling (<= 38m) and Zero-GC rendering to prevent Jetsam OOM & Metal buffer overflow
                                        if (distance <= 38f)
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
                                                ? new Color(1f, 0.15f, 0.15f, 1f)
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
                                    else
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

                                        Transform[] bones = new Transform[16];
                                        bones[0] = sHead;
                                        bones[1] = sNeck;
                                        bones[2] = sSpine;
                                        bones[3] = sHip;
                                        bones[4] = sLArm;
                                        bones[5] = sLElbow;
                                        bones[6] = sLHand;
                                        bones[7] = sRArm;
                                        bones[8] = sRElbow;
                                        bones[9] = sRHand;
                                        bones[10] = sLLeg;
                                        bones[11] = sLAnkle;
                                        bones[12] = sLFoot;
                                        bones[13] = sRLeg;
                                        bones[14] = sRAnkle;
                                        bones[15] = sRFoot;

                                        Vector2[] pts = new Vector2[16];
                                        bool[] valid = new bool[16];
                                        for (int bi = 0; bi < 16; bi++)
                                        {
                                            Transform tf = bones[bi];
                                            if (tf != null)
                                            {
                                                Vector3 sp = camera.WorldToScreenPoint(tf.position);
                                                if (sp.z > 0f && !float.IsNaN(sp.x) && !float.IsNaN(sp.y)
                                                    && !float.IsInfinity(sp.x) && !float.IsInfinity(sp.y))
                                                {
                                                    pts[bi] = new Vector2(sp.x, (float)screenHeight - sp.y);
                                                    valid[bi] = true;
                                                }
                                            }
                                        }

                                        float skelThickness = 1.6f;
                                        GUI.color = dying
                                            ? new Color(1f, 0.15f, 0.15f, 1f)
                                            : new Color(0.9f, 0.95f, 1f, 0.95f);

                                        for (int boneIdx = 0; boneIdx < 15; boneIdx++)
                                        {
                                            int iA = 0;
                                            int iB = 0;
                                            if (boneIdx == 0) { iA = 0; iB = 1; }
                                            else if (boneIdx == 1) { iA = 1; iB = 2; }
                                            else if (boneIdx == 2) { iA = 2; iB = 3; }
                                            else if (boneIdx == 3) { iA = 1; iB = 4; }
                                            else if (boneIdx == 4) { iA = 4; iB = 5; }
                                            else if (boneIdx == 5) { iA = 5; iB = 6; }
                                            else if (boneIdx == 6) { iA = 1; iB = 7; }
                                            else if (boneIdx == 7) { iA = 7; iB = 8; }
                                            else if (boneIdx == 8) { iA = 8; iB = 9; }
                                            else if (boneIdx == 9) { iA = 3; iB = 10; }
                                            else if (boneIdx == 10) { iA = 10; iB = 11; }
                                            else if (boneIdx == 11) { iA = 11; iB = 12; }
                                            else if (boneIdx == 12) { iA = 3; iB = 13; }
                                            else if (boneIdx == 13) { iA = 13; iB = 14; }
                                            else { iA = 14; iB = 15; }

                                            if (valid[iA] && valid[iB])
                                            {
                                                Vector2 a = pts[iA];
                                                Vector2 b = pts[iB];
                                                float dx = b.x - a.x;
                                                float dy = b.y - a.y;
                                                float len = Mathf.Sqrt(dx * dx + dy * dy);
                                                if (len > 0.5f && len < 500f)
                                                {
                                                    float angle = Mathf.Atan2(dy, dx) * 57.29578f;
                                                    GUI.matrix = Matrix4x4.TRS(
                                                        new Vector3(a.x, a.y, 0f),
                                                        Quaternion.Euler(0f, 0f, angle),
                                                        Vector3.one);
                                                    GUI.DrawTexture(
                                                        new Rect(0f, -skelThickness * 0.5f, len, skelThickness),
                                                        pixel);
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
                                    if (!isIOS || distance <= 120f)
                                    {
                                        string nickname = player.NickName;
                                        if (string.IsNullOrEmpty(nickname)) nickname = "Hoá iOS Cheat";

                                        Color bodyBg = dying
                                            ? new Color(0.6f, 0.12f, 0.12f, 0.85f)
                                            : new Color(0.14f, 0.62f, 0.28f, 0.85f);
                                        Color bottomBandColor = dying
                                            ? new Color(0.35f, 0.05f, 0.05f, 0.95f)
                                            : new Color(0.05f, 0.32f, 0.12f, 0.95f);
                                        Color borderColor = dying
                                            ? new Color(0.85f, 0.25f, 0.25f, 0.9f)
                                            : new Color(0.25f, 0.82f, 0.42f, 0.9f);

                                        float charWidth = 7.5f;
                                        float textW = Mathf.Clamp((float)nickname.Length * charWidth, 42f, 150f);
                                        float tagW = textW + 18f;
                                        float tagH = 22f;
                                        float bottomBarH = 3.5f;
                                        float midX = left + width * 0.5f;
                                        float tagX = midX - tagW * 0.5f;
                                        // Tăng độ cao đặt thẻ lên cách đỉnh đầu 28px để không bị che khuất đầu nhân vật
                                        float tagY = top - tagH - 28f;

                                        // Thân thẻ tên (xanh lá cây bình thường, đỏ khi knock)
                                        GUI.color = bodyBg;
                                        GUI.DrawTexture(new Rect(tagX, tagY, tagW, tagH - bottomBarH), pixel);

                                        // Viền dưới đáy (đậm màu hơn)
                                        GUI.color = bottomBandColor;
                                        GUI.DrawTexture(new Rect(tagX, tagY + tagH - bottomBarH, tagW, bottomBarH), pixel);

                                        // Mũi nhọn chỉ xuống ở chính giữa đáy
                                        GUI.DrawTexture(new Rect(midX - 5f, tagY + tagH, 10f, 1.5f), pixel);
                                        GUI.DrawTexture(new Rect(midX - 3.5f, tagY + tagH + 1.5f, 7f, 1.5f), pixel);
                                        GUI.DrawTexture(new Rect(midX - 2f, tagY + tagH + 3f, 4f, 1.5f), pixel);
                                        GUI.DrawTexture(new Rect(midX - 0.5f, tagY + tagH + 4.5f, 1f, 1.5f), pixel);

                                        // Viền bao quanh nhẹ (trên, trái, phải)
                                        GUI.color = borderColor;
                                        GUI.DrawTexture(new Rect(tagX, tagY, tagW, 1f), pixel);
                                        GUI.DrawTexture(new Rect(tagX, tagY, 1f, tagH), pixel);
                                        GUI.DrawTexture(new Rect(tagX + tagW - 1f, tagY, 1f, tagH), pixel);

                                        // Chữ tên màu trắng nổi bật, đẩy lên trên vùng thân thẻ, không bị đè lên thanh đậm ở đáy
                                        float labelX = midX - textW * 0.5f;
                                        float labelY = tagY - 1f;

                                        if (isIOS)
                                        {
                                            GUI.color = Color.white;
                                            GUI.Label(new Rect(labelX, labelY, textW + 10f, 18f), nickname);
                                        }
                                        else
                                        {
                                            GUI.color = new Color(0f, 0f, 0f, 0.75f);
                                            GUI.Label(new Rect(labelX + 1f, labelY + 1f, textW + 10f, 18f), nickname);
                                            GUI.color = Color.white;
                                            GUI.Label(new Rect(labelX, labelY, textW + 10f, 18f), nickname);
                                        }
                                    }
                                }

                                if ((mask & EspDistance) != 0)
                                {
                                    if (!isIOS || distance <= 150f)
                                    {
                                        int distanceValue = (int)distance;
                                        if (distanceValue < 0) distanceValue = 0;
                                        if (distanceValue > 999) distanceValue = 999;
                                        string distStr = distanceValue.ToString() + "m";
                                        float textW = (float)distStr.Length * 7.5f;
                                        float labelX = (left + width * 0.5f) - (textW * 0.5f);
                                        float labelY = top + height + 3f;

                                        if (isIOS)
                                        {
                                            GUI.color = dying
                                                ? new Color(1f, 0.25f, 0.25f, 1f)
                                                : Color.white;
                                            GUI.Label(new Rect(labelX, labelY, textW + 10f, 18f), distStr);
                                        }
                                        else
                                        {
                                            // Bóng chữ màu đen giúp số và chữ 'm' cực kỳ rõ nét trên mọi nền map
                                            GUI.color = new Color(0f, 0f, 0f, 0.85f);
                                            GUI.Label(new Rect(labelX + 1f, labelY + 1f, textW + 10f, 18f), distStr);

                                            // Chữ hiển thị: Đỏ khi knock, trắng sáng khi bình thường
                                            GUI.color = dying
                                                ? new Color(1f, 0.25f, 0.25f, 1f)
                                                : Color.white;
                                            GUI.Label(new Rect(labelX, labelY, textW + 10f, 18f), distStr);
                                        }
                                    }
                                }
                                }
                                catch (Exception)
                                {
                                    // A recycled entity is skipped without aborting the frame.
                                }
                            }
                        }
                    }

                    if (menuOpen)
                    {
                        GUI.matrix = Matrix4x4.identity;
                        if (pixel != null)
                        {
                            Color panelBg = new Color(0.08f, 0.08f, 0.08f, 0.95f);
                            Color frameC = new Color(0.2f, 0.2f, 0.2f, 1f);
                            GUI.color = panelBg;
                            GUI.DrawTexture(panelRect, pixel);
                            GUI.color = frameC;
                            float ft = 1f;
                            GUI.DrawTexture(new Rect(panelX, panelY, panelWidth, ft), pixel);
                            GUI.DrawTexture(new Rect(panelX, panelY + panelHeight - ft, panelWidth, ft), pixel);
                            GUI.DrawTexture(new Rect(panelX, panelY, ft, panelHeight), pixel);
                            GUI.DrawTexture(new Rect(panelX + panelWidth - ft, panelY, ft, panelHeight), pixel);
                        }
                        Color headerTop = new Color(0.12f, 0.12f, 0.12f, 1f);
                        Color headerBot = new Color(0.06f, 0.06f, 0.06f, 1f);
                        GUI.color = headerTop;
                        GUI.DrawTexture(new Rect(
                            panelX, panelY, panelWidth, 24f), pixel);
                        GUI.color = headerBot;
                        GUI.DrawTexture(new Rect(
                            panelX, panelY + 24f, panelWidth, 25f), pixel);
                        GUI.color = new Color(1f, 1f, 1f, 0.05f);
                        GUI.DrawTexture(new Rect(
                            panelX + 8f, panelY + 45f,
                            panelWidth - 16f, 4f), pixel);
                        GUI.color = new Color(1f, 1f, 1f, 0.02f);
                        GUI.DrawTexture(new Rect(
                            panelX + 12f, panelY + 44f,
                            panelWidth - 24f, 6f), pixel);
                        GUI.color = new Color(1f, 1f, 1f, 0.15f);
                        GUI.DrawTexture(new Rect(
                            panelX + 2f, panelY + 47f,
                            panelWidth - 4f, 1f), pixel);
                        float titleScale = 1.4f;
                        float titleTextWidth = 80f;
                        float titleTextHeight = 20f;
                        float titleX = panelX + panelWidth * 0.5f - (titleTextWidth * titleScale * 0.5f);
                        float titleY = panelY + 10f;

                        GUI.matrix = Matrix4x4.TRS(
                            new Vector3(titleX, titleY, 0f),
                            Quaternion.identity,
                            new Vector3(titleScale, titleScale, 1f));

                        GUI.color = new Color(0f, 0f, 0f, 0.5f);
                        GUI.Label(new Rect(1f, 1f, titleTextWidth, titleTextHeight), "Hoá iOS Cheat");

                        GUI.color = new Color(0.95f, 0.95f, 0.95f, 1f);
                        GUI.Label(new Rect(0f, 0f, titleTextWidth, titleTextHeight), "Hoá iOS Cheat");

                        GUI.matrix = Matrix4x4.identity;
                        GUI.color = new Color(0.85f, 0.16f, 0.18f, 1f);
                        GUI.DrawTexture(closeRect, pixel);
                        GUI.color = Color.white;
                        GUI.Label(new Rect(
                            closeRect.x + 11f, closeRect.y + 5f,
                            18f, 20f), "X");

                        for (int row = 0; row < rowCount; row++)
                        {
                            Rect rowRect = row == 0 ? row1Rect
                                : (row == 1 ? row2Rect
                                : (row == 2 ? row3Rect
                                : (row == 3 ? row4Rect
                                : (row == 4 ? row5Rect
                                : (row == 5 ? row6Rect : row7Rect)))));
                            int rowBit = 0;
                            string rowLabel = null;
                            if (activeTab == 0)
                            {
                                rowBit = row == 0 ? EspMaster
                                    : (row == 1 ? EspBox
                                    : (row == 2 ? EspTracer
                                    : (row == 3 ? EspHealth
                                    : (row == 4 ? EspName
                                    : (row == 5 ? EspDistance : -AuxSkeleton)))));
                                rowLabel = row == 0 ? "Enable ESP"
                                    : (row == 1 ? "Player box"
                                    : (row == 2 ? "Top tracer"
                                    : (row == 3 ? "Health bar"
                                    : (row == 4 ? "Player name"
                                    : (row == 5 ? "Distance" : "Skeleton")))));
                            }
                            else if (activeTab == 1)
                            {
                                if (row == 0)
                                {
                                    rowBit = AimEnabled;
                                    rowLabel = "Silent aim";
                                }
                                else if (row == 1)
                                {
                                    rowBit = AimSystemEnabled;
                                    rowLabel = "Aim system";
                                }
                                else if ((state & AimEnabled) != 0)
                                {
                                    if (row == 2)
                                    {
                                        rowLabel = aimMode == 0 ? "Target: BODY"
                                            : (aimMode == 1 ? "Target: HEAD" : "Target: MIXED");
                                    }
                                    else if (row == 3)
                                    {
                                        rowLabel = headRateIndex == 0 ? "Headshot rate: 0%"
                                            : (headRateIndex == 1 ? "Headshot rate: 25%"
                                            : (headRateIndex == 2 ? "Headshot rate: 50%"
                                            : (headRateIndex == 3 ? "Headshot rate: 75%"
                                            : "Headshot rate: 100%")));
                                    }
                                    else if (row == 4)
                                    {
                                        rowBit = EspFov;
                                        rowLabel = "Aim FOV circle";
                                    }
                                    else if (row == 5)
                                    {
                                        int fovIdx = (auxState & AuxFovRadiusMask)
                                            >> AuxFovRadiusShift;
                                        rowLabel = "FOV radius: " + (int)(50f + (float)fovIdx * 11.29f);
                                    }
                                    else if (row == 6)
                                    {
                                        rowBit = NoRecoil;
                                        rowLabel = "No recoil";
                                    }
                                }
                                else if ((state & AimSystemEnabled) != 0)
                                {
                                    if (row == 2)
                                    {
                                        rowLabel = (state & AimSystemHead) != 0
                                            ? "Aim system target: HEAD"
                                            : "Aim system target: NECK";
                                    }
                                    else if (row == 3)
                                    {
                                        rowBit = NoRecoil;
                                        rowLabel = "No recoil";
                                    }
                                }
                                else if (row == 2)
                                {
                                    rowBit = NoRecoil;
                                    rowLabel = "No recoil";
                                }
                            }
                            else
                            {
                                rowLabel = row == 0 ? "RESET DEFAULTS" : "HIDE MENU";
                            }
                            bool showToggle = rowBit != 0;
                            GUI.color = new Color(0.024f, 0.1f, 0.14f, 1f);
                            GUI.DrawTexture(rowRect, pixel);
                            GUI.color = new Color(0f, 0.78f, 0.98f, 0.5f);
                            GUI.DrawTexture(new Rect(
                                rowRect.x, rowRect.y,
                                2f, rowRect.height), pixel);
                            GUI.color = new Color(0.72f, 0.94f, 0.98f, 1f);
                            GUI.Label(new Rect(
                                rowRect.x + 14f, rowRect.y + 10f,
                                rowRect.width - (showToggle ? 90f : 28f), 22f),
                                rowLabel);

                            if (showToggle)
                            {
                                bool enabled = rowBit < 0
                                    ? (auxState & -rowBit) != 0
                                    : (activeTab == 0
                                        ? (mask & rowBit) != 0
                                        : (rowBit <= EspFov
                                            ? (mask & rowBit) != 0
                                            : (state & rowBit) != 0));
                                float trkW = 48f;
                                float trkH = 24f;
                                Rect track = new Rect(
                                    rowRect.x + rowRect.width - 62f,
                                    rowRect.y + 8f, trkW, trkH);
                                GUI.color = enabled
                                    ? new Color(0.1f, 0.78f, 0.92f, 1f)
                                    : new Color(0.04f, 0.13f, 0.18f, 1f);
                                GUI.DrawTexture(track, pixel);
                                float knobD = 18f;
                                float knobX = enabled
                                    ? track.x + trkW - knobD - 3f
                                    : track.x + 3f;
                                float knobY = track.y + 3f;
                                GUI.color = enabled
                                    ? new Color(1f, 1f, 1f, 1f)
                                    : new Color(0.6f, 0.7f, 0.75f, 1f);
                                GUI.DrawTexture(new Rect(knobX, knobY, knobD, knobD), pixel);
                            }

                            if (activeTab == 1 && row == 5
                                && (state & AimEnabled) != 0)
                            {
                                int fovIdx = (auxState & AuxFovRadiusMask)
                                    >> AuxFovRadiusShift;
                                float tX = rowRect.x + 130f;
                                float tW = rowRect.width - 144f;
                                float tY = rowRect.y + 15f;
                                float tH = 10f;
                                GUI.color = new Color(
                                    0.04f, 0.13f, 0.18f, 1f);
                                GUI.DrawTexture(new Rect(
                                    tX, tY, tW, tH), pixel);
                                float fillW = (float)fovIdx / 31f * tW;
                                if (fillW > 1f)
                                {
                                    GUI.color = new Color(
                                        0.3f, 1f, 0f, 1f);
                                    GUI.DrawTexture(new Rect(
                                        tX, tY, fillW, tH), pixel);
                                }
                                GUI.color = new Color(
                                    0.85f, 0.98f, 1f, 1f);
                                GUI.DrawTexture(new Rect(
                                    tX + fillW - 3f, tY - 4f,
                                    6f, tH + 8f), pixel);
                            }
                        }

                        Color tabActiveBg = new Color(0f, 0.78f, 0.95f, 1f);
                        Color tabInactiveBg = new Color(0.02f, 0.1f, 0.14f, 1f);
                        Color tabActiveText = new Color(0.02f, 0.07f, 0.1f, 1f);
                        Color tabInactiveText = new Color(0.55f, 0.87f, 0.95f, 1f);
                        bool espA = activeTab == 0;
                        GUI.color = espA ? tabActiveBg : tabInactiveBg;
                        GUI.DrawTexture(espTab, pixel);
                        GUI.color = espA ? tabActiveText : tabInactiveText;
                        GUI.Label(new Rect(
                            espTab.x + espTab.width * 0.5f - 12f,
                            espTab.y + 11f, 36f, 22f), "ESP");

                        bool aimA = activeTab == 1;
                        GUI.color = aimA ? tabActiveBg : tabInactiveBg;
                        GUI.DrawTexture(aimTab, pixel);
                        GUI.color = aimA ? tabActiveText : tabInactiveText;
                        GUI.Label(new Rect(
                            aimTab.x + aimTab.width * 0.5f - 12f,
                            aimTab.y + 11f, 36f, 22f), "AIM");

                        bool setA = activeTab == 2;
                        GUI.color = setA ? tabActiveBg : tabInactiveBg;
                        GUI.DrawTexture(settingsTab, pixel);
                        GUI.color = setA ? tabActiveText : tabInactiveText;
                        GUI.Label(new Rect(
                            settingsTab.x + settingsTab.width * 0.5f - 31f,
                            settingsTab.y + 11f, 80f, 22f), "SETTINGS");
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

        public static CGKJLKPMGDJ SilentAim(Player self)
        {
            if (self == null)
            {
                return null;
            }
            CGKJLKPMGDJ info = self.FDMIEDDNCEC;
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
            int state = menu == null ? 0 : (int)menu.DIGCJIKHGJP.x;
            if ((state & AimEnabled) == 0 || (state & AimSystemEnabled) != 0)
            {
                return info;
            }

            JMAGGLCNGIG match = GameFacade.CurrentMatch();
            IList players = match == null ? null : match.ILPNGCMEFFI();
            Camera camera = Camera.main;
            if (players == null || camera == null)
            {
                return info;
            }

            int aimMode = (state & AimModeMask) >> AimModeShift;
            int headRate = ((state & HeadRateMask) >> HeadRateShift) * 25;
            bool aimAtHead = aimMode == 1
                || (aimMode == 2 && UnityEngine.Random.Range(0, 100) < headRate);
            Vector3 aimStart = self.AimStartPostion;
            float encodedAux = menu == null ? 0f : menu.DIGCJIKHGJP.y;
            int aux = encodedAux <= -AuxStateMarker
                ? (int)(-encodedAux - AuxStateMarker) & AuxMask
                : 0;
            int fovIdx = (aux & AuxFovRadiusMask) >> AuxFovRadiusShift;
            float fovRadius = 50f + (float)fovIdx * 11.29f;
            float fovSqr = fovRadius * fovRadius;
            float bestScore = fovSqr;
            Collider bestCollider = null;
            Vector3 bestPosition = Vector3.zero;

            for (int index = 0; index < players.Count; index++)
            {
                Player candidate = players[index] as Player;
                GameObject candidateObject = candidate == null ? null : candidate.gameObject;
                if (candidateObject == null || !candidateObject.activeInHierarchy
                    || candidate.IsLocalPlayer()
                    || candidate.CurHP <= 0
                    || candidate.IsLocalTeammate(false)
                    || candidate.IsLocalTeammate(true))
                {
                    continue;
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

                if (Vector3.Distance(hitPosition, aimStart) > 150f)
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
                float score = dx * dx + dy * dy;
                if (float.IsNaN(score) || float.IsInfinity(score)
                    || score >= bestScore)
                {
                    continue;
                }

                bestScore = score;
                bestCollider = hitCollider;
                bestPosition = hitPosition;
            }

            if (bestCollider != null)
            {
                Vector3 rayDirection = Vector3.Normalize(bestPosition - aimStart);
                info.JHAINOBIFMA = bestCollider.gameObject;
                info.JINDNOFABKB = bestCollider;
                info.HPCOJHGFEEG = bestPosition;
                info.DOJDNHCGFGK = bestPosition;
                info.HLDECMJFKJK = rayDirection;
                info.EKPLMDDKOGB = aimStart;
                info.ONMKMEGMHOL = aimStart;
                info.DKPDBLLJEAA = (LKOOALMKJND)1;
                info.EFMBNPNFGHM = false;
                info.CEOKOILBODN = false;
                info.CLOLKHNMNEK = (short)0;
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
                GameObject driver = GameObject.Find("__esp_driver");
            SceneEditBoxSelectTool menu = driver == null
                ? null
                : (SceneEditBoxSelectTool)driver.GetComponent(typeof(SceneEditBoxSelectTool));
            int state = menu == null ? 0 : (int)menu.DIGCJIKHGJP.x;
            if ((state & AimSystemEnabled) == 0 || (state & AimEnabled) != 0
                || self.gameObject == null || !self.gameObject.activeInHierarchy
                || self.IsLocalPlayer() || self.CurHP <= 0
                || self.IsLocalTeammate(false) || self.IsLocalTeammate(true))
            {
                return original;
            }

            Collider targetCollider = null;
            if ((state & AimSystemHead) != 0)
            {
                targetCollider = self.HeadCollider;
            }
            else
            {
                Transform neck = self.NeckBone;
                IList fireColliders = self.FireColliders;
                float nearestDistance = 10000f;
                if (neck != null && fireColliders != null)
                {
                    for (int index = 0; index < fireColliders.Count; index++)
                    {
                        Collider candidateCollider = fireColliders[index] as Collider;
                        if (candidateCollider == null)
                        {
                            continue;
                        }

                        float distance = Vector3.Distance(
                            candidateCollider.transform.position, neck.position);
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

            if (targetCollider == null)
            {
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
                GameObject driver = GameObject.Find("__esp_driver");
            SceneEditBoxSelectTool menu = driver == null
                ? null
                : (SceneEditBoxSelectTool)driver.GetComponent(typeof(SceneEditBoxSelectTool));
            int state = menu == null ? 0 : (int)menu.DIGCJIKHGJP.x;
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
    }
}
