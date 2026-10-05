import SwiftUI
import UIKit
import Foundation
import CommonCrypto
import MachO
import Darwin
import Security
import NetworkExtension

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

// MARK: - License Manager (Powered by Encrypted MeoCore .a Static Library)
class LicenseManager: ObservableObject {
    static let shared = LicenseManager()
    private let core = MeoCore.shared()

    @Published var isAuthed: Bool = false
    @Published var authError: String? = nil
    @Published var deviceExpires: String = ""
    @Published var systemActive: Bool = true
    @Published var serverFeatures: [String: Bool] = [:]

    var onLiveStateChanged: ((Bool) -> Void)? {
        didSet {
            core.onLiveStateChanged = { [weak self] active in
                DispatchQueue.main.async {
                    self?.systemActive = active
                    self?.isAuthed = active
                    self?.onLiveStateChanged?(active)
                }
            }
        }
    }

    var onTokenRefreshed: (() -> Void)? {
        didSet {
            core.onTokenRefreshed = { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.systemActive = self.core.systemActive
                    self.isAuthed = self.core.isAuthed
                    self.deviceExpires = self.core.deviceExpires
                    self.serverFeatures = (self.core.serverFeatures as? [String: Bool]) ?? [:]
                    self.onTokenRefreshed?()
                }
            }
        }
    }

    var onLicenseTerminated: ((String) -> Void)? {
        didSet {
            core.onLicenseTerminated = { [weak self] reason in
                DispatchQueue.main.async {
                    self?.isAuthed = false
                    self?.systemActive = false
                    self?.onLicenseTerminated?(reason)
                }
            }
        }
    }

    var storedKey: String {
        get { core.storedKey }
        set { core.storedKey = newValue }
    }

    var deviceId: String {
        return core.deviceId
    }

    init() {
        self.isAuthed = core.isAuthed
        self.systemActive = core.systemActive
        self.deviceExpires = core.deviceExpires
        self.serverFeatures = (core.serverFeatures as? [String: Bool]) ?? [:]

        core.onLiveStateChanged = { [weak self] active in
            DispatchQueue.main.async {
                self?.systemActive = active
                self?.isAuthed = active
                self?.onLiveStateChanged?(active)
            }
        }

        core.onTokenRefreshed = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.systemActive = self.core.systemActive
                self.isAuthed = self.core.isAuthed
                self.deviceExpires = self.core.deviceExpires
                self.serverFeatures = (self.core.serverFeatures as? [String: Bool]) ?? [:]
                self.onTokenRefreshed?()
            }
        }

        core.onLicenseTerminated = { [weak self] reason in
            DispatchQueue.main.async {
                self?.isAuthed = false
                self?.systemActive = false
                self?.onLicenseTerminated?(reason)
            }
        }
    }

    func authenticate(key: String, completion: @escaping (Bool, String?) -> Void) {
        core.authenticate(withKey: key) { [weak self] ok, err in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isAuthed = self.core.isAuthed
                self.authError = err
                self.systemActive = self.core.systemActive
                self.deviceExpires = self.core.deviceExpires
                self.serverFeatures = (self.core.serverFeatures as? [String: Bool]) ?? [:]
                completion(ok, err)
            }
        }
    }

    func startHeartbeat() { core.startHeartbeat() }
    func stopHeartbeat() { core.stopHeartbeat() }

    func checkStatus(completion: @escaping (Bool) -> Void) {
        core.checkStatus { [weak self] ok in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isAuthed = self.core.isAuthed
                self.serverFeatures = (self.core.serverFeatures as? [String: Bool]) ?? [:]
                completion(ok)
            }
        }
    }

    func getMeomeo() -> String { core.getMeomeo() }
    func getSig() -> String { core.getSig() }
    func getToken() -> String { core.getToken() }
    func getTs() -> Int { core.getTs() }
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
    @State private var activeAlert: ActiveAlertItem?

    private var selectedBundleID: String {
        gameTab == "ff" ? "com.dts.freefireth" : "com.dts.freefiremax"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !license.isAuthed {
                // ── MÀN HÌNH NHẬP KEY TRƯỚC (HIDE TOÀN BỘ GUI CHO ĐẾN KHI KEY HỢP LỆ) ──
                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            Text("MeoMeo")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                        Text("VUI LÒNG NHẬP LICENSE KEY ĐỂ MỞ KHOÁ")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color(white: 0.60))
                            .tracking(1.2)
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 20)

                    authView
                }
            } else {
                // ── ĐÃ KÍCH HOẠT XONG: HIỆN TOÀN BỘ GUI VÀ CÁC TAB ──
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 2) {
                        HStack(spacing: 8) {
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(.white)
                            Text("MeoMeo")
                                .font(.system(size: 21, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                    // CONTENT AREA
                    ZStack {
                        if currentTab == "Function" {
                            VStack(spacing: 0) {
                                // GAME SELECTOR
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

                                functionView
                            }
                        } else if currentTab == "Profile" {
                            profileView
                        } else {
                            dnsAppView
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // BOTTOM TAB BAR
                    bottomTabBar
                }
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
            hasInjected = MeoCore.shared().isModInjected(forBundleID: selectedBundleID)
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
                    VStack(spacing: 14) {
                        HStack {
                            Image(systemName: "key")
                                .foregroundColor(.white)
                                .frame(width: 20)
                            TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKeyInput)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                            if let pasteStr = UIPasteboard.general.string, !pasteStr.isEmpty {
                                Button(action: {
                                    licenseKeyInput = pasteStr.trimmingCharacters(in: .whitespacesAndNewlines)
                                }) {
                                    Image(systemName: "doc.on.clipboard")
                                        .foregroundColor(Color(white: 0.70))
                                        .padding(4)
                                }
                            }
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

                // Device HWID Card
                CardView(title: "THIẾT BỊ CỦA BẠN (HWID)", icon: "iphone") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gửi mã HWID này cho Admin để được kích hoạt License Key:")
                            .font(.system(size: 11, weight: .medium))
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
                }

                // Telegram Support Card
                CardView(title: "KÊNH MUA KEY & HỖ TRỢ", icon: "paperplane.fill") {
                    Button(action: {
                        if let url = URL(string: "https://t.me/cheatmeo") {
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
                                Text("Channel Telegram (Nhận / Mua Key)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("t.me/cheatmeo")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
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
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Function Tab (Đen Trắng)
    var functionView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {

                // ── BẬT / TẮT DNS NHANH ─────────────────────────────────
                CardView(title: "DNS BẢO VỆ (MEOMEEXT-FF)", icon: "bolt.shield.fill") {
                    HStack(spacing: 12) {
                        Image(systemName: isDnsActive ? "shield.fill" : "shield.slash.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(isDnsActive ? .white : Color(white: 0.50))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isDnsActive ? "DNS: ĐANG BẬT" : "DNS: ĐANG TẮT")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(isDnsActive ? .white : Color(white: 0.65))
                            Text(isDnsActive ? "Bảo vệ DoH & Chặn Telemetry đang hoạt động" : "Gạt công tắc để BẬT ngay")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(white: 0.50))
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { self.isDnsActive },
                            set: { val in self.toggleDns(enabled: val) }
                        ))
                        .toggleStyle(SlimToggleStyle())
                        .labelsHidden()
                    }
                }

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
                            if let url = URL(string: "https://t.me/cheatmeo") {
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
                                    Text("t.me/cheatmeo")
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
                            if let url = URL(string: "https://t.me/truongdeptrai7") {
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
                                    Text("t.me/truongdeptrai7")
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
                // BẬT / TẮT DNS NHANH CARD
                CardView(title: "BẬT / TẮT DNS NHANH", icon: "bolt.shield.fill") {
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: isDnsActive ? "shield.fill" : "shield.slash.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(isDnsActive ? .white : Color(white: 0.50))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(isDnsActive ? "DNS: ĐANG BẬT" : "DNS: ĐANG TẮT")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundColor(isDnsActive ? .white : Color(white: 0.65))
                                Text(isDnsActive ? "Tự động chặn report / chống ban server Garena" : "Bấm nút hoặc gạt để BẬT ngay")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(white: 0.55))
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { self.isDnsActive },
                                set: { val in self.toggleDns(enabled: val) }
                            ))
                            .toggleStyle(SlimToggleStyle())
                            .labelsHidden()
                        }

                        // Quick 1-tap Action Buttons
                        HStack(spacing: 10) {
                            Button(action: {
                                toggleDns(enabled: true)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("BẬT DNS")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .foregroundColor(isDnsActive ? Color.black : Color.white)
                                .background(isDnsActive ? Color.white : Color(white: 0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(isDnsActive ? 0.8 : 0.2), lineWidth: 1)
                                )
                            }

                            Button(action: {
                                toggleDns(enabled: false)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("TẮT DNS")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .foregroundColor(!isDnsActive ? Color.black : Color(white: 0.85))
                                .background(!isDnsActive ? Color.white : Color(white: 0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(!isDnsActive ? 0.8 : 0.2), lineWidth: 1)
                                )
                            }
                        }
                    }
                }

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
                                    Text(isDnsActive ? "MeoMeoExt-FF DNS Đang Bật" : (isDnsInstalled ? "Cài Lại MeoMeoExt-FF DNS" : "Install DNS"))
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
        MeoCore.shared().uninstallModFromGame(withBundleID: selectedBundleID)
        hasInjected = false
        license.stopHeartbeat()
    }

    private func injectGame() {
        if MeoCore.isDebuggerAttached() { return }
        guard license.isAuthed else { return }
        guard let jsonData = saveConfigLocally() else { return }
        isInjecting = true

        MeoCore.shared().inject(toGameWithBundleID: selectedBundleID, configData: jsonData) { [self] success, error in
            DispatchQueue.main.async {
                self.isInjecting = false
                if success {
                    self.hasInjected = true
                    self.currentTab = "Function"
                }
            }
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

    func toggleDns(enabled: Bool) {
        let manager = NEDNSSettingsManager.shared()
        if enabled {
            installDnsProfile()
        } else {
            isInstallingDns = true
            manager.loadFromPreferences { _ in
                manager.removeFromPreferences { err in
                    DispatchQueue.main.async {
                        self.isInstallingDns = false
                        if err == nil {
                            self.isDnsActive = false
                            self.isDnsInstalled = false
                        }
                    }
                }
            }
        }
    }

    private func installDnsProfile() {
        isInstallingDns = true
        let manager = NEDNSSettingsManager.shared()
        manager.loadFromPreferences { loadError in
            manager.localizedDescription = MeoCore.dnsDisplayName()

            let dohSettings = NEDNSOverHTTPSSettings(servers: MeoCore.dnsBootstrapServers())
            if let serverURL = URL(string: MeoCore.dohServerURL()) {
                dohSettings.serverURL = serverURL
            }
            manager.dnsSettings = dohSettings

            manager.saveToPreferences { saveError in
                DispatchQueue.main.async {
                    self.isInstallingDns = false
                    if let saveError = saveError {
                        let nsErr = saveError as NSError
                        if nsErr.domain == "NEConfigurationErrorDomain" || nsErr.code == 10 || nsErr.code == 1 {
                            self.activeAlert = ActiveAlertItem(
                                title: "Cài Đặt MeoMeoExt-FF DNS",
                                message: "Hệ thống cần xác nhận hồ sơ cấu hình MeoMeoExt-FF DNS. Bạn có muốn mở để hoàn tất cài đặt không?",
                                isDestructive: false,
                                action: {
                                    if let url = URL(string: MeoCore.dnsPayloadURL()) {
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
