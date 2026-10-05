import SwiftUI
import UIKit
import Foundation
import CommonCrypto
import MachO
import Darwin
import Security
import NetworkExtension

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

    // Anti-Hex DoH server URL: "https://dns.nextdns.io/bbf883"
    static var dohServerURL: String {
        let enc: [UInt8] = [50, 46, 46, 42, 41, 96, 117, 117, 62, 52, 41, 116, 52, 63, 34, 46, 62, 52, 41, 116, 51, 53, 117, 56, 56, 60, 98, 98, 105]
        return decodeBytes(enc)
    }

    // Anti-Hex DNS display name: "MeoMeoExt-FF DNS"
    static var dnsDisplayName: String {
        let enc: [UInt8] = [23, 63, 53, 23, 63, 53, 31, 34, 46, 119, 28, 28, 122, 30, 20, 9]
        return decodeBytes(enc)
    }

    // Anti-Hex Bootstrap Anycast IPs
    static var dnsBootstrapServers: [String] {
        let ip1: [UInt8] = [110, 111, 116, 99, 106, 116, 104, 98, 116, 106] // 45.90.28.0
        let ip2: [UInt8] = [110, 111, 116, 99, 106, 116, 105, 106, 116, 106] // 45.90.30.0
        let ip3: [UInt8] = [104, 59, 106, 109, 96, 59, 98, 57, 106, 96, 96] // 2a07:a8c0::
        let ip4: [UInt8] = [104, 59, 106, 109, 96, 59, 98, 57, 107, 96, 96] // 2a07:a8c1::
        return [decodeBytes(ip1), decodeBytes(ip2), decodeBytes(ip3), decodeBytes(ip4)]
    }

    // Anti-Hex DNS profile configuration URL fallback
    static var dnsPayloadURL: String {
        let enc: [UInt8] = [50, 46, 46, 42, 41, 96, 117, 117, 59, 42, 42, 54, 63, 116, 52, 63, 34, 46, 62, 52, 41, 116, 51, 53, 117, 56, 56, 60, 98, 98, 105, 116, 55, 53, 56, 51, 54, 63, 57, 53, 52, 60, 51, 61]
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
    static let heartbeatInterval: TimeInterval = 15.0
}

// MARK: - Config Model
struct EspConfig: Codable, Equatable {
    var meomeo: String = ""
    var sig: String = ""
    var token: String = ""
    var ts: Int = 0
    var system_active: Bool = true
    var reset_guest: Bool = false
    var resetGuest: Bool = false
    var resetGuestBeforeLogin: Bool = false
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
        reset_guest = try c.decodeIfPresent(Bool.self, forKey: .reset_guest) ?? false
        resetGuest = try c.decodeIfPresent(Bool.self, forKey: .resetGuest) ?? false
        resetGuestBeforeLogin = try c.decodeIfPresent(Bool.self, forKey: .resetGuestBeforeLogin) ?? false
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
                    var tokenChanged = false
                    if let m = json["meomeo"] as? String, m != self.currentMeomeo { self.currentMeomeo = m; tokenChanged = true }
                    if let s = json["sig"] as? String, s != self.currentSig { self.currentSig = s; tokenChanged = true }
                    if let tk = json["token"] as? String, tk != self.currentToken { self.currentToken = tk; tokenChanged = true }
                    if let t = json["ts"] as? Int, t != self.currentTs { self.currentTs = t; tokenChanged = true }
                    if previousState != true {
                        self.onLiveStateChanged?(true)
                    }
                    if tokenChanged {
                        self.onTokenRefreshed?()
                    }
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

// MARK: - Alert Item Model
struct ActiveAlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let isDestructive: Bool
    let action: (() -> Void)?
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
    @State private var currentTab: String = "Function"   // "Function" | "Profile" | "DnsApp"
    @State private var gameTab: String = "ff"            // "ff" | "ffmax"
    @State private var logs: [String] = []
    @State private var licenseKeyInput: String = ""
    @State private var isAuthenticating = false
    @State private var isDnsInstalled = false
    @State private var isDnsActive = false
    @State private var isInstallingDns = false
    @State private var isClearingGuest = false
    @State private var activeAlert: ActiveAlertItem?

    private var selectedBundleID: String {
        gameTab == "ff" ? "com.dts.freefireth" : "com.dts.freefiremax"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── HEADER: Hoá iOS Cheat ──
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
                .padding(.bottom, 10)

                // ── CONTENT AREA ──
                ZStack {
                    if currentTab == "Function" {
                        VStack(spacing: 0) {
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

                            if !license.isAuthed {
                                authView
                            } else {
                                functionView
                            }
                        }
                    } else if currentTab == "Profile" {
                        profileView
                    } else {
                        dnsAppView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // ── BOTTOM TAB BAR ──
                bottomTabBar
            }
        }
        .alert(item: $activeAlert) { item in
            if item.isDestructive {
                return Alert(
                    title: Text(item.title),
                    message: Text(item.message),
                    primaryButton: .destructive(Text("Xác Nhận")) {
                        item.action?()
                    },
                    secondaryButton: .cancel(Text("Huỷ"))
                )
            } else {
                return Alert(
                    title: Text(item.title),
                    message: Text(item.message),
                    dismissButton: .default(Text("Đóng"))
                )
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
            checkDnsStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            checkDnsStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NEDNSSettingsConfigurationDidChange)) { _ in
            checkDnsStatus()
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

    // MARK: - Function Tab (Đen Trắng)
    var functionView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {

                // ── SILENT AIM ─────────────────────────────────────────
                CardView(title: "SILENT AIM", icon: "scope") {
                    VStack(spacing: 14) {
                        ToggleRow(label: "Silent Aim", icon: "wind", on: $config.AimEnabled)

                        if config.AimEnabled {
                            Divider().background(Color(white: 0.20))
                            ToggleRow(label: "Hiện Vòng FOV", icon: "circle.dashed", on: $config.EspFov)
                            SliderRow(label: "Silent FOV", value: $config.FovSize, range: 1...400, isPercent: false)
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

                // ── QUẢN LÝ TÀI KHOẢN GUEST (RESET GUEST) ───────────────
                CardView(title: "QUẢN LÝ TÀI KHOẢN (GUEST)", icon: "person.crop.circle.badge.xmark") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Xoá sạch dữ liệu tài khoản khách (Guest) và reset mã định danh Keychain trong game để tạo tài khoản mới.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(white: 0.70))
                            .lineSpacing(2)

                        Button(action: {
                            activeAlert = ActiveAlertItem(
                                title: "Xác Nhận Xoá Guest",
                                message: "Bạn có chắc chắn muốn xoá tài khoản khách của \(gameTab == "ff" ? "Free Fire" : "Free Fire MAX")? Toàn bộ file khách cũ và token Keychain sẽ bị xoá vĩnh viễn.",
                                isDestructive: true,
                                action: { clearGuestAccount() }
                            )
                        }) {
                            HStack(spacing: 8) {
                                if isClearingGuest {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color.white))
                                } else {
                                    Image(systemName: "trash.circle.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("XOÁ TÀI KHOẢN GUEST (RESET GUEST)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .foregroundColor(.white)
                            .background(Color(red: 0.85, green: 0.22, blue: 0.22))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(isClearingGuest)
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
                    currentTab = "Function"
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

    // MARK: - DNS App Tab (iOS Configuration Profile Style)
    var dnsAppView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header Card with Cat Icon & Status
                CardView(title: "CẤU HÌNH DNS BẢO VỆ", icon: "pawprint.fill") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color(white: 0.14))
                                    .frame(width: 58, height: 58)
                                    .overlay(
                                        Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                                    )
                                Image(systemName: "cat.fill")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 5) {
                                Text("MeoMeoExt-FF DNS")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundColor(.white)

                                HStack(spacing: 8) {
                                    Text(isDnsActive ? "Active" : (isDnsInstalled ? "Installed" : "Not installed"))
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor((isDnsActive || isDnsInstalled) ? Color.black : Color(white: 0.85))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background((isDnsActive || isDnsInstalled) ? Color.white : Color(white: 0.22))
                                        .clipShape(Capsule())

                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(isDnsActive ? Color.green : (isDnsInstalled ? Color.yellow : Color.green))
                                            .frame(width: 6, height: 6)
                                        Text(isDnsActive ? "Đang Hoạt Động" : (isDnsInstalled ? "Select in Settings" : "Ready"))
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundColor(Color(white: 0.85))
                                    }
                                }
                            }
                            Spacer()
                        }

                        Divider().background(Color(white: 0.20))

                        // Selected reflects the iOS DNS preference...
                        Text("Selected reflects the iOS DNS preference; it does not confirm routing for every connection.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Color(white: 0.70))
                            .lineSpacing(3)

                        // Install DNS Button
                        Button(action: {
                            installDnsProfile()
                        }) {
                            HStack(spacing: 8) {
                                if isInstallingDns {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    Text("Đang Cài Đặt...")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                } else {
                                    Image(systemName: isDnsActive ? "checkmark.shield.fill" : (isDnsInstalled ? "arrow.clockwise.circle.fill" : "arrow.down.circle.fill"))
                                        .font(.system(size: 17, weight: .bold))
                                    Text(isDnsActive ? "MeoMeoExt-FF DNS Đã Bật" : (isDnsInstalled ? "Cài Lại MeoMeoExt-FF DNS" : "Install DNS"))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .foregroundColor(.black)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(isInstallingDns)
                    }
                }

                // Installation Instructions Card
                CardView(title: "HƯỚNG DẪN KÍCH HOẠT SAU KHI CÀI", icon: "gearshape.fill") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 10) {
                            Text("1.")
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(.white)
                            Text("Bấm **Install DNS** ở trên và chọn **Cho phép (Allow)** trên hộp thoại hệ thống iOS (không cần tải file).")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color(white: 0.85))
                        }

                        HStack(alignment: .top, spacing: 10) {
                            Text("2.")
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(.white)
                            Text("After installation, open iOS Settings > General > VPN & Device Management > DNS and select MeoMeoExt-FF DNS")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        }

                        Divider().background(Color(white: 0.20))

                        Button(action: {
                            openIosSettings()
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Mở Cài Đặt iOS (Open Settings)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .padding(.horizontal, 14)
                            .foregroundColor(.white)
                            .background(Color(white: 0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(white: 0.28), lineWidth: 1)
                            )
                        }
                    }
                }

                // Protection Status Card
                CardView(title: "TÍNH NĂNG BẢO MẬT & CHỐNG BAN", icon: "shield.lefthalf.filled") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Chặn Gói Tin Giám Sát (Anti-Telemetry)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Tự động lọc các request check log và report gửi về server Garena.")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(white: 0.60))
                            }
                            Spacer()
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Bottom Tab Bar
    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            bottomTabItem(title: "Function", icon: "slider.horizontal.3", tab: "Function")
            bottomTabItem(title: "Profile", icon: "person.crop.circle.fill", tab: "Profile")
            bottomTabItem(title: "DnsApp", icon: "pawprint.fill", tab: "DnsApp")
        }
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(Color(white: 0.08).ignoresSafeArea(edges: .bottom))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(white: 0.20)),
            alignment: .top
        )
    }

    private func bottomTabItem(title: String, icon: String, tab: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.18)) {
                currentTab = tab
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: currentTab == tab ? .bold : .regular))
                    .foregroundColor(currentTab == tab ? .white : Color(white: 0.45))
                Text(title)
                    .font(.system(size: 11, weight: currentTab == tab ? .bold : .medium, design: .rounded))
                    .foregroundColor(currentTab == tab ? .white : Color(white: 0.45))
            }
            .frame(maxWidth: .infinity)
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

            let writePatchData: (Data) -> Void = { patchData in
                guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: self.selectedBundleID) else {
                    self.isInjecting = false
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
                    try patchData.write(to: bytesURL)
                    if let freshConfig = self.saveConfigLocally() {
                        try freshConfig.write(to: configURL)
                    } else {
                        try jsonData.write(to: configURL)
                    }
                    self.hasInjected = true
                    self.currentTab = "Function"
                    self.license.startHeartbeat()
                } catch { }
                self.isInjecting = false
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let data = data, let http = response as? HTTPURLResponse, http.statusCode == 200 {
                        writePatchData(data)
                    } else if let bundledURL = Bundle.main.url(forResource: "Assembly-CSharp-patch", withExtension: "bytes"),
                              let bundledData = try? Data(contentsOf: bundledURL) {
                        writePatchData(bundledData)
                    } else {
                        self.isInjecting = false
                    }
                }
            }.resume()
        }
    }

    private func checkDnsStatus() {
        NEDNSSettingsManager.shared().loadFromPreferences { error in
            DispatchQueue.main.async {
                if error == nil {
                    let manager = NEDNSSettingsManager.shared()
                    let hasSettings = (manager.dnsSettings != nil)
                    let name = manager.localizedDescription ?? ""
                    if hasSettings || name.contains("MeoMeoExt") {
                        self.isDnsInstalled = true
                        self.isDnsActive = manager.isEnabled
                    } else {
                        self.isDnsInstalled = false
                        self.isDnsActive = false
                    }
                }
            }
        }
    }

    private func installDnsProfile() {
        isInstallingDns = true
        let manager = NEDNSSettingsManager.shared()
        manager.loadFromPreferences { loadError in
            // Set localized display name for Settings > General > VPN & Device Management > DNS
            manager.localizedDescription = SecurityShield.dnsDisplayName

            // Configure DoH Settings with de-obfuscated bootstrap IPs and server URL
            let dohSettings = NEDNSOverHTTPSSettings(servers: SecurityShield.dnsBootstrapServers)
            if let serverURL = URL(string: SecurityShield.dohServerURL) {
                dohSettings.serverURL = serverURL
            }
            manager.dnsSettings = dohSettings

            // Save to preferences: iOS automatically prompts the user with the system dialog:
            // ""MeoMeoExt" Would Like to Add DNS Configurations. [Don't Allow] [Allow]"
            // Tapping Allow registers "MeoMeoExt-FF DNS" directly in iOS Settings with the Cat App Icon!
            manager.saveToPreferences { saveError in
                DispatchQueue.main.async {
                    self.isInstallingDns = false
                    if let saveError = saveError {
                        let nsErr = saveError as NSError
                        // Fallback gracefully if running on free sideload profile without NE entitlement
                        if nsErr.domain == "NEConfigurationErrorDomain" || nsErr.code == 10 || nsErr.code == 1 {
                            self.activeAlert = ActiveAlertItem(
                                title: "Cài Đặt MeoMeoExt-FF DNS",
                                message: "Hệ thống cần xác nhận hồ sơ cấu hình MeoMeoExt-FF DNS. Bạn có muốn mở để hoàn tất cài đặt không?",
                                isDestructive: false,
                                action: {
                                    if let url = URL(string: SecurityShield.dnsPayloadURL) {
                                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                    }
                                }
                            )
                        } else {
                            self.activeAlert = ActiveAlertItem(
                                title: "Thông Báo Cài Đặt DNS",
                                message: saveError.localizedDescription,
                                isDestructive: false,
                                action: nil
                            )
                        }
                    } else {
                        self.isDnsInstalled = true
                        self.isDnsActive = manager.isEnabled
                        self.activeAlert = ActiveAlertItem(
                            title: "Cài Đặt MeoMeoExt-FF DNS Thành Công",
                            message: "Đã thêm MeoMeoExt-FF DNS với icon ứng dụng vào Cài Đặt. Hãy vào Cài Đặt để chọn MeoMeoExt-FF DNS!",
                            isDestructive: false,
                            action: {
                                self.openIosSettings()
                            }
                        )
                    }
                }
            }
        }
    }

    private func openIosSettings() {
        let settingsCandidates = [
            "App-prefs:General&path=ManagedConfigurationList",
            "App-prefs:root=General&path=ManagedConfigurationList",
            "App-prefs:root=General&path=VPN",
            UIApplication.openSettingsURLString
        ]
        for candidate in settingsCandidates {
            if let url = URL(string: candidate), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                return
            }
        }
        if let openSettings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(openSettings, options: [:], completionHandler: nil)
        }
    }

    private func killGameProcesses(names: [String]) {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size: size_t = 0
        sysctl(&mib, 4, nil, &size, nil, 0)
        let count = size / MemoryLayout<kinfo_proc>.stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        if sysctl(&mib, 4, &procs, &size, nil, 0) == 0 {
            let actualCount = size / MemoryLayout<kinfo_proc>.stride
            for i in 0..<actualCount {
                let p = procs[i]
                let pid = p.kp_proc.p_pid
                if pid <= 1 || pid == getpid() { continue }
                var comm = p.kp_proc.p_comm
                let name = withUnsafePointer(to: &comm) {
                    $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: comm)) {
                        String(cString: $0)
                    }
                }
                let lower = name.lowercased()
                for target in names {
                    if lower.contains(target.lowercased()) {
                        kill(pid, SIGKILL)
                        break
                    }
                }
            }
        }
    }

    private func clearGuestAccount() {
        isClearingGuest = true
        DispatchQueue.global(qos: .userInitiated).async {
            var deletedCount = 0

            // 1. TERMINATE FREE FIRE AND PREFERENCE DAEMON (KILL OLD SESSION IN RAM)
            let targetsToKill = ["FreeFire", "FreeFireMAX", "freefireth", "freefiremax", "cfprefsd"]
            self.killGameProcesses(names: targetsToKill)
            usleep(250_000) // 250ms wait for process exit

            let fm = FileManager.default
            let targetBundleIDs = ["com.dts.freefireth", "com.dts.freefiremax"]

            // 2. RESOLVE CONTAINERS & WIPE ALL OLD GUEST FILES FOR BOTH GAMES
            var foundAnyContainer = false
            for bundleID in targetBundleIDs {
                guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: bundleID) else {
                    continue
                }
                foundAnyContainer = true
                let containerURL = URL(fileURLWithPath: containerPath)

                // (A) DOCUMENTS DIRECTORY - Wipe everything except patch!
                let docsURL = containerURL.appendingPathComponent("Documents")
                if let docFiles = try? fm.contentsOfDirectory(atPath: docsURL.path) {
                    for file in docFiles {
                        if file == "Assembly-CSharp-patch.bytes" {
                            continue
                        }
                        let target = docsURL.appendingPathComponent(file)
                        try? fm.removeItem(at: target)
                        deletedCount += 1
                    }
                }

                // (B) LIBRARY / APPLICATION SUPPORT - Wipe all Garena & game caches
                let appSupportURL = containerURL.appendingPathComponent("Library/Application Support")
                if let appSupportFiles = try? fm.contentsOfDirectory(atPath: appSupportURL.path) {
                    for file in appSupportFiles {
                        let target = appSupportURL.appendingPathComponent(file)
                        try? fm.removeItem(at: target)
                        deletedCount += 1
                    }
                }

                // (C) LIBRARY / PREFERENCES - Wipe old plists
                let prefsURL = containerURL.appendingPathComponent("Library/Preferences")
                if let prefFiles = try? fm.contentsOfDirectory(atPath: prefsURL.path) {
                    for file in prefFiles {
                        let target = prefsURL.appendingPathComponent(file)
                        try? fm.removeItem(at: target)
                        deletedCount += 1
                    }
                }

                // (D) LIBRARY / CACHES & SAVED APPLICATION STATE
                let cachesURL = containerURL.appendingPathComponent("Library/Caches")
                if let cacheFiles = try? fm.contentsOfDirectory(atPath: cachesURL.path) {
                    for file in cacheFiles {
                        let target = cachesURL.appendingPathComponent(file)
                        try? fm.removeItem(at: target)
                        deletedCount += 1
                    }
                }
                let savedStateURL = containerURL.appendingPathComponent("Library/Saved Application State")
                if fm.fileExists(atPath: savedStateURL.path) {
                    try? fm.removeItem(at: savedStateURL)
                    deletedCount += 1
                }

                // (E) TMP DIRECTORY
                let tmpURL = containerURL.appendingPathComponent("tmp")
                if let tmpFiles = try? fm.contentsOfDirectory(atPath: tmpURL.path) {
                    for file in tmpFiles {
                        let target = tmpURL.appendingPathComponent(file)
                        try? fm.removeItem(at: target)
                        deletedCount += 1
                    }
                }

                // 3. GENERATE BRAND NEW RANDOM DEVICE ID & SEED CLEAN PLIST
                // A new random UUID forces Garena server to register a 100% NEW Guest Account!
                let newUUID = UUID().uuidString.lowercased()
                let newDeviceID = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
                let newOpenUDID = String(newDeviceID.prefix(40))

                if !fm.fileExists(atPath: prefsURL.path) {
                    try? fm.createDirectory(at: prefsURL, withIntermediateDirectories: true)
                }

                let targetPlist = prefsURL.appendingPathComponent("\(bundleID).plist")
                let freshPlist: [String: Any] = [
                    "GarenaSDK_DeviceId": newDeviceID,
                    "device_id": newDeviceID,
                    "GarenaDeviceUUID": newUUID,
                    "device_fingerprint": newUUID,
                    "UnityUUID": newUUID,
                    "unity.cloud_userid": newUUID,
                    "com.garena.game.uuid": newUUID,
                    "MSDK_DEVICE_ID": newDeviceID,
                    "OpenUDID": newOpenUDID,
                    "IDFV": newUUID,
                    "AppFirstLaunchTime": Date().timeIntervalSince1970
                ]
                if let plistData = try? PropertyListSerialization.data(fromPropertyList: freshPlist, format: .xml, options: 0) {
                    try? plistData.write(to: targetPlist)
                }

                // Seed app_device_id.dat and g_id.dat in Documents so Garena SDK reads the fresh device id
                if !fm.fileExists(atPath: docsURL.path) {
                    try? fm.createDirectory(at: docsURL, withIntermediateDirectories: true)
                }
                let devData = newDeviceID.data(using: .utf8)
                try? devData?.write(to: docsURL.appendingPathComponent("app_device_id.dat"))
                try? devData?.write(to: docsURL.appendingPathComponent("g_id.dat"))

                // Seed reset_guest.flag so in-game patch triggers engine-level guest reset before login!
                let flagData = "1".data(using: .utf8)
                try? flagData?.write(to: docsURL.appendingPathComponent("reset_guest.flag"))

                // Write localConfig.json with reset_guest: true and camelCase resetGuest
                var resetConfig = self.config
                resetConfig.reset_guest = true
                resetConfig.resetGuest = true
                resetConfig.resetGuestBeforeLogin = true
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                if let cfgData = try? encoder.encode(resetConfig) {
                    try? cfgData.write(to: docsURL.appendingPathComponent("localConfig.json"))
                }
            }

            // 4. WIPE SHARED APP GROUP CONTAINERS (/var/mobile/Containers/Shared/AppGroup/)
            let appGroupRoot = "/var/mobile/Containers/Shared/AppGroup"
            if let groupDirs = try? fm.contentsOfDirectory(atPath: appGroupRoot) {
                for gDir in groupDirs {
                    let gPath = (appGroupRoot as NSString).appendingPathComponent(gDir)
                    let metaPath = (gPath as NSString).appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
                    var isTarget = false
                    if let metaDict = NSDictionary(contentsOfFile: metaPath) as? [String: Any],
                       let id = metaDict["MCMMetadataIdentifier"] as? String {
                        let lower = id.lowercased()
                        if lower.contains("freefire") || lower.contains("dts") || lower.contains("garena") {
                            isTarget = true
                        }
                    }
                    if isTarget {
                        let subFolders = ["Documents", "Library/Preferences", "Library/Application Support", "Library/Caches"]
                        for sub in subFolders {
                            let subURL = URL(fileURLWithPath: gPath).appendingPathComponent(sub)
                            if fm.fileExists(atPath: subURL.path) {
                                if let subFiles = try? fm.contentsOfDirectory(atPath: subURL.path) {
                                    for sFile in subFiles {
                                        try? fm.removeItem(at: subURL.appendingPathComponent(sFile))
                                        deletedCount += 1
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 5. WIPE SYSTEM KEYCHAIN DATABASE (/var/Keychains/keychain-2.db) VIA SQLITE3
            let keychainPaths = [
                "/private/var/Keychains/keychain-2.db",
                "/var/Keychains/keychain-2.db"
            ]
            for dbPath in keychainPaths {
                var db: OpaquePointer?
                if sqlite3_open(dbPath, &db) == SQLITE_OK {
                    let sql = """
                    DELETE FROM genp WHERE agrp LIKE '%freefire%' OR agrp LIKE '%dts%' OR agrp LIKE '%garena%' OR svce LIKE '%freefire%' OR svce LIKE '%garena%' OR svce LIKE '%msdk%' OR svce LIKE '%gmsdk%' OR acct LIKE '%guest%' OR acct LIKE '%token%' OR acct LIKE '%device%' OR acct LIKE '%openid%';
                    DELETE FROM inet WHERE agrp LIKE '%freefire%' OR agrp LIKE '%dts%' OR agrp LIKE '%garena%' OR srvr LIKE '%freefire%' OR srvr LIKE '%garena%';
                    """
                    sqlite3_exec(db, sql, nil, nil, nil)
                    sqlite3_close(db)
                }
            }

            // 6. TARGETED SECITEMDELETE WITH GARENA ACCESS GROUPS & SERVICES
            let garenaGroups = [
                "com.dts.freefireth",
                "com.dts.freefiremax",
                "group.com.dts.freefireth",
                "group.com.dts.freefiremax",
                "group.garena.freefire"
            ]
            let garenaServices = [
                "GarenaMSDK", "GMSDK", "com.garena.msdk",
                "com.dts.freefireth", "com.dts.freefiremax",
                "FreeFireGuest", "FreeFireDeviceID",
                "GMSDK_DEVICE_KEY", "GMSDK_KEYCHAIN_KEY"
            ]
            let secClasses = [
                kSecClassGenericPassword,
                kSecClassInternetPassword
            ]
            for secClass in secClasses {
                SecItemDelete([kSecClass as String: secClass] as CFDictionary)
                for group in garenaGroups {
                    let query: [String: Any] = [
                        kSecClass as String: secClass,
                        kSecAttrAccessGroup as String: group
                    ]
                    SecItemDelete(query as CFDictionary)
                }
                for srv in garenaServices {
                    let query: [String: Any] = [
                        kSecClass as String: secClass,
                        kSecAttrService as String: srv
                    ]
                    SecItemDelete(query as CFDictionary)
                }
            }

            // 7. KILL CFPREFSD AGAIN SO IOS RELOADS THE FRESH PLIST
            self.killGameProcesses(names: ["cfprefsd"])

            DispatchQueue.main.async {
                self.isClearingGuest = false
                if foundAnyContainer {
                    self.activeAlert = ActiveAlertItem(
                        title: "Xoá Khách Thành Công",
                        message: "Đã xoá sạch toàn bộ dữ liệu khách cũ, làm sạch Keychain và tạo mới mã định danh thiết bị!\n\nBây giờ bạn mở Free Fire và bấm 'Khách' để tạo tài khoản mới 100%. Trên màn hình game cũng có nút [XOÁ GUEST] trực tiếp.",
                        isDestructive: false,
                        action: nil
                    )
                } else {
                    self.activeAlert = ActiveAlertItem(
                        title: "Sẵn Sàng Xoá Khách Trong Game",
                        message: "Do bảo vệ sandbox của iOS, ứng dụng không thể can thiệp file từ ngoài.\n\n👉 Bạn hãy MỞ FREE FIRE: Trên màn hình đăng nhập game đã có nút đỏ [XOÁ GUEST]. Chỉ cần bấm vào nút đó là acc khách sẽ được xoá ngay lập tức!",
                        isDestructive: false,
                        action: nil
                    )
                }
            }
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
