import SwiftUI
import UIKit
import Foundation
import CommonCrypto
import MachO
import Darwin

// MARK: - Anti-Hex & Anti-Tamper Security Core
struct SecurityShield {
    // De-obfuscate XOR byte arrays at runtime so plain strings are NEVER visible in binary Hex/Strings
    private static let xorKey: UInt8 = 0x5A

    static func decodeBytes(_ bytes: [UInt8]) -> String {
        let decoded = bytes.map { $0 ^ xorKey }
        return String(bytes: decoded, encoding: .utf8) ?? ""
    }

    // Anti-Hex endpoint resolution
    static var apiBaseURL: String {
        let enc: [UInt8] = [50, 46, 46, 42, 96, 117, 117, 107, 106, 105, 116, 104, 105, 98, 116, 104, 105, 110, 116, 104, 106, 110, 96, 104, 106, 106, 109]
        return decodeBytes(enc)
    }

    // Anti-Hex auth token resolution
    static var githubToken: String {
        let enc: [UInt8] = [61, 50, 42, 5, 55, 32, 44, 99, 110, 11, 28, 14, 99, 20, 56, 22, 35, 51, 27, 21, 16, 35, 46, 28, 23, 22, 109, 24, 109, 54, 18, 59, 98, 55, 104, 23, 59, 29, 20, 108]
        return decodeBytes(enc)
    }

    // Anti-Hex binary payload URL resolution
    static var payloadDownloadURL: String {
        let enc: [UInt8] = [50, 46, 46, 42, 41, 96, 117, 117, 40, 59, 45, 116, 61, 51, 46, 50, 47, 56, 47, 41, 63, 40, 57, 53, 52, 46, 63, 52, 46, 116, 57, 53, 55, 117, 34, 47, 59, 52, 46, 40, 47, 52, 117, 44, 51, 42, 55, 53, 60, 117, 55, 59, 51, 52, 117, 27, 41, 41, 63, 55, 56, 54, 35, 119, 25, 9, 50, 59, 40, 42, 119, 42, 59, 46, 57, 50, 116, 56, 35, 46, 63, 41]
        return decodeBytes(enc)
    }

    // Anti-Tamper: Detect Debugger / P_TRACED hook
    static var isDebuggerAttached: Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let junk = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        if junk == 0 {
            return (info.kp_proc.p_flag & P_TRACED) != 0
        }
        return false
    }

    // Anti-Tamper: Detect suspicious dynamic libraries (Frida, Substrate, Cycript)
    static var isHooked: Bool {
        let suspiciousLibraries = [
            "FridaGadget", "frida", "cynject", "libcycript", "SubstrateLoader"
        ]
        let count = _dyld_image_count()
        for i in 0..<count {
            if let namePtr = _dyld_get_image_name(i) {
                let name = String(cString: namePtr).lowercased()
                for sus in suspiciousLibraries {
                    if name.contains(sus.lowercased()) {
                        return true
                    }
                }
            }
        }
        return false
    }
}

// MARK: - API Config
struct APIConfig {
    static var baseURL: String {
        return SecurityShield.apiBaseURL
    }
    static let sessionTTL: TimeInterval = 25 * 60
    static let heartbeatInterval: TimeInterval = 2.0
}

// MARK: - Config Model
struct EspConfig: Codable, Equatable {
    var meomeo: String = ""
    var sig: String = ""
    var token: String = ""
    var ts: Int = 0
    var system_active: Bool = true
    var server_esp: Bool = true
    var server_aim: Bool = true
    var server_box: Bool = true
    var server_line: Bool = true
    var server_skeleton: Bool = true
    var server_name: Bool = true
    var server_distance: Bool = true
    var server_health: Bool = true
    var server_headshot: Bool = true
    var testCodePatch: Bool = true
    // ESP
    var EspMaster: Bool = false
    var EspBox: Bool = false
    var EspLine: Bool = false
    var EspName: Bool = false
    var EspHealth: Bool = false
    var EspDistance: Bool = false
    var EspTracer: Bool = false
    var EspSkeleton: Bool = false
    // Aim
    var AimEnabled: Bool = false       // Silent Aim
    var AimSystemEnabled: Bool = false // Aim System
    var EspFov: Bool = false
    var NoRecoil: Bool = false
    var AimTarget: Int = 0             // 0=Head, 1=Neck, 2=Body
    var FovSize: Float = 60.0
    var HeadshotRate: Float = 60.0

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        meomeo = try c.decodeIfPresent(String.self, forKey: .meomeo) ?? ""
        sig = try c.decodeIfPresent(String.self, forKey: .sig) ?? ""
        token = try c.decodeIfPresent(String.self, forKey: .token) ?? ""
        ts = try c.decodeIfPresent(Int.self, forKey: .ts) ?? 0
        system_active = try c.decodeIfPresent(Bool.self, forKey: .system_active) ?? true
        server_esp = try c.decodeIfPresent(Bool.self, forKey: .server_esp) ?? true
        server_aim = try c.decodeIfPresent(Bool.self, forKey: .server_aim) ?? true
        server_box = try c.decodeIfPresent(Bool.self, forKey: .server_box) ?? true
        server_line = try c.decodeIfPresent(Bool.self, forKey: .server_line) ?? true
        server_skeleton = try c.decodeIfPresent(Bool.self, forKey: .server_skeleton) ?? true
        server_name = try c.decodeIfPresent(Bool.self, forKey: .server_name) ?? true
        server_distance = try c.decodeIfPresent(Bool.self, forKey: .server_distance) ?? true
        server_health = try c.decodeIfPresent(Bool.self, forKey: .server_health) ?? true
        server_headshot = try c.decodeIfPresent(Bool.self, forKey: .server_headshot) ?? true
        testCodePatch = try c.decodeIfPresent(Bool.self, forKey: .testCodePatch) ?? true
        EspMaster = try c.decodeIfPresent(Bool.self, forKey: .EspMaster) ?? false
        EspBox = try c.decodeIfPresent(Bool.self, forKey: .EspBox) ?? false
        EspLine = try c.decodeIfPresent(Bool.self, forKey: .EspLine) ?? false
        EspName = try c.decodeIfPresent(Bool.self, forKey: .EspName) ?? false
        EspHealth = try c.decodeIfPresent(Bool.self, forKey: .EspHealth) ?? false
        EspDistance = try c.decodeIfPresent(Bool.self, forKey: .EspDistance) ?? false
        EspTracer = try c.decodeIfPresent(Bool.self, forKey: .EspTracer) ?? false
        EspSkeleton = try c.decodeIfPresent(Bool.self, forKey: .EspSkeleton) ?? false
        AimEnabled = try c.decodeIfPresent(Bool.self, forKey: .AimEnabled) ?? false
        AimSystemEnabled = try c.decodeIfPresent(Bool.self, forKey: .AimSystemEnabled) ?? false
        EspFov = try c.decodeIfPresent(Bool.self, forKey: .EspFov) ?? false
        NoRecoil = try c.decodeIfPresent(Bool.self, forKey: .NoRecoil) ?? false
        AimTarget = try c.decodeIfPresent(Int.self, forKey: .AimTarget) ?? 0
        FovSize = try c.decodeIfPresent(Float.self, forKey: .FovSize) ?? 60.0
        HeadshotRate = try c.decodeIfPresent(Float.self, forKey: .HeadshotRate) ?? 60.0
    }
}

// MARK: - License Manager
class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published var isAuthed = false
    @Published var authError: String? = nil
    @Published var deviceExpires: String = ""
    @Published var systemActive: Bool = true
    @Published var serverFeatures: [String: Bool] = [:]

    var onLiveStateChanged: ((Bool) -> Void)?
    var onTokenRefreshed: (() -> Void)?

    private var sessionToken: String = ""
    private var currentMeomeo: String = ""
    private var currentSig: String = ""
    private var currentToken: String = ""
    private var currentTs: Int = 0
    private var heartbeatTimer: Timer?

    var storedKey: String {
        get { UserDefaults.standard.string(forKey: "license_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "license_key") }
    }

    var deviceId: String {
        if let stored = UserDefaults.standard.string(forKey: "device_uuid"), !stored.isEmpty {
            return stored
        }
        let uuid = (UIDevice.current.identifierForVendor ?? UUID()).uuidString
        UserDefaults.standard.set(uuid, forKey: "device_uuid")
        return uuid
    }

    // MARK: - Auth
    func authenticate(key: String, completion: @escaping (Bool, String?) -> Void) {
        let url = URL(string: "\(APIConfig.baseURL)/api/auth")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["device_id": deviceId, "key": key]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.authError = error.localizedDescription
                    completion(false, self.authError)
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.authError = "Invalid response"
                    completion(false, self.authError)
                    return
                }

                if let errMsg = json["error"] as? String {
                    self.authError = errMsg
                    self.isAuthed = false
                    completion(false, errMsg)
                    return
                }

                self.sessionToken = json["session_token"] as? String ?? ""
                self.currentMeomeo = json["meomeo"] as? String ?? ""
                self.currentSig = json["sig"] as? String ?? ""
                self.currentToken = json["token"] as? String ?? ""
                self.currentTs = json["ts"] as? Int ?? 0
                self.deviceExpires = json["device_expires"] as? String ?? ""
                self.systemActive = json["system_active"] as? Bool ?? true
                self.serverFeatures = json["features"] as? [String: Bool] ?? [:]
                self.storedKey = key
                self.isAuthed = true
                self.authError = nil
                self.onTokenRefreshed?()
                completion(true, nil)
            }
        }.resume()
    }

    // MARK: - Heartbeat
    func startHeartbeat() {
        startBackgroundKeepAlive()
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: APIConfig.heartbeatInterval, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }

    func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        stopBackgroundKeepAlive()
    }

    private func sendHeartbeat() {
        guard !sessionToken.isEmpty else { return }
        let url = URL(string: "\(APIConfig.baseURL)/api/heartbeat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["device_id": deviceId, "session_token": sessionToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 8

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self else { return }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            
            let isSysActive = json["system_active"] as? Bool ?? (json["ok"] as? Bool ?? false)
            let feats = json["features"] as? [String: Bool] ?? [:]

            DispatchQueue.main.async {
                let previousState = self.systemActive
                self.systemActive = isSysActive
                self.serverFeatures = feats

                if !isSysActive {
                    self.currentMeomeo = ""
                    self.currentSig = ""
                    self.currentToken = ""
                    self.currentTs = 0
                    if previousState != false {
                        self.onLiveStateChanged?(false)
                    }
                } else {
                    if let m = json["meomeo"] as? String { self.currentMeomeo = m }
                    if let s = json["sig"] as? String { self.currentSig = s }
                    if let tk = json["token"] as? String { self.currentToken = tk }
                    if let t = json["ts"] as? Int { self.currentTs = t }
                    if previousState != true {
                        self.onLiveStateChanged?(true)
                    }
                    self.onTokenRefreshed?()
                }
            }
        }.resume()
    }

    // MARK: - Token access
    func getMeomeo() -> String { currentMeomeo }
    func getSig() -> String { currentSig }
    func getToken() -> String { currentToken }
    func getTs() -> Int { currentTs }

    // MARK: - Check status
    func checkStatus(completion: @escaping (Bool) -> Void) {
        var urlStr = "\(APIConfig.baseURL)/api/status?device_id=\(deviceId)"
        if !currentMeomeo.isEmpty {
            urlStr += "&meomeo=\(currentMeomeo)"
        }
        guard let url = URL(string: urlStr) else { completion(false); return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = json["ok"] as? Bool else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            DispatchQueue.main.async {
                if let tk = json["token"] as? String { self.currentToken = tk }
                if let t = json["ts"] as? Int { self.currentTs = t }
                if let feats = json["features"] as? [String: Bool] { self.serverFeatures = feats }
                self.isAuthed = ok
                self.onTokenRefreshed?()
                completion(ok)
            }
        }.resume()
    }
}

// MARK: - Custom Toggle Style (matches reference image)
struct SlimToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { configuration.isOn.toggle() } }) {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? Color.white : Color(white: 0.25))
                    .frame(width: 46, height: 26)
                Circle()
                    .fill(configuration.isOn ? Color.black : Color.white)
                    .frame(width: 20, height: 20)
                    .padding(3)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Main View
struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @ObservedObject private var license = LicenseManager.shared

    @State private var config = EspConfig()
    @State private var isInjecting = false
    @State private var hasInjected = false
    @State private var topTab: String = "Menu"   // "Menu" | "Log"
    @State private var gameTab: String = "ff"    // "ff" | "ffmax"
    @State private var logs: [String] = []
    @State private var licenseKeyInput: String = ""
    @State private var isAuthenticating = false

    private var selectedBundleID: String {
        gameTab == "ff" ? "com.dts.freefireth" : "com.dts.freefiremax"
    }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.07).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── HEADER: MeoMeo Cheat & iOS Version ────────────────
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.yellow)
                        Text("MeoMeo Cheat")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Text("Phiên bản iOS: \(UIDevice.current.systemVersion) (\(UIDevice.current.model))")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.6))
                }
                .padding(.top, 14)
                .padding(.bottom, 6)

                // ── TOP TAB BAR ──────────────────────────────────────
                HStack(spacing: 0) {
                    ForEach(["Menu", "Log"], id: \.self) { tab in
                        Button(action: { withAnimation { topTab = tab } }) {
                            Text(tab)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(topTab == tab ? .black : Color(white: 0.5))
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(topTab == tab ? Color.white : Color.clear)
                        }
                    }
                }
                .background(Color(white: 0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)

                // ── GAME SELECTOR ─────────────────────────────────────
                HStack(spacing: 0) {
                    ForEach(["ff", "ffmax"], id: \.self) { id in
                        let label = (id == "ff") ? "Free Fire" : "Free Fire MAX"
                        Button(action: {
                            gameTab = id
                            if hasInjected { syncConfig() }
                        }) {
                            Text(label)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(gameTab == id ? .black : Color(white: 0.5))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(gameTab == id ? Color.white : Color.clear)
                        }
                    }
                }
                .background(Color(white: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                // ── CONTENT AREA ──────────────────────────────────────
                if topTab == "Menu" {
                    if !license.isAuthed {
                        authView
                    } else {
                        menuView
                    }
                } else {
                    logView
                }
            }
        }
        .onAppear {
            loadConfig()
            licenseKeyInput = license.storedKey
            if let containerPath = ContainerStore.resolveAppContainerPath(bundleID: selectedBundleID) {
                let patchURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents/Assembly-CSharp-patch.bytes")
                if FileManager.default.fileExists(atPath: patchURL.path) {
                    hasInjected = true
                    log("⚡ Mod detected in game container")
                }
            }
            // Setup live server listener
            license.onLiveStateChanged = { active in
                self.syncConfig()
                if active {
                    self.log("⚡ Server ONLINE: Đã phục hồi chức năng!")
                } else {
                    self.log("⛔ Server OFFLINE: Đã khoá tất cả chức năng!")
                }
            }
            license.onTokenRefreshed = {
                self.syncConfig()
            }
            // Auto-auth if key is stored
            if !license.storedKey.isEmpty {
                isAuthenticating = true
                license.authenticate(key: license.storedKey) { ok, err in
                    isAuthenticating = false
                    if ok {
                        log("✅ License valid")
                        syncConfig()
                        self.license.startHeartbeat()
                    } else {
                        log("❌ License: \(err ?? "failed")")
                    }
                }
            }
        }
        .onChange(of: config) { _ in
            syncConfig()
        }
    }

    // MARK: - Auth View
    var authView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // License Key Input (No Server URL on GUI)
                CardView(title: "LICENSE", icon: "key.fill") {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "key")
                                .foregroundColor(Color(white: 0.5))
                                .frame(width: 20)
                            TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKeyInput)
                                .font(.system(size: 15, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                        }
                        .padding(12)
                        .background(Color(white: 0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        if let err = license.authError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(err)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.red)
                            }
                        }

                        Button(action: {
                            let key = licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !key.isEmpty else { return }
                            isAuthenticating = true
                            log("⏳ Authenticating...")
                            license.authenticate(key: key) { ok, err in
                                isAuthenticating = false
                                if ok {
                                    log("✅ License activated!")
                                    log("✅ Expires: \(license.deviceExpires)")
                                    syncConfig()
                                    self.license.startHeartbeat()
                                } else {
                                    log("❌ Auth failed: \(err ?? "unknown")")
                                }
                            }
                        }) {
                            HStack {
                                if isAuthenticating {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black))
                                } else {
                                    Image(systemName: "checkmark.shield.fill")
                                        .foregroundColor(.black)
                                    Text("ACTIVATE")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.black)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(isAuthenticating || licenseKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                // Device Info
                CardView(title: "DEVICE", icon: "iphone") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("ID")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(white: 0.4))
                            Spacer()
                            Text(license.deviceId.prefix(20) + "...")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(white: 0.6))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Menu Tab
    var menuView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {

                // ── SILENT AIM ─────────────────────────────────────────
                CardView(title: "SILENT AIM", icon: "scope") {
                    VStack(spacing: 14) {
                        // Master toggle
                        ToggleRow(label: "Silent Aim", icon: "wind", on: $config.AimEnabled)

                        if config.AimEnabled {
                            Divider().background(Color(white: 0.2))

                            // FOV toggle
                            ToggleRow(label: "Show FOV Circle", icon: "circle.dashed", on: $config.EspFov)

                            // FOV Slider
                            SliderRow(label: "Silent FOV", value: $config.FovSize, range: 30...400, isPercent: false)

                            // Headshot Rate Slider
                            SliderRow(label: "Headshot Rate", value: $config.HeadshotRate, range: 0...100, isPercent: true)

                            // AimTarget picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Target Bone")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(white: 0.45))

                                HStack(spacing: 8) {
                                    ForEach(0..<3, id: \.self) { idx in
                                        let name = idx == 0 ? "Head" : (idx == 1 ? "Neck" : "Body")
                                        Button(action: { config.AimTarget = idx }) {
                                            Text(name)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(config.AimTarget == idx ? .black : Color(white: 0.7))
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 36)
                                                .background(config.AimTarget == idx ? Color.white : Color(white: 0.15))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── AIM SYSTEM ─────────────────────────────────────────
                CardView(title: "AIM SYSTEM", icon: "target") {
                    VStack(spacing: 14) {
                        ToggleRow(label: "Aim System", icon: "flame", on: $config.AimSystemEnabled)

                        if config.AimSystemEnabled {
                            Divider().background(Color(white: 0.2))

                            // AimTarget picker (shared with silent aim)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Target Bone")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(white: 0.45))

                                HStack(spacing: 8) {
                                    ForEach(0..<3, id: \.self) { idx in
                                        let name = idx == 0 ? "Head" : (idx == 1 ? "Neck" : "Body")
                                        Button(action: { config.AimTarget = idx }) {
                                            Text(name)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(config.AimTarget == idx ? .black : Color(white: 0.7))
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 36)
                                                .background(config.AimTarget == idx ? Color.white : Color(white: 0.15))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                }
                            }

                            ToggleRow(label: "No Recoil", icon: "minus.circle", on: $config.NoRecoil)
                        }
                    }
                }

                // ── VISUALS ────────────────────────────────────────────
                CardView(title: "VISUALS (ESP)", icon: "eye") {
                    VStack(spacing: 14) {
                        ToggleRow(label: "Enable ESP", icon: "eye.fill", on: $config.EspMaster)
                        Divider().background(Color(white: 0.2))
                        ToggleRow(label: "Show Box", icon: "person.crop.square", on: $config.EspBox)
                        Divider().background(Color(white: 0.2))
                        ToggleRow(label: "Show Line / Tracer", icon: "line.diagonal", on: $config.EspLine)
                        Divider().background(Color(white: 0.2))
                        ToggleRow(label: "Show Name", icon: "textformat", on: $config.EspName)
                        Divider().background(Color(white: 0.2))
                        ToggleRow(label: "Show Health", icon: "heart.fill", on: $config.EspHealth)
                        Divider().background(Color(white: 0.2))
                        ToggleRow(label: "Show Distance", icon: "ruler", on: $config.EspDistance)
                        Divider().background(Color(white: 0.2))
                        ToggleRow(label: "Show Skeleton", icon: "figure.walk", on: $config.EspSkeleton)
                    }
                }

                // ── INJECT / UNINSTALL ─────────────────────────────────
                if !hasInjected {
                    Button(action: { injectGame() }) {
                        HStack {
                            if isInjecting {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black))
                            } else {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.black)
                                Text("INJECT MOD")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isInjecting)
                } else {
                    Button(action: { uninstallMod() }) {
                        HStack {
                            Image(systemName: "trash.fill").foregroundColor(.white)
                            Text("UNINSTALL MOD")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Log Tab
    var logView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                if logs.isEmpty {
                    Text("No logs yet. Inject to start.")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color(white: 0.4))
                        .padding(.top, 20)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(Array(logs.reversed()), id: \.self) { line in
                        Text(line)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(line.hasPrefix("✅") ? .green : line.hasPrefix("❌") ? .red : Color(white: 0.7))
                            .padding(.horizontal, 4)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(white: 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    // MARK: - Logic
    private func log(_ msg: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logs.append("[\(ts)] \(msg)")
    }

    private func loadConfig() {
        do {
            let fm = FileManager.default
            let docsURL = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let configURL = docsURL.appendingPathComponent("localConfig.json")
            if fm.fileExists(atPath: configURL.path) {
                let data = try Data(contentsOf: configURL)
                config = try JSONDecoder().decode(EspConfig.self, from: data)
                log("✅ Loaded config from Documents")
            }
        } catch { log("❌ Load config failed: \(error)") }
    }

    private func saveConfigLocally() -> Data? {
        do {
            // Inject live API tokens & server active state into config before saving
            if !license.getMeomeo().isEmpty { config.meomeo = license.getMeomeo() }
            if !license.getSig().isEmpty { config.sig = license.getSig() }
            if !license.getToken().isEmpty { config.token = license.getToken() }
            if license.getTs() != 0 { config.ts = license.getTs() }
            config.system_active = license.systemActive
            config.server_esp = license.serverFeatures["server_esp"] ?? true
            config.server_aim = license.serverFeatures["server_aim"] ?? true
            config.server_box = license.serverFeatures["server_box"] ?? true
            config.server_line = license.serverFeatures["server_line"] ?? true
            config.server_skeleton = license.serverFeatures["server_skeleton"] ?? true
            config.server_name = license.serverFeatures["server_name"] ?? true
            config.server_distance = license.serverFeatures["server_distance"] ?? true
            config.server_health = license.serverFeatures["server_health"] ?? true
            config.server_headshot = license.serverFeatures["server_headshot"] ?? true

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            let fm = FileManager.default
            let docsURL = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            try data.write(to: docsURL.appendingPathComponent("localConfig.json"))
            return data
        } catch { return nil }
    }

    private func syncConfig() {
        guard let jsonData = saveConfigLocally() else { return }
        if let containerPath = ContainerStore.resolveAppContainerPath(bundleID: selectedBundleID) {
            let docsURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents")
            let configURL = docsURL.appendingPathComponent("localConfig.json")
            try? jsonData.write(to: configURL)
            log("✅ Config synced to game")
        }
    }

    private func uninstallMod() {
        guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: selectedBundleID) else {
            log("❌ Cannot find game container")
            hasInjected = false
            return
        }
        let docsURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents")
        let fm = FileManager.default
        let bytesURL = docsURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
        let configURL = docsURL.appendingPathComponent("localConfig.json")
        do {
            if fm.fileExists(atPath: bytesURL.path) { try fm.removeItem(at: bytesURL) }
            if fm.fileExists(atPath: configURL.path) { try fm.removeItem(at: configURL) }
            log("✅ Uninstalled mod")
            hasInjected = false
            license.stopHeartbeat()
        } catch {
            log("❌ Uninstall error: \(error)")
        }
    }

    private func injectGame() {
        // Anti-Tamper check before proceeding
        if SecurityShield.isDebuggerAttached {
            log("❌ Tamper detected: Debugger attached")
            return
        }

        // Verify license is still valid before injecting
        guard license.isAuthed else {
            log("❌ License not active — authenticate first")
            return
        }

        guard let jsonData = saveConfigLocally() else {
            log("❌ Error saving config")
            return
        }
        isInjecting = true
        log("⏳ Verifying license with server...")
        topTab = "Log"

        // Double-check with API before downloading
        license.checkStatus { ok in
            guard ok else {
                self.isInjecting = false
                self.log("❌ Server rejected: license inactive or expired")
                return
            }
            self.log("✅ License verified")
            self.log("⏳ Download...")

            let token = SecurityShield.githubToken
            let urlStr = SecurityShield.payloadDownloadURL
            guard let url = URL(string: urlStr) else {
                self.log("❌ Invalid URL"); self.isInjecting = false; return
            }
            var request = URLRequest(url: url)
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    self.isInjecting = false
                    if let error = error {
                        self.log("❌ Download error: \(error.localizedDescription)"); return
                    }
                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        self.log("❌ HTTP \(http.statusCode)"); return
                    }
                    guard let data = data else {
                        self.log("❌ No data received"); return
                    }
                    self.log("✅ Downloaded \(data.count) bytes")

                    guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: self.selectedBundleID) else {
                        self.log("❌ Game not found: \(self.selectedBundleID)"); return
                    }
                    let docsURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents")
                    let bytesURL = docsURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
                    let configURL = docsURL.appendingPathComponent("localConfig.json")
                    do {
                        let fm = FileManager.default
                        if !fm.fileExists(atPath: docsURL.path) {
                            try fm.createDirectory(at: docsURL, withIntermediateDirectories: true)
                        }
                        try data.write(to: bytesURL)
                        // Re-save config with fresh API tokens
                        if let freshConfig = self.saveConfigLocally() {
                            try freshConfig.write(to: configURL)
                        } else {
                            try jsonData.write(to: configURL)
                        }
                        let gameName = self.gameTab == "ff" ? "Free Fire" : "Free Fire MAX"
                        self.log("✅ Done Mod — launch \(gameName) now!")
                        self.hasInjected = true
                        self.topTab = "Menu"
                        // Start heartbeat to keep session alive
                        self.license.startHeartbeat()
                    } catch {
                        self.log("❌ Write error: \(error)")
                    }
                }
            }.resume()
        }
    }
}

// MARK: - Reusable Components
struct CardView<Content: View>: View {
    var title: String
    var icon: String
    var content: Content
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.icon = icon; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(Color(white: 0.6))
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color(white: 0.4))
                    .tracking(1.5)
            }
            content
        }
        .padding(16)
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct ToggleRow: View {
    var label: String
    var icon: String
    @Binding var on: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color(white: 0.5))
                .frame(width: 20)
            Text(label)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: $on).toggleStyle(SlimToggleStyle()).labelsHidden()
        }
    }
}

struct SliderRow: View {
    var label: String
    @Binding var value: Float
    var range: ClosedRange<Float>
    var isPercent: Bool
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color(white: 0.6))
                Spacer()
                Text(isPercent ? "\(Int(value))%" : "\(Int(value))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range, step: 1)
                .accentColor(.white)
        }
    }
}
