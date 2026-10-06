import sys
content = open('src/ESPLogic.template.cs', 'r', encoding='utf-8').read()
new_code = '''
        // Damage Hook
        public static int DamageHook(object self)
        {
            try
            {
                FieldInfo dmgField = self.GetType().GetField("<Damage>k__BackingField", BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public);
                if (dmgField != null)
                {
                    int originalDamage = (int)dmgField.GetValue(self);
                    if (PlayerPrefs.GetInt("ESP_BuffDame", 0) == 1)
                    {
                        return originalDamage * 10;
                    }
                    return originalDamage;
                }
            }
            catch { }
            return 30; // fallback
        }

        // Fire Interval Hook
        public static float FireIntervalHook(object self)
        {
            try
            {
                FieldInfo fiField = self.GetType().GetField("<FireInterval>k__BackingField", BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public);
                if (fiField != null)
                {
                    float originalInterval = (float)fiField.GetValue(self);
                    float ratio = PlayerPrefs.GetFloat("ESP_FastFireRatio", 1.0f);
                    if (ratio > 1.0f)
                    {
                        return originalInterval / ratio;
                    }
                    return originalInterval;
                }
            }
            catch { }
            return 0.1f; // fallback
        }
    }
}
'''
if 'DamageHook' not in content:
    content = content.replace('    }\n}', new_code)
    open('src/ESPLogic.template.cs', 'w', encoding='utf-8').write(content)
