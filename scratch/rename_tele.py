import os

with open('3105-main/ThreeOneOSFive/ContentView.swift', 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

content = content.replace('Text("t.me/cheatmeo")', 'Text("@cheatmeo")')
content = content.replace('Text("t.me/truongdeptrai7")', 'Text("@truongdeptrai7")')

with open('3105-main/ThreeOneOSFive/ContentView.swift', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated Telegram strings")
