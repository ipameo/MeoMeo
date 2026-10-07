import re

with open('src/ESPLogic.template.cs', 'r', encoding='utf-8') as f:
    content = f.read()

draw_pattern = r'(//\s*\{\{SCENE_MENU_FIELD\}\}\s*public static void Draw\(SceneEditBoxSelectTool self\)|public static void Draw\(SceneEditBoxSelectTool self\)).*?(?=public static \{\{AIM_INFO_TYPE\}\} SilentAim)'

new_draw = """// {{SCENE_MENU_FIELD}}
        public static void Draw(SceneEditBoxSelectTool self)
        {
            if (self == null) return;
            Event currentEvent = Event.current;
            if (currentEvent == null) return;

            GameObject driverObject = self.gameObject;
            if (driverObject == null || driverObject.name != "__esp_driver") return;

            int screenWidth = Screen.width;
            int screenHeight = Screen.height;
            
            float lastUpdate = self.{{SCENE_STATE_FIELD}}.x;
            if (Time.realtimeSinceStartup - lastUpdate > 1.0f || lastUpdate == 0)
            {
                self.{{SCENE_STATE_FIELD}} = new Vector2(Time.realtimeSinceStartup, self.{{SCENE_STATE_FIELD}}.y);
                try
                {
                    string configPath = Application.persistentDataPath + "/localConfig.json";
                    if (System.IO.File.Exists(configPath))
                    {
                        string json = System.IO.File.ReadAllText(configPath).Replace(" ", "");
                        
                        int s = DefaultAimState | StateInitialized;
                        if (json.Contains("\\"EspMaster\\":true")) s |= EspMaster;
                        if (json.Contains("\\"EspBox\\":true")) s |= EspBox;
                        if (json.Contains("\\"EspHealth\\":true")) s |= EspHealth;
                        if (json.Contains("\\"EspTracer\\":true")) s |= EspTracer;
                        if (json.Contains("\\"AimEnabled\\":true")) s |= AimEnabled;
                        if (json.Contains("\\"AimSystemEnabled\\":true")) s |= AimSystemEnabled;
                        if (json.Contains("\\"EspFov\\":true")) s |= EspFov;
                        if (json.Contains("\\"NoRecoil\\":true")) s |= NoRecoil;
                        
                        int a = (13 << AuxFovRadiusShift);
                        if (json.Contains("\\"EspSkeleton\\":true")) a |= AuxSkeleton;
                        
                        self.{{SCENE_POSITION_FIELD}} = new Vector2((float)s, (float)a);
                    }
                }
                catch { }
            }

            int state = (int)self.{{SCENE_POSITION_FIELD}}.x;
            int auxState = (int)self.{{SCENE_POSITION_FIELD}}.y;
            
            if ((state & StateInitialized) == 0)
            {
                state = StateInitialized | EspMask | DefaultAimState;
                int defaultAux = (13 << AuxFovRadiusShift) | AuxSkeleton;
                self.{{SCENE_POSITION_FIELD}} = new Vector2((float)state, (float)defaultAux);
            }

            int mask = state & EspMask;
            int aimMode = (state & AimModeMask) >> AimModeShift;

            if (currentEvent.type != EventType.Repaint)
            {
                return;
            }

            Matrix4x4 savedMatrix = GUI.matrix;
            Color savedColor = GUI.color;

            try
            {
                Texture2D pixel = Texture2D.whiteTexture;

                if ((mask & EspMaster) != 0)
                {
                    {{MATCH_TYPE}} match = GameFacade.CurrentMatch();
                    IList players = match == null ? null : match.{{MATCH_PLAYERS_METHOD}}();
                    Camera camera = Camera.main;

                    if (players != null && camera != null)
                    {
                        int enemyCount = 0;
                        for (int index = 0; index < players.Count; index++)
                        {
                            Player candidate = players[index] as Player;
                            GameObject candidateObject = candidate == null ? null : candidate.gameObject;
                            if (candidateObject == null || !candidateObject.activeInHierarchy || candidate.IsLocalPlayer() || candidate.CurHP <= 0 || candidate.IsLocalTeammate(false) || candidate.IsLocalTeammate(true))
                            {
                                continue;
                            }
                            enemyCount++;
                            if (pixel == null) continue;
                            
                            Vector3 footPos = candidateObject.transform.position;
                            Vector3 headPos = footPos + new Vector3(0f, 1.8f, 0f);
                            Transform headBone = candidate.GetHeadTF();
                            if (headBone != null)
                            {
                                headPos = headBone.position + new Vector3(0f, 0.2f, 0f);
                            }
                            Vector3 screenFoot = camera.WorldToScreenPoint(footPos);
                            Vector3 screenHead = camera.WorldToScreenPoint(headPos);

                            if (screenFoot.z > 0f)
                            {
                                float height = screenFoot.y - screenHead.y;
                                float width = height / 2f;
                                float x = screenHead.x - width / 2f;
                                float y = (float)screenHeight - screenFoot.y;

                                if ((mask & EspBox) != 0)
                                {
                                    GUI.color = Color.red;
                                    GUI.DrawTexture(new Rect(x, y, width, 1f), pixel);
                                    GUI.DrawTexture(new Rect(x, y + height, width, 1f), pixel);
                                    GUI.DrawTexture(new Rect(x, y, 1f, height), pixel);
                                    GUI.DrawTexture(new Rect(x + width, y, 1f, height + 1f), pixel);
                                }

                                if ((mask & EspTracer) != 0)
                                {
                                    GUI.color = Color.white;
                                    float cx = (float)screenWidth / 2f;
                                    float cy = 0f;
                                    GUI.DrawTexture(new Rect(screenFoot.x - 2f, y - 2f, 4f, 4f), pixel);
                                }

                                if ((mask & EspHealth) != 0)
                                {
                                    int curHp = candidate.CurHP;
                                    int maxHp = candidate.MaxHP;
                                    if (maxHp > 0)
                                    {
                                        float hpRatio = (float)curHp / (float)maxHp;
                                        GUI.color = Color.black;
                                        GUI.DrawTexture(new Rect(x - 5f, y - 1f, 3f, height + 2f), pixel);
                                        GUI.color = hpRatio > 0.5f ? Color.green : (hpRatio > 0.2f ? Color.yellow : Color.red);
                                        float hpH = height * hpRatio;
                                        GUI.DrawTexture(new Rect(x - 4f, y + height - hpH, 1f, hpH), pixel);
                                    }
                                }
                            }
                        }
                        
                        string countText = enemyCount > 0 ? ("Hoá iOS Cheat: " + enemyCount) : "Clean";
                        float txtW = enemyCount > 0 ? 110f : 50f;
                        float centerOffset = txtW * 0.5f;
                        
                        GUI.color = new Color(0f, 0f, 0f, 0.7f);
                        GUI.Label(new Rect(((float)screenWidth * 0.5f) - centerOffset + 1f, 31f, txtW, 25f), countText);
                        GUI.color = enemyCount > 0 ? new Color(1f, 0.2f, 0.2f, 1f) : new Color(0.1f, 0.9f, 0.1f, 1f);
                        GUI.Label(new Rect(((float)screenWidth * 0.5f) - centerOffset, 30f, txtW, 25f), countText);
                    }
                }
            }
            catch (Exception)
            {
            }

            GUI.matrix = savedMatrix;
            GUI.color = savedColor;
        }

        """

content = re.sub(draw_pattern, new_draw, content, flags=re.DOTALL)

with open('src/ESPLogic.template.cs', 'w', encoding='utf-8') as f:
    f.write(content)
