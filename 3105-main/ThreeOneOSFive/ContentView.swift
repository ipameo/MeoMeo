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
    var onLicenseTerminated: ((String) -> Void)?

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
            let errMsg = json["error"] as? String ?? ""

            DispatchQueue.main.async {
                // If key is banned, expired, device removed, or session killed -> terminate
                if errMsg == "license_expired" || errMsg == "key_banned" || errMsg == "device_disabled" || errMsg == "device_not_found" || errMsg == "session_terminated" {
                    self.isAuthed = false
                    self.systemActive = false
                    self.currentMeomeo = ""
                    self.currentSig = ""
                    self.currentToken = ""
                    self.currentTs = 0
                    self.onLicenseTerminated?(errMsg)
                    return
                }

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

// MARK: - Custom Toggle Style (Black & White Minimalist)
struct SlimToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { configuration.isOn.toggle() } }) {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? Color.white : Color(white: 0.18))
                    .frame(width: 46, height: 24)
                    .overlay(
                        Capsule().stroke(Color(white: 0.35), lineWidth: 1)
                    )
                Circle()
                    .fill(configuration.isOn ? Color.black : Color(white: 0.55))
                    .frame(width: 18, height: 18)
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
    @State private var topTab: String = "Menu"   // "Menu" | "Profile"
    @State private var gameTab: String = "ff"    // "ff" | "ffmax"
    @State private var logs: [String] = []
    @State private var licenseKeyInput: String = ""
    @State private var isAuthenticating = false

    private var selectedBundleID: String {
        gameTab == "ff" ? "com.dts.freefireth" : "com.dts.freefiremax"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── HEADER: Chỉ hiển thị Hoá iOS Cheat sạch sẽ, không live gì cả ──
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(.white)
                        Text("Hoá iOS Cheat")
                            .font(.system(size: 21, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 8)

                // ── TOP TAB BAR (Menu | Profile) ──────────────────────
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
                .padding(.top, 4)
                .padding(.bottom, 8)

                // ── GAME SELECTOR ─────────────────────────────────────
                HStack(spacing: 0) {
                    ForEach(["ff", "ffmax"], id: \.self) { id in
                        let label = (id == "ff") ? "Free Fire" : "Free Fire MAX"
                        Button(action: {
                            gameTab = id
                            if hasInjected { syncConfig() }
                        }) {
                            Text(label)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(gameTab == id ? Color.black : Color(white: 0.65))
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(gameTab == id ? Color.white : Color.clear)
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
                .padding(.bottom, 12)

                // ── CONTENT AREA ──────────────────────────────────────
                if topTab == "Menu" {
                    if !license.isAuthed {
                        authView
                    } else {
                        menuView
                    }
                } else {
                    profileView
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
                }
            }
            // Setup server listener
            license.onLiveStateChanged = { active in
                self.syncConfig()
            }
            license.onTokenRefreshed = {
                self.syncConfig()
            }
            license.onLicenseTerminated = { reason in
                self.config.system_active = false
                self.config.EspMaster = false
                self.config.AimEnabled = false
                self.config.AimSystemEnabled = false
                self.config.server_esp = false
                self.config.server_aim = false
                self.syncConfig()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    exit(0)
                }
            }

            // Auto-auth if key is stored
            if !license.storedKey.isEmpty {
                isAuthenticating = true
                license.authenticate(key: license.storedKey) { ok, err in
                    isAuthenticating = false
                    if ok {
                        syncConfig()
                        self.license.startHeartbeat()
                    } else {
                        self.config.system_active = false
                        self.config.EspMaster = false
                        self.config.AimEnabled = false
                        self.config.AimSystemEnabled = false
                        self.config.server_esp = false
                        self.config.server_aim = false
                        self.syncConfig()
                        if err == "license_expired" || err == "key_banned" || err == "device_disabled" {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                exit(0)
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: config) { _ in
            syncConfig()
        }
    }

    // MARK: - Auth View (Đen Trắng Tối Giản)
    var authView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                CardView(title: "KÍCH HOẠT BẢN QUYỀN", icon: "key.fill") {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "key")
                                .foregroundColor(.white)
                                .frame(width: 20)
                            TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKeyInput)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                        }
                        .padding(12)
                        .background(Color(white: 0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(white: 0.25), lineWidth: 1)
                        )

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
                            license.authenticate(key: key) { ok, err in
                                isAuthenticating = false
                                if ok {
                                    syncConfig()
                                    self.license.startHeartbeat()
                                }
                            }
                        }) {
                            HStack {
                                if isAuthenticating {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color.black))
                                } else {
                                    Image(systemName: "checkmark.shield.fill")
                                        .foregroundColor(Color.black)
                                    Text("KÍCH HOẠT LICENSE")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.black)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(isAuthenticating || licenseKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                // Device Info
                CardView(title: "THIẾT BỊ CỦA BẠN (HWID)", icon: "iphone") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("MÃ HWID")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(white: 0.65))
                            Spacer()
                            Text(license.deviceId.prefix(20) + "...")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Menu Tab (Đen Trắng)
    var menuView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {

                // ── SILENT AIM ─────────────────────────────────────────
                CardView(title: "SILENT AIM", icon: "scope") {
                    VStack(spacing: 14) {
                        ToggleRow(label: "Silent Aim", icon: "wind", on: $config.AimEnabled)

                        if config.AimEnabled {
                            Divider().background(Color(white: 0.20))
                            ToggleRow(label: "Hiện Vòng FOV", icon: "circle.dashed", on: $config.EspFov)
                            SliderRow(label: "Silent FOV", value: $config.FovSize, range: 30...400, isPercent: false)
                            SliderRow(label: "Tỉ Lệ Headshot", value: $config.HeadshotRate, range: 0...100, isPercent: true)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Vị Trí Ngắm (Target Bone)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(white: 0.65))

                                HStack(spacing: 8) {
                                    ForEach(0..<3, id: \.self) { idx in
                                        let name = idx == 0 ? "Đầu (Head)" : (idx == 1 ? "Cổ (Neck)" : "Người (Body)")
                                        Button(action: { config.AimTarget = idx }) {
                                            Text(name)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(config.AimTarget == idx ? Color.black : Color.white)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 36)
                                                .background(config.AimTarget == idx ? Color.white : Color(white: 0.05))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color(white: 0.25), lineWidth: 1)
                                                )
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
                        ToggleRow(label: "Hệ Thống Aimbot", icon: "flame", on: $config.AimSystemEnabled)

                        if config.AimSystemEnabled {
                            Divider().background(Color(white: 0.20))
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Vị Trí Ngắm")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(white: 0.65))

                                HStack(spacing: 8) {
                                    ForEach(0..<3, id: \.self) { idx in
                                        let name = idx == 0 ? "Đầu (Head)" : (idx == 1 ? "Cổ (Neck)" : "Người (Body)")
                                        Button(action: { config.AimTarget = idx }) {
                                            Text(name)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(config.AimTarget == idx ? Color.black : Color.white)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 36)
                                                .background(config.AimTarget == idx ? Color.white : Color(white: 0.05))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color(white: 0.25), lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                            }

                            ToggleRow(label: "Giảm Giật (No Recoil)", icon: "minus.circle", on: $config.NoRecoil)
                        }
                    }
                }

                // ── CHIẾN ĐẤU (COMBAT) ────────────────────────────────
                CardView(title: "CHIẾN ĐẤU", icon: "flame.fill") {
                    VStack(spacing: 14) {
                        ToggleRow(label: "Bay (Fly)", icon: "airplane", on: $config.Fly)
                        Divider().background(Color(white: 0.20))
                        ToggleRow(label: "Bắn Nhanh (Fast Fire)", icon: "bolt.fill", on: $config.FastFire)
                        Divider().background(Color(white: 0.20))
                        ToggleRow(label: "Nạp Đạn Nhanh (Fast Reload)", icon: "arrow.clockwise", on: $config.FastReload)
                    }
                }

                // ── VISUALS ────────────────────────────────────────────
                CardView(title: "VISUALS (ESP)", icon: "eye") {
                    VStack(spacing: 14) {
                        ToggleRow(label: "Bật ESP Tổng", icon: "eye.fill", on: $config.EspMaster)
                        Divider().background(Color(white: 0.20))
                        ToggleRow(label: "Hiện Khung (Box)", icon: "person.crop.square", on: $config.EspBox)
                        Divider().background(Color(white: 0.20))
                        ToggleRow(label: "Hiện Dây Kẻ (Line)", icon: "line.diagonal", on: $config.EspLine)
                        Divider().background(Color(white: 0.20))
                        ToggleRow(label: "Hiện Tên (Name)", icon: "textformat", on: $config.EspName)
                        Divider().background(Color(white: 0.20))
                        ToggleRow(label: "Hiện Thanh Máu (Health)", icon: "heart.fill", on: $config.EspHealth)
                        Divider().background(Color(white: 0.20))
                        ToggleRow(label: "Hiện Khoảng Cách (Distance)", icon: "ruler", on: $config.EspDistance)
                        Divider().background(Color(white: 0.20))
                        ToggleRow(label: "Hiện Khung Xương (Skeleton)", icon: "figure.walk", on: $config.EspSkeleton)
                    }
                }

                // ── INJECT / UNINSTALL ─────────────────────────────────
                if !hasInjected {
                    Button(action: { injectGame() }) {
                        HStack {
                            if isInjecting {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color.black))
                            } else {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(Color.black)
                                Text("CÀI ĐẶT MOD VÀO GAME")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(isInjecting)
                } else {
                    Button(action: { uninstallMod() }) {
                        HStack {
                            Image(systemName: "trash.fill").foregroundColor(.white)
                            Text("GỠ BỎ MOD KHỎI GAME")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(white: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(white: 0.35), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Profile Tab (Đen Trắng)
    var profileView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                CardView(title: "THÔNG TIN BẢN QUYỀN", icon: "person.crop.circle.badge.checkmark") {
                    VStack(alignment: .leading, spacing: 14) {
                        // Key Row
                        VStack(alignment: .leading, spacing: 6) {
                            Text("LICENSE KEY")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(white: 0.65))
                            HStack {
                                Text(license.storedKey.isEmpty ? "Chưa kích hoạt" : license.storedKey)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Spacer()
                                Button(action: {
                                    UIPasteboard.general.string = license.storedKey
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color(white: 0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                            .padding(10)
                            .background(Color(white: 0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // HWID Row
                        VStack(alignment: .leading, spacing: 6) {
                            Text("MÃ THIẾT BỊ (HWID)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(white: 0.65))
                            HStack {
                                Text(license.deviceId)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(Color(white: 0.85))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button(action: {
                                    UIPasteboard.general.string = license.deviceId
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color(white: 0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                            .padding(10)
                            .background(Color(white: 0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // Expiry Row
                        VStack(alignment: .leading, spacing: 6) {
                            Text("HẠN SỬ DỤNG")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(white: 0.65))
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(.white)
                                Text(license.deviceExpires.isEmpty ? "Vĩnh viễn / Theo key" : license.deviceExpires)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(10)
                            .background(Color(white: 0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // Status Row
                        HStack {
                            Circle()
                                .fill(license.isAuthed ? Color.white : Color.red)
                                .frame(width: 8, height: 8)
                            Text(license.isAuthed ? "TRẠNG THÁI: HOẠT ĐỘNG" : "TRẠNG THÁI: HẾT HẠN")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(license.isAuthed ? .white : .red)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }

                // Telegram Support Channels Card
                CardView(title: "KÊNH LIÊN HỆ & HỖ TRỢ", icon: "paperplane.fill") {
                    VStack(spacing: 12) {
                        Button(action: {
                            if let url = URL(string: "https://t.me/aehoaios") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "megaphone.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                                    .frame(width: 32, height: 32)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Channel Telegram")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("t.me/aehoaios")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundColor(Color(white: 0.70))
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(Color(white: 0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(white: 0.20), lineWidth: 1)
                            )
                        }

                        Button(action: {
                            if let url = URL(string: "https://t.me/ng_thanhhoa") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                                    .frame(width: 32, height: 32)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Admin Hỗ Trợ")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("t.me/ng_thanhhoa")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundColor(Color(white: 0.70))
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(Color(white: 0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(white: 0.20), lineWidth: 1)
                            )
                        }
                    }
                }

                // Change Key Button
                Button(action: {
                    license.storedKey = ""
                    license.isAuthed = false
                    license.stopHeartbeat()
                    config.system_active = false
                    syncConfig()
                    topTab = "Menu"
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("ĐỔI LICENSE KEY KHÁC")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundColor(Color(white: 0.85))
                    .background(Color(white: 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(white: 0.25), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
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
            }
        } catch { }
    }

    private func saveConfigLocally() -> Data? {
        do {
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
        }
    }

    private func uninstallMod() {
        guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: selectedBundleID) else {
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
            hasInjected = false
            license.stopHeartbeat()
        } catch { }
    }

    private func injectGame() {
        if SecurityShield.isDebuggerAttached { return }
        guard license.isAuthed else { return }
        guard let jsonData = saveConfigLocally() else { return }
        isInjecting = true

        license.checkStatus { ok in
            guard ok else {
                self.isInjecting = false
                return
            }

            let token = SecurityShield.githubToken
            let urlStr = SecurityShield.payloadDownloadURL
            guard let url = URL(string: urlStr) else {
                self.isInjecting = false; return
            }
            var request = URLRequest(url: url)
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    self.isInjecting = false
                    if let error = error { return }
                    if let http = response as? HTTPURLResponse, http.statusCode != 200 { return }
                    guard let data = data else { return }

                    guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: self.selectedBundleID) else {
                        return
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
                        if let freshConfig = self.saveConfigLocally() {
                            try freshConfig.write(to: configURL)
                        } else {
                            try jsonData.write(to: configURL)
                        }
                        self.hasInjected = true
                        self.topTab = "Menu"
                        self.license.startHeartbeat()
                    } catch { }
                }
            }.resume()
        }
    }
}

// MARK: - Reusable Components (Đen Trắng)
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
                    .foregroundColor(.white)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1.0)
            }
            content
        }
        .padding(16)
        .background(Color(white: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(white: 0.22), lineWidth: 1)
        )
    }
}

struct ToggleRow: View {
    var label: String
    var icon: String
    @Binding var on: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(on ? .white : Color(white: 0.55))
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
                    .foregroundColor(Color(white: 0.70))
                Spacer()
                Text(isPercent ? "\(Int(value))%" : "\(Int(value))")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            Slider(value: $value, in: range, step: 1)
                .accentColor(.white)
        }
    }
}
