import os

with open('3105-main/ThreeOneOSFive/ContentView.swift', 'r', encoding='utf-8') as f:
    content = f.read()

func_code = '''
    private func performResetGuest() {
        let fm = FileManager.default
        let secClasses = [kSecClassGenericPassword, kSecClassInternetPassword]
        for secClass in secClasses {
            let query: [String: Any] = [kSecClass as String: secClass]
            SecItemDelete(query as CFDictionary)
        }

        guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: selectedBundleID) else { return }
        let docs = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents").path
        
        try? fm.removeItem(atPath: (docs as NSString).appendingPathComponent("app_device_id.dat"))
        try? fm.removeItem(atPath: (docs as NSString).appendingPathComponent("g_id.dat"))
        try? fm.removeItem(atPath: (docs as NSString).appendingPathComponent("guest100067.dat"))
        
        let newUUID = UUID().uuidString
        try? newUUID.write(toFile: (docs as NSString).appendingPathComponent("app_device_id.dat"), atomically: true, encoding: .utf8)
        try? newUUID.write(toFile: (docs as NSString).appendingPathComponent("g_id.dat"), atomically: true, encoding: .utf8)
        
        let flagPath = (docs as NSString).appendingPathComponent("reset_guest.flag")
        try? "1".write(toFile: flagPath, atomically: true, encoding: .utf8)

        config.reset_guest = true
        config.resetGuest = true
        config.resetGuestBeforeLogin = true
        syncConfig()
    }

    private func loadConfig() {'''

content = content.replace('    private func loadConfig() {', func_code)

with open('3105-main/ThreeOneOSFive/ContentView.swift', 'w', encoding='utf-8') as f:
    f.write(content)
print("Added performResetGuest successfully!")
