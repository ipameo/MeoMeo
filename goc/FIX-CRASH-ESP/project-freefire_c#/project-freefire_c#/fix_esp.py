with open("src/ESPLogic.template.cs", "r", encoding="utf-8") as f:
    content = f.read()

# Add a read of SCENE_MENU_FIELD right after the driver check
content = content.replace(
    '            if (driverObject == null || driverObject.name != "__esp_driver")\n            {\n                return;\n            }',
    '            if (driverObject == null || driverObject.name != "__esp_driver")\n            {\n                return;\n            }\n\n            bool menuFlag = self.{{SCENE_MENU_FIELD}};'
)

with open("src/ESPLogic.template.cs", "w", encoding="utf-8") as f:
    f.write(content)

print("Done - added SCENE_MENU_FIELD read")
