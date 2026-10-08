import sys

def merge():
    with open('espfix/src/ESPLogic.template.cs', 'r', encoding='utf-8') as f:
        espfix = f.read()
    
    with open('src/ESPLogic.template.cs', 'r', encoding='utf-8') as f:
        current = f.read()
        
    json_start = current.find('float lastUpdate = self.{{SCENE_STATE_FIELD}}.x;')
    json_end = current.find('if ((state & StateInitialized) == 0)')
    json_logic = current[json_start:json_end]

    draw_start = espfix.find('public static void Draw(SceneEditBoxSelectTool self)')
    
    sw_start = espfix.find('int screenHeight = Screen.height;', draw_start)
    gui_start = espfix.find('GUI.matrix = Matrix4x4.identity;', draw_start)
    
    drawing_logic = espfix[gui_start:]
    top_part = espfix[:sw_start+33]
    
    merged = top_part + '\n            ' + json_logic + """
            int mask = state & EspMask;
            int aimMode = (state & AimModeMask) >> AimModeShift;
            
            if (currentEvent.type != EventType.Repaint) { return; }
            Matrix4x4 savedMatrix = GUI.matrix;
            Color savedColor = GUI.color;
            try {
    """ + drawing_logic
    
    # Inject enemyCount initialization
    players_loop_start = merged.find('for (int index = 0; index < players.Count; index++)')
    merged = merged[:players_loop_start] + 'int enemyCount = 0;\n                                ' + merged[players_loop_start:]
    
    # Inject enemyCount++ inside the loop
    dying_check = merged.find('if (health <= 0 && !dying)')
    continue_after_dying = merged.find('continue;', dying_check) + 9
    merged = merged[:continue_after_dying] + '\n                                    enemyCount++;\n' + merged[continue_after_dying:]
    
    # After the loop finishes, we inject the drawing of enemyCount
    loop_end = merged.find('}\n                        }', continue_after_dying)
    count_draw = """
                                } // end for loop
                        
                                string countText = enemyCount > 0 ? ("Hoá iOS Cheat: " + str(enemyCount)) : "Clean";
                                float txtW = enemyCount > 0 ? 110f : 50f;
                                float centerOffset = txtW * 0.5f;
                                
                                GUI.color = new Color(0f, 0f, 0f, 0.7f);
                                GUI.Label(new Rect(((float)screenWidth * 0.5f) - centerOffset + 1f, 31f, txtW, 25f), countText);
                                GUI.color = enemyCount > 0 ? new Color(1f, 0.2f, 0.2f, 1f) : new Color(0.1f, 0.9f, 0.1f, 1f);
                                GUI.Label(new Rect(((float)screenWidth * 0.5f) - centerOffset, 30f, txtW, 25f), countText);
                        }"""
    count_draw = count_draw.replace("str(enemyCount)", "enemyCount")
    merged = merged[:loop_end] + count_draw + merged[loop_end+27:]
    
    with open('src/ESPLogic.template.cs', 'w', encoding='utf-8') as f:
        f.write(merged)
    print('Merged successfully')
    
merge()
