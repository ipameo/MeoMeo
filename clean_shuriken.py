import re

with open('3105-main/ThreeOneOSFive/ContentView.swift', 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(r'\s*ToggleRow\(label:\s*"Shuriken 1 Hit \(Buff Shuriken\)".*?MemoryScanner\.patchShuriken\(\)\s*\}\s*\}', '', content, flags=re.DOTALL)
content = re.sub(r'\s*public class MemoryScanner \{.*?^}$', '', content, flags=re.DOTALL | re.MULTILINE)

lines = content.split('\n')
lines = [l for l in lines if 'BuffShuriken' not in l and 'server_shuriken' not in l]
content = '\n'.join(lines)

with open('3105-main/ThreeOneOSFive/ContentView.swift', 'w', encoding='utf-8') as f:
    f.write(content)

with open('src/ESPLogic.template.cs', 'r', encoding='utf-8') as f:
    cs_content = f.read()

cs_lines = cs_content.split('\n')
cs_lines = [l for l in cs_lines if 'buffShuriken' not in l and 'server_shuriken' not in l]
cs_content = '\n'.join(cs_lines)

with open('src/ESPLogic.template.cs', 'w', encoding='utf-8') as f:
    f.write(cs_content)

print('Cleaned up shuriken!')
