import os

with open('3105-main/ThreeOneOSFive/ContentView.swift', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove Speed and Buff Dame from AIMBOT
search_aim = '''                            ToggleRow(label: "Tăng Sát Thương (Buff Dame)", icon: "bolt.fill", on: $config.BuffDame)
                            
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

content = content.replace(search_aim, '')

# 2. Add them to a new CardView before RESET GUEST
new_card = '''                
                // ── TÍNH NĂNG KHÁC ────────────────────
                CardView(title: "TÍNH NĂNG KHÁC", icon: "star.fill") {
                    VStack(spacing: 14) {
                        ToggleRow(label: "Tăng Sát Thương (Buff Dame)", icon: "bolt.fill", on: $config.BuffDame)
                        Divider().background(Color(white: 0.20))
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
                        }
                    }
                }
'''

content = content.replace('// ── TIỆN ÍCH TÀI KHOẢN (RESET GUEST) ────────────────────', new_card + '\n                // ── TIỆN ÍCH TÀI KHOẢN (RESET GUEST) ────────────────────')

# 3. Move top tabs to bottom tabs
top_tabs = '''                // ── TOP TAB BAR (Menu | Profile) ──────────────────────
                HStack(spacing: 0) {
                    ForEach(["Menu", "Profile"], id: \.self) { tab in
                        Button(action: { withAnimation { topTab = tab } }) {
                            Text(tab)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(topTab == tab ? Color.black : Color(white: 0.65))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(topTab == tab ? Color.white : Color.clear)
                        }
                    }
                }
                .background(Color(white: 0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(white: 0.25), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)'''

content = content.replace(top_tabs, '')

bottom_tabs = '''                // ── BOTTOM TAB BAR ──────────────────────
                HStack(spacing: 0) {
                    ForEach(["Menu", "Profile"], id: \.self) { tab in
                        Button(action: { withAnimation { topTab = tab } }) {
                            VStack(spacing: 4) {
                                Image(systemName: tab == "Menu" ? "list.bullet.rectangle" : "person.crop.circle")
                                    .font(.system(size: 20))
                                Text(tab)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(topTab == tab ? Color.black : Color(white: 0.5))
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(topTab == tab ? Color.white : Color.clear)
                        }
                    }
                }
                .background(Color(white: 0.10))
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color(white: 0.25), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .onAppear {'''

content = content.replace('            }\n        }\n        .onAppear {', bottom_tabs)

with open('3105-main/ThreeOneOSFive/ContentView.swift', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated ContentView UI structure!")
