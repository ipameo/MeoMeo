import os
import re

with open('3105-main/ThreeOneOSFive/ContentView.swift', 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

match = re.search(r'Text\(\".*?iOS Cheat\"', content)
if match:
    print('Found Text:', repr(match.group(0)))
    content = re.sub(r'Text\(\".*?iOS Cheat\"', 'Text(\"MeoMeoExt\"', content)
    
with open('3105-main/ThreeOneOSFive/ContentView.swift', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated MeoMeoExt")
