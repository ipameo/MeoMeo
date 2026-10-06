import sys
content = open('src/ESPLogic.template.cs', 'r', encoding='utf-8').read()
content = content.replace('bool buffDame = json.Contains("\"BuffDame\":true");', '''bool buffDame = json.Contains("\"BuffDame\":true");
                            PlayerPrefs.SetInt("ESP_BuffDame", buffDame ? 1 : 0);
                            float fastFire = 1.0f;
                            int fireIdx = json.IndexOf("\"FastFireRatio\":");
                            if (fireIdx != -1)
                            {
                                int fStart = fireIdx + 16;
                                int fEnd = json.IndexOf(",", fStart);
                                if (fEnd == -1) fEnd = json.IndexOf("}", fStart);
                                if (fEnd != -1)
                                {
                                    string fStr = json.Substring(fStart, fEnd - fStart).Trim();
                                    float.TryParse(fStr, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out fastFire);
                                }
                            }
                            if (fastFire < 1.0f) fastFire = 1.0f;
                            PlayerPrefs.SetFloat("ESP_FastFireRatio", fastFire);''')
open('src/ESPLogic.template.cs', 'w', encoding='utf-8').write(content)
