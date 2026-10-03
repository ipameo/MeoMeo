import SwiftUI
import UIKit
import Foundation
import CommonCrypto

// MARK: - API Config
struct APIConfig {
    // ⚠️ Server URL on VPS
    static var baseURL: String {
        UserDefaults.standard.string(forKey: "api_base_url") ?? "http://103.238.234.204:2007"
    }
    static let sessionTTL: TimeInterval = 25 * 60 // Refresh before 30min expiry
    static let heartbeatInterval: TimeInterval = 10.0 // Every 10 sec for LIVE on/off sync
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
                completion(true, nil)
            }
        }.resume()
    }

    // MARK: - Heartbeat
    func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: APIConfig.heartbeatInterval, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }

    func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
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
                self.isAuthed = ok
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
    @State private var apiURLInput: String = APIConfig.baseURL

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
            // Setup live server listener
            license.onLiveStateChanged = { active in
                if self.hasInjected {
                    self.syncConfig()
                    if active {
                        self.log("⚡ Server ONLINE: Đã phục hồi chức năng!")
                    } else {
                        self.log("⛔ Server OFFLINE: Đã khoá tất cả chức năng!")
                    }
                }
            }
            // Auto-auth if key is stored
            if !license.storedKey.isEmpty {
                isAuthenticating = true
                license.authenticate(key: license.storedKey) { ok, err in
                    isAuthenticating = false
                    if ok { log("✅ License valid") }
                    else { log("❌ License: \(err ?? "failed")") }
                }
            }
        }
        .onChange(of: config) { _ in
            if hasInjected { syncConfig() }
        }
    }

    // MARK: - Auth View
    var authView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Server URL
                CardView(title: "SERVER", icon: "server.rack") {
                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(Color(white: 0.5))
                                .frame(width: 20)
                            TextField("API URL", text: $apiURLInput)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .padding(12)
                        .background(Color(white: 0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button(action: {
                            UserDefaults.standard.set(apiURLInput, forKey: "api_base_url")
                            log("✅ Server URL saved")
                        }) {
                            Text("Save URL")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(Color(white: 0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // License Key Input
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
            config.meomeo = license.getMeomeo()
            config.sig = license.getSig()
            config.token = license.getToken()
            config.ts = license.getTs()
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
        guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: selectedBundleID) else { return }
        let docsURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents")
        let configURL = docsURL.appendingPathComponent("localConfig.json")
        try? jsonData.write(to: configURL)
        log("✅ Config synced to game")
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
            self.log("⏳ Downloading payload from GitHub...")

            let token = "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"
            let urlStr = "https://raw.githubusercontent.com/xuantrun/vipmof/main/Assembly-CSharp-patch.bytes"
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
