import os

with open('3105-main/ThreeOneOSFive/ContentView.swift', 'rb') as f:
    content = f.read().decode('utf-8', errors='ignore')

content = content.replace(
    'var NoRecoil: Bool = false\r\n    var AimTarget: Int = 0',
    'var NoRecoil: Bool = false\r\n    var BuffDame: Bool = false\r\n    var SpeedHack: Int = 1\r\n    var AimTarget: Int = 0'
)
content = content.replace(
    'var NoRecoil: Bool = false\n    var AimTarget: Int = 0',
    'var NoRecoil: Bool = false\n    var BuffDame: Bool = false\n    var SpeedHack: Int = 1\n    var AimTarget: Int = 0'
)

content = content.replace(
    'NoRecoil = try c.decodeIfPresent(Bool.self, forKey: .NoRecoil) ?? false\r\n        AimTarget = try c.decodeIfPresent(Int.self, forKey: .AimTarget) ?? 0',
    'NoRecoil = try c.decodeIfPresent(Bool.self, forKey: .NoRecoil) ?? false\r\n        BuffDame = try c.decodeIfPresent(Bool.self, forKey: .BuffDame) ?? false\r\n        SpeedHack = try c.decodeIfPresent(Int.self, forKey: .SpeedHack) ?? 1\r\n        AimTarget = try c.decodeIfPresent(Int.self, forKey: .AimTarget) ?? 0'
)
content = content.replace(
    'NoRecoil = try c.decodeIfPresent(Bool.self, forKey: .NoRecoil) ?? false\n        AimTarget = try c.decodeIfPresent(Int.self, forKey: .AimTarget) ?? 0',
    'NoRecoil = try c.decodeIfPresent(Bool.self, forKey: .NoRecoil) ?? false\n        BuffDame = try c.decodeIfPresent(Bool.self, forKey: .BuffDame) ?? false\n        SpeedHack = try c.decodeIfPresent(Int.self, forKey: .SpeedHack) ?? 1\n        AimTarget = try c.decodeIfPresent(Int.self, forKey: .AimTarget) ?? 0'
)

ui_search = 'on: $config.NoRecoil)'
ui_replace = '''on: $config.NoRecoil)
                            ToggleRow(label: "Tăng Sát Thương (Buff Dame)", icon: "bolt.fill", on: $config.BuffDame)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Tốc Độ (Speed Hack)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.8))
                                HStack(spacing: 8) {
                                    ForEach(1..<6, id: \\.self) { idx in
                                        Button(action: { config.SpeedHack = idx }) {
                                            Text("x\\(idx)")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(config.SpeedHack == idx ? Color.black : Color.white)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 36)
                                                .background(config.SpeedHack == idx ? Color.white : Color(white: 0.05))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                            }'''
content = content.replace(ui_search, ui_replace)

with open('3105-main/ThreeOneOSFive/ContentView.swift', 'wb') as f:
    f.write(content.encode('utf-8'))
print('Replaced successfully')
