with open("src/ESPLogic.template.cs", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace(
    "if (Time.frameCount == -1) DummyReferences();",
    "if (Time.frameCount == -1) { Event.current.Use(); Vector2 m = Input.mousePosition; Vector2 d = Input.GetTouch(0).deltaPosition; int t = Input.touchCount; float f = Time.unscaledTime; }"
)

with open("src/ESPLogic.template.cs", "w", encoding="utf-8") as f:
    f.write(content)
