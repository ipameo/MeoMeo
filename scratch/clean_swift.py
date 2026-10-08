import re
import os

files = [
    r'c:\Users\Administrator\Downloads\FIX-CRASH-ESP\project-freefire_c#\project-freefire_c#\3105-main\ThreeOneOSFive\ContentView.swift',
    r'c:\Users\Administrator\Downloads\FIX-CRASH-ESP\project-freefire_c#\project-freefire_c#\meo\ThreeOneOSFive\ContentView.swift'
]

for file in files:
    if not os.path.exists(file): continue
    with open(file, 'r', encoding='utf-8') as f:
        text = f.read()
    
    # Remove variables
    text = re.sub(r'[ \t]*@Published var pullAI.*?\n', '', text)
    # Remove UserDefaults reading
    text = re.sub(r'[ \t]*pullAI.*?=.*?UserDefaults\.standard.*?\n', '', text)
    # Remove UserDefaults writing
    text = re.sub(r'[ \t]*UserDefaults\.standard\.set\(pullAI.*?\n', '', text)
    # Remove sync calls
    text = re.sub(r'[ \t]*syncPullAIToJson\(bundleID: bundleID\)\n', '', text)
    # Remove function
    text = re.sub(r'[ \t]*private func syncPullAIToJson\(bundleID: String\) \{.*?^    \}[ \t]*\n', '', text, flags=re.DOTALL | re.MULTILINE)
    # Remove UI Card
    text = re.sub(r'[ \t]*// ── PULL AI PLAYER ─+.*?CardView\(title: "PULL AI PLAYER".*?^\s*\}\n\s*\}\n', '', text, flags=re.DOTALL | re.MULTILINE)
    
    with open(file, 'w', encoding='utf-8') as f:
        f.write(text)
