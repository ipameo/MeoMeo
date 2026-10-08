import os

with open('3105-main/ThreeOneOSFive/ContentView.swift', 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

# 1. Add resetGuest to EspConfig
content = content.replace(
    'var NoRecoil: Bool = false',
    'var NoRecoil: Bool = false\n    var reset_guest: Bool = false\n    var resetGuest: Bool = false\n    var resetGuestBeforeLogin: Bool = false'
)

# 2. Decode it in init (we don't strictly need it in decode if we only write to it, but good practice)
content = content.replace(
    'NoRecoil = try c.decodeIfPresent(Bool.self, forKey: .NoRecoil) ?? false',
    'NoRecoil = try c.decodeIfPresent(Bool.self, forKey: .NoRecoil) ?? false\n        reset_guest = try c.decodeIfPresent(Bool.self, forKey: .reset_guest) ?? false\n        resetGuest = try c.decodeIfPresent(Bool.self, forKey: .resetGuest) ?? false\n        resetGuestBeforeLogin = try c.decodeIfPresent(Bool.self, forKey: .resetGuestBeforeLogin) ?? false'
)

# 3. Add the UI block
ui_block = '''
                // ── TIỆN ÍCH TÀI KHOẢN (RESET GUEST) ────────────────────
                CardView(title: "TIỆN ÍCH TÀI KHOẢN", icon: "person.crop.circle.badge.exclamationmark") {
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reset Acc Khách (Guest)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("Xoá acc khách bị khoá, đổi Device ID & làm mới MSDK")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(white: 0.45))
                            }
                            Spacer()
                        }

                        Button(action: {
                            performResetGuest()
                        }) {
                            HStack {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 15, weight: .bold))
                                Text("Xoá Acc Khách & Đổi ID Máy")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .foregroundColor(.white)
                            .background(Color(white: 0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(white: 0.30), lineWidth: 1)
                            )
                        }
                    }
                }

                // ── INJECT / UNINSTALL ─────────────────────────────────'''
content = content.replace('// ── INJECT / UNINSTALL ─────────────────────────────────', ui_block)

# 4. Add the performResetGuest function
func_block = '''    }

    // MARK: - GUI Actions (Calling MeoCore in libmeo.a)
    private func performResetGuest() {
        let fm = FileManager.default
        // 1. Clear iOS Keychain items for Garena / Guest
        let secClasses = [kSecClassGenericPassword, kSecClassInternetPassword]
        for secClass in secClasses {
            let query: [String: Any] = [kSecClass as String: secClass]
            SecItemDelete(query as CFDictionary)
        }

        guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: selectedBundleID) else { return }
        let docs = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents").path
        let lib = URL(fileURLWithPath: containerPath).appendingPathComponent("Library/Preferences").path
        
        // 2. Remove files
        try? fm.removeItem(atPath: (docs as NSString).appendingPathComponent("app_device_id.dat"))
        try? fm.removeItem(atPath: (docs as NSString).appendingPathComponent("g_id.dat"))
        try? fm.removeItem(atPath: (docs as NSString).appendingPathComponent("guest100067.dat"))
        
        let newUUID = UUID().uuidString
        try? newUUID.write(toFile: (docs as NSString).appendingPathComponent("app_device_id.dat"), atomically: true, encoding: .utf8)
        try? newUUID.write(toFile: (docs as NSString).appendingPathComponent("g_id.dat"), atomically: true, encoding: .utf8)
        
        let flagPath = (docs as NSString).appendingPathComponent("reset_guest.flag")
        try? "1".write(toFile: flagPath, atomically: true, encoding: .utf8)

        // Force reset flags in config
        config.reset_guest = true
        config.resetGuest = true
        config.resetGuestBeforeLogin = true
        syncConfig()
    }
'''

content = content.replace('    }\n\n    // MARK: - GUI Actions', func_block)

with open('3105-main/ThreeOneOSFive/ContentView.swift', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated ContentView with Reset Guest")
