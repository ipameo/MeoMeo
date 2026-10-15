import SwiftUI
import UIKit
import Foundation
import CommonCrypto
import MachO
import Darwin
import Security

// MARK: - Hardware-Bound Keychain Store (Anti-HWID Spoofing)
struct KeychainStore {
    private static let serviceName = "com.meomeo.security.vault"
    private static let accountHWID = "device_fingerprint_v2"

    static func getOrCreateDeviceHWID() -> String {
        if let existing = load(key: accountHWID), !existing.isEmpty {
            return existing
        }
        var sysInfo = utsname()
        uname(&sysInfo)
        let machine = withUnsafePointer(to: &sysInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { ptr in String(cString: ptr) }
        }
        let vendorUUID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let rawFingerprint = "\(vendorUUID):\(machine):\(ProcessInfo.processInfo.processorCount):xtr_hw_salt_2026"
        
        guard let data = rawFingerprint.data(using: .utf8) else { return vendorUUID }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        let hex = hash.prefix(16).map { String(format: "%02x", $0) }.joined()
        let formatted = "MM-\(hex.prefix(4).uppercased())-\(hex.dropFirst(4).prefix(4).uppercased())-\(hex.dropFirst(8).prefix(4).uppercased())-\(hex.dropFirst(12).prefix(4).uppercased())"
        save(key: accountHWID, value: formatted)
        return formatted
    }

    private static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data,
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return nil
    }
}

// MARK: - Anti-Hex & Anti-Crack Cryptographic Security Core
struct SecurityShield {
    private static let keyA: UInt8 = 0x5A
    private static let keyB: UInt8 = 0xA7

    // Multi-round dynamic bit-rotation deobfuscator (Anti-Strings / Anti-HexFiend)
    static func decodeBytes(_ bytes: [UInt8]) -> String {
        var result = [UInt8]()
        for (i, b) in bytes.enumerated() {
            let rot = ((b >> 3) | (b << 5)) & 0xFF
            let dec = rot ^ keyA ^ UInt8((i * 11 + Int(keyB)) & 0xFF)
            result.append(dec)
        }
        return String(bytes: result, encoding: .utf8) ?? ""
    }

    // Anti-Hex endpoint resolution: "http://103.238.234.204:2007"
    static var apiBaseURL: String {
        let enc: [UInt8] = [172, 228, 156, 23, 157, 93, 228, 252, 172, 27, 11, 66, 18, 162, 169, 33, 241, 96, 200, 128, 79, 7, 207, 102, 46, 134, 69]
        return decodeBytes(enc)
    }

    // Anti-Hex GitHub Token: "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"
    static var githubToken: String {
        let enc: [UInt8] = [212, 4, 188, 110, 6, 126, 191, 246, 164, 16, 17, 248, 208, 161, 227, 138, 98, 218, 162, 170, 76, 212, 133, 68, 188, 206, 111, 127, 103, 159, 220, 63, 72, 145, 187, 192, 120, 65, 50, 98]
        return decodeBytes(enc)
    }

    // Anti-Hex binary payload URL resolution: "https://raw.githubusercontent.com/sonank077/meomeo/main/Assembly-CSharp-patch.bytes"
    static var payloadDownloadURL: String {
        let enc: [UInt8] = [172, 228, 156, 23, 215, 245, 228, 12, 190, 137, 193, 162, 176, 40, 123, 243, 195, 210, 18, 138, 229, 53, 5, 140, 220, 164, 215, 39, 175, 148, 70, 78, 129, 59, 161, 232, 56, 40, 235, 43, 169, 56, 192, 175, 229, 77, 164, 220, 68, 191, 197, 127, 198, 238, 110, 139, 160, 153, 96, 120, 96, 243, 59, 251, 128, 91, 163, 213, 69, 181, 28, 30, 172, 143, 223, 206, 206, 20, 201, 121, 201, 232, 32]
        return decodeBytes(enc)
    }

    // HMAC secret: "xtr_hmac_auth_shield_2026_xuantrun"
    static var hmacSecret: String {
        let enc: [UInt8] = [44, 228, 172, 110, 15, 79, 150, 110, 215, 137, 209, 112, 200, 153, 67, 243, 35, 234, 218, 50, 52, 55, 159, 102, 30, 253, 63, 255, 7, 150, 254, 166, 65, 49]
        return decodeBytes(enc)
    }

    // Anti-Crack: Verify HMAC-SHA256 signature from API server to stop Charles / Thor / HTTP Proxy spoofing
    static func verifyAuthSignature(deviceId: String, key: String, sessionToken: String, ts: Int, nonce: String, signature: String) -> Bool {
        guard !signature.isEmpty, !nonce.isEmpty else { return false }
        let secret = hmacSecret
        let message = "\(deviceId.trimmingCharacters(in: .whitespacesAndNewlines)):\(key.trimmingCharacters(in: .whitespacesAndNewlines)):\(sessionToken.trimmingCharacters(in: .whitespacesAndNewlines)):\(ts):\(nonce.trimmingCharacters(in: .whitespacesAndNewlines)):\(secret)"
        guard let keyData = secret.data(using: .utf8),
              let msgData = message.data(using: .utf8) else { return false }
        var mac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        keyData.withUnsafeBytes { kBytes in
            msgData.withUnsafeBytes { mBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), kBytes.baseAddress, keyData.count, mBytes.baseAddress, msgData.count, &mac)
            }
        }
        let computedHex = mac.map { String(format: "%02x", $0) }.joined()
        return computedHex.lowercased() == signature.lowercased()
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

    // Anti-Debug: Enforce PT_DENY_ATTACH to prevent IDA Pro, Hopper, LLDB from attaching
    static func enforceAntiDebug() {
        typealias PtraceType = @convention(c) (CInt, pid_t, CInt, CInt) -> CInt
        if let handle = dlopen(nil, RTLD_NOW) {
            if let sym = dlsym(handle, "ptrace") {
                let ptrace = unsafeBitCast(sym, to: PtraceType.self)
                _ = ptrace(31, 0, 0, 0) // PT_DENY_ATTACH = 31
            }
            dlclose(handle)
        }
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

    // Anti-Proxy: Direct secure session that completely bypasses Wi-Fi / system HTTP proxies (ProxyBin, Charles, Proxyman)
    static let secureSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.connectionProxyDictionary = [:] // DIRECT CONNECTION: Forces iOS networking stack to bypass all proxies!
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: config)
    }()

    // Anti-Proxy: Detect HTTP/HTTPS Proxy active in iOS system (ProxyBin, Charles, Reqable)
    static var isProxyActive: Bool {
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            return false
        }
        if let httpEnable = proxySettings["HTTPEnable"] as? NSNumber, httpEnable.boolValue {
            return true
        }
        if let httpsEnable = proxySettings["HTTPSEnable"] as? NSNumber, httpsEnable.boolValue {
            return true
        }
        if let httpProxy = proxySettings["HTTPProxy"] as? String, !httpProxy.isEmpty {
            return true
        }
        if let httpsProxy = proxySettings["HTTPSProxy"] as? String, !httpsProxy.isEmpty {
            return true
        }
        if let host = proxySettings[kCFProxyHostNameKey as String] as? String, !host.isEmpty {
            return true
        }
        return false
    }

    // Anti-VPN: Detect VPN tunnel interfaces used by packet sniffing tools (Thor, Shadowrocket, ProxyBin)
    static var isVPNActive: Bool {
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
              let scoped = proxySettings["__SCOPED__"] as? [String: Any] else {
            return false
        }
        for key in scoped.keys {
            let lower = key.lowercased()
            if lower.contains("tap") || lower.contains("tun") || lower.contains("ppp") || lower.contains("ipsec") {
                return true
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

// MARK: - Remote GUI & Feature Visibility Model
struct GuiConfig: Codable, Equatable {
    var gui_enabled: Bool = true
    var tab_menu: Bool = true
    var tab_profile: Bool = true
    var card_silent_aim: Bool = true
    var card_aim_system: Bool = true
    var card_esp: Bool = true
    var card_other: Bool = true
    var card_antiban: Bool = true
    var card_guest: Bool = true
    var notice_text: String = ""
    var notice_active: Bool = false

    init() {}

    init(from dict: [String: Any]) {
        if let val = dict["gui_enabled"] as? Bool { self.gui_enabled = val }
        if let val = dict["tab_menu"] as? Bool { self.tab_menu = val }
        if let val = dict["tab_profile"] as? Bool { self.tab_profile = val }
        if let val = dict["card_silent_aim"] as? Bool { self.card_silent_aim = val }
        if let val = dict["card_aim_system"] as? Bool { self.card_aim_system = val }
        if let val = dict["card_esp"] as? Bool { self.card_esp = val }
        if let val = dict["card_other"] as? Bool { self.card_other = val }
        if let val = dict["card_antiban"] as? Bool { self.card_antiban = val }
        if let val = dict["card_guest"] as? Bool { self.card_guest = val }
        if let val = dict["notice_text"] as? String { self.notice_text = val }
        if let val = dict["notice_active"] as? Bool { self.notice_active = val }
    }
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
    var reset_guest: Bool = false
    var resetGuest: Bool = false
    var resetGuestBeforeLogin: Bool = false
    var BuffDame: Bool = false
    var SpeedHack: Int = 1
    var AimTarget: Int = 0             // 0=Head, 1=Neck, 2=Body
    var FovSize: Float = 60.0
    var HeadshotRate: Float = 60.0
    var ShowGuestBtn: Bool = true
    var CamXa: Bool = false
    var FastParachute: Bool = false
    var CamXaFloat: Float = 1.5
    var GhostMode: Bool = false
    var AntiBan: Bool = true

    enum CodingKeys: String, CodingKey {
        case meomeo
        case sig
        case token
        case ts
        case testCodePatch
        case system_active = "s0"
        case server_esp = "s1"
        case server_aim = "s2"
        case server_box = "s3"
        case server_line = "s4"
        case server_skeleton = "s5"
        case server_name = "s6"
        case server_distance = "s7"
        case server_health = "s8"
        case server_headshot = "s9"
        
        case EspMaster = "u1"
        case EspBox = "u2"
        case EspLine = "u3"
        case EspName = "u4"
        case EspHealth = "u5"
        case EspDistance = "u6"
        case EspTracer = "u7"
        case EspSkeleton = "u8"
        case AimEnabled = "u9"
        case AimSystemEnabled = "u10"
        case EspFov = "u11"
        case NoRecoil = "u12"
        case reset_guest = "u13"
        case resetGuest = "u14"
        case resetGuestBeforeLogin = "u15"
        case BuffDame = "u16"
        case SpeedHack = "u17"
        case AimTarget = "u18"
        case FovSize = "u19"
        case HeadshotRate = "u20"
        case ShowGuestBtn = "u21"
        case CamXa = "u22"
        case FastParachute = "u23"
        case CamXaFloat = "u24"
        case GhostMode = "u25"
        case AntiBan = "u26"
    }

    var userTogglesMask: UInt32 {
        var mask: UInt32 = 0
        if EspMaster { mask |= (UInt32(1) << 0) }
        if EspBox { mask |= (UInt32(1) << 1) }
        if EspLine || EspTracer { mask |= (UInt32(1) << 2) }
        if EspName { mask |= (UInt32(1) << 3) }
        if EspHealth { mask |= (UInt32(1) << 4) }
        if EspDistance { mask |= (UInt32(1) << 5) }
        if EspSkeleton { mask |= (UInt32(1) << 6) }
        if AimEnabled { mask |= (UInt32(1) << 7) }
        if AimSystemEnabled { mask |= (UInt32(1) << 8) }
        if EspFov { mask |= (UInt32(1) << 9) }
        if NoRecoil { mask |= (UInt32(1) << 10) }
        if ShowGuestBtn { mask |= (UInt32(1) << 11) }
        if reset_guest || resetGuest || resetGuestBeforeLogin { mask |= (UInt32(1) << 12) }
        if CamXa { mask |= (UInt32(1) << 13) }
        if FastParachute { mask |= (UInt32(1) << 14) }
        if GhostMode { mask |= (UInt32(1) << 15) }
        if BuffDame { mask |= (UInt32(1) << 16) }
        if AntiBan { mask |= (UInt32(1) << 26) }
        
        mask |= (UInt32(AimTarget & 0x3) << 17)
        mask |= (UInt32(SpeedHack & 0x7) << 19)
        
        var scaledFov = Int(FovSize / 5.0)
        if scaledFov > 31 { scaledFov = 31 }
        if scaledFov < 1 { scaledFov = 1 }
        mask |= (UInt32(scaledFov & 0x1F) << 22)
        
        var hr = Int(HeadshotRate / 10.0)
        if hr > 10 { hr = 10 }
        if hr < 0 { hr = 0 }
        mask |= (UInt32(hr & 0xF) << 27)
        
        if CamXaFloat >= 2.0 { mask |= (UInt32(1) << 31) }
        
        return mask
    }

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
        if let b = try? c.decodeIfPresent(Bool.self, forKey: .testCodePatch) {
            testCodePatch = b
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .testCodePatch) {
            testCodePatch = (s.lowercased() == "true")
        } else {
            testCodePatch = true
        }
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
        reset_guest = try c.decodeIfPresent(Bool.self, forKey: .reset_guest) ?? false
        resetGuest = try c.decodeIfPresent(Bool.self, forKey: .resetGuest) ?? false
        resetGuestBeforeLogin = try c.decodeIfPresent(Bool.self, forKey: .resetGuestBeforeLogin) ?? false
        BuffDame = try c.decodeIfPresent(Bool.self, forKey: .BuffDame) ?? false
        SpeedHack = try c.decodeIfPresent(Int.self, forKey: .SpeedHack) ?? 1
        AimTarget = try c.decodeIfPresent(Int.self, forKey: .AimTarget) ?? 0
        FovSize = try c.decodeIfPresent(Float.self, forKey: .FovSize) ?? 60.0
        HeadshotRate = try c.decodeIfPresent(Float.self, forKey: .HeadshotRate) ?? 60.0
        ShowGuestBtn = try c.decodeIfPresent(Bool.self, forKey: .ShowGuestBtn) ?? true
        CamXa = try c.decodeIfPresent(Bool.self, forKey: .CamXa) ?? false
        FastParachute = try c.decodeIfPresent(Bool.self, forKey: .FastParachute) ?? false
        CamXaFloat = try c.decodeIfPresent(Float.self, forKey: .CamXaFloat) ?? 1.5
        GhostMode = try c.decodeIfPresent(Bool.self, forKey: .GhostMode) ?? false
        AntiBan = try c.decodeIfPresent(Bool.self, forKey: .AntiBan) ?? true
    }
}

// MARK: - License Manager (Anti-Crack Auth Shield & Remote GUI)
class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published var isAuthed = false
    @Published var authError: String? = nil
    @Published var deviceExpires: String = ""
    @Published var systemActive: Bool = true
    @Published var serverFeatures: [String: Bool] = [:]
    @Published var guiConfig = GuiConfig()

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

    // Hardware-Bound Device HWID stored in Secure Keychain (Anti-Filza / Anti-Plist spoofing)
    var deviceId: String {
        return KeychainStore.getOrCreateDeviceHWID()
    }

    // MARK: - Remote GUI Sync
    func fetchGuiConfig(completion: ((GuiConfig) -> Void)? = nil) {
        guard let url = URL(string: "\(APIConfig.baseURL)/api/gui_config") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        SecurityShield.secureSession.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let gCfg = json["gui_config"] as? [String: Any] else { return }
            DispatchQueue.main.async {
                self.guiConfig = GuiConfig(from: gCfg)
                completion?(self.guiConfig)
            }
        }.resume()
    }

    // MARK: - Auth (HMAC-SHA256 Cryptographic Signature Verification)
    func authenticate(key: String, completion: @escaping (Bool, String?) -> Void) {
        // Anti-Sniffer: Check for active ProxyBin, Charles, or VPN MITM tunnels
        if SecurityShield.isProxyActive || SecurityShield.isVPNActive {
            self.authError = "CẢNH BÁO: Phát hiện phần mềm Proxy / Bắt gói tin (ProxyBin/VPN)! Vui lòng tắt Proxy để mở menu."
            self.isAuthed = false
            completion(false, self.authError)
            return
        }

        let devId = self.deviceId
        let url = URL(string: "\(APIConfig.baseURL)/api/auth")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["device_id": devId, "key": key]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        SecurityShield.secureSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.authError = error.localizedDescription
                    completion(false, self.authError)
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.authError = "Phản hồi máy chủ không hợp lệ"
                    completion(false, self.authError)
                    return
                }

                if let errMsg = json["error"] as? String {
                    self.authError = errMsg
                    self.isAuthed = false
                    completion(false, errMsg)
                    return
                }

                let sessionTok = json["session_token"] as? String ?? ""
                let nonce = json["nonce"] as? String ?? ""
                let authSign = json["auth_sign"] as? String ?? ""
                let ts = json["ts"] as? Int ?? 0

                // Anti-Crack: Verify HMAC-SHA256 signature to block Thor / Charles / HTTP Mock bypass
                let isSignatureValid = SecurityShield.verifyAuthSignature(
                    deviceId: devId,
                    key: key,
                    sessionToken: sessionTok,
                    ts: ts,
                    nonce: nonce,
                    signature: authSign
                )

                if !isSignatureValid {
                    self.authError = "CẢNH BÁO: Phát hiện can thiệp auth hoặc proxy giả mạo!"
                    self.isAuthed = false
                    completion(false, self.authError)
                    return
                }

                self.sessionToken = sessionTok
                self.currentMeomeo = json["meomeo"] as? String ?? ""
                self.currentSig = json["sig"] as? String ?? ""
                self.currentToken = json["token"] as? String ?? ""
                self.currentTs = ts
                self.deviceExpires = json["device_expires"] as? String ?? ""
                self.systemActive = json["system_active"] as? Bool ?? true
                self.serverFeatures = json["features"] as? [String: Bool] ?? [:]
                if let gCfg = json["gui_config"] as? [String: Any] {
                    self.guiConfig = GuiConfig(from: gCfg)
                }
                self.storedKey = key
                self.isAuthed = true
                self.authError = nil
                self.onTokenRefreshed?()
                completion(true, nil)
            }
        }.resume()
    }

    func updateUserToggles(mask: UInt32, completion: @escaping (Bool) -> Void) {
        guard !sessionToken.isEmpty else {
            completion(false)
            return
        }
        let url = URL(string: "\(APIConfig.baseURL)/api/set_user_toggles")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "device_id": deviceId,
            "session_token": sessionToken,
            "user_toggles": mask
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 10

        SecurityShield.secureSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let ok = json["ok"] as? Bool, ok,
                      let newToken = json["token"] as? String else {
                    completion(false)
                    return
                }
                self.currentToken = newToken
                completion(true)
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
        if SecurityShield.isProxyActive || SecurityShield.isVPNActive {
            DispatchQueue.main.async {
                self.isAuthed = false
                self.systemActive = false
                self.currentMeomeo = ""
                self.currentSig = ""
                self.currentToken = ""
                self.currentTs = 0
                self.onLiveStateChanged?(false)
            }
            return
        }

        let url = URL(string: "\(APIConfig.baseURL)/api/heartbeat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["device_id": deviceId, "session_token": sessionToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 8

        SecurityShield.secureSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            guard error == nil, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                // API SERVER IS OFFLINE OR UNREACHABLE -> IMMEDIATELY LOCK GAME
                DispatchQueue.main.async {
                    self.systemActive = false
                    self.isAuthed = false
                    self.currentMeomeo = ""
                    self.currentSig = ""
                    self.currentToken = ""
                    self.currentTs = 0
                    self.onLiveStateChanged?(false)
                }
                return
            }
            
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
                if let gCfg = json["gui_config"] as? [String: Any] {
                    self.guiConfig = GuiConfig(from: gCfg)
                }

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

    // Cryptographic Proof of Auth: Verifies session token and server tokens are non-empty and non-expired (Anti-Bypass Guard)
    var isCryptographicallyVerified: Bool {
        guard isAuthed else { return false }
        guard !sessionToken.isEmpty, !currentToken.isEmpty, !currentSig.isEmpty, !currentMeomeo.isEmpty else {
            return false
        }
        let now = Int(Date().timeIntervalSince1970)
        if currentTs != 0 && currentTs < now {
            return false
        }
        return true
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

        SecurityShield.secureSession.dataTask(with: request) { data, _, _ in
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
                if let gCfg = json["gui_config"] as? [String: Any] {
                    self.guiConfig = GuiConfig(from: gCfg)
                }
                self.isAuthed = ok
                self.onTokenRefreshed?()
                completion(ok)
            }
        }.resume()
    }
}

// MARK: - Swiss International Design System
struct SwissDesign {
    static let bg = Color(red: 245/255, green: 245/255, blue: 245/255) // #F5F5F5 Off-white
    static let surface = Color.white // Clean white
    static let white = Color.white // Pure white
    static let black = Color.black // Pure Helvetica black
    static let red = Color(red: 224/255, green: 6/255, blue: 19/255) // International Red (#E00613)
    static let line = Color(white: 0.86) // 1px hairline divider
    static let lineDark = Color.black // 1.5px structural line
    static let textSecondary = Color(white: 0.42) // Swiss neutral gray
    static let textMuted = Color(white: 0.65)
}

// MARK: - Clean Table Row Without Borders
struct LapRowView: View {
    let lap: String
    let split: String
    let diff: String
    let subsys: String
    let state: String
    let isAccent: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text(lap)
                .font(.system(size: 11, weight: isAccent ? .black : .bold, design: .monospaced))
                .foregroundColor(isAccent ? SwissDesign.red : SwissDesign.black)
                .frame(width: 36, alignment: .leading)
            Text(split)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(isAccent ? SwissDesign.red : SwissDesign.black)
                .frame(width: 78, alignment: .leading)
            Text(diff)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(SwissDesign.textSecondary)
                .frame(width: 58, alignment: .leading)
            Text(subsys)
                .font(.system(size: 10, weight: .bold, design: .default))
                .foregroundColor(SwissDesign.black)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(state)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundColor(isAccent ? SwissDesign.white : SwissDesign.black)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(isAccent ? SwissDesign.red : Color(white: 0.90))
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Swiss Section
struct SwissSection<Content: View>: View {
    let number: String
    let title: String
    let content: Content

    init(number: String, title: String, @ViewBuilder content: () -> Content) {
        self.number = number
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(SwissDesign.black)
                .frame(height: 1.5)
            
            HStack(spacing: 8) {
                Text(number)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(SwissDesign.red)
                Text(title)
                    .font(.system(size: 12, weight: .black, design: .default))
                    .tracking(1.2)
                    .foregroundColor(SwissDesign.black)
                Spacer()
            }
            .padding(.top, 10)
            .padding(.bottom, 10)

            content

            Rectangle()
                .fill(SwissDesign.line)
                .frame(height: 1)
                .padding(.top, 12)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }
}

// MARK: - Swiss Toggle Row (Minimalist Geometric Square)
struct SwissToggleRow: View {
    let label: String
    let code: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: {
            isOn.toggle()
        }) {
            HStack(spacing: 12) {
                Text(code)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(SwissDesign.textSecondary)
                    .frame(width: 24, alignment: .leading)
                
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .default))
                    .foregroundColor(SwissDesign.black)
                
                Spacer()

                // Sharp geometric square checkbox
                ZStack {
                    Rectangle()
                        .stroke(SwissDesign.black, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                        .background(SwissDesign.surface)
                    if isOn {
                        Rectangle()
                            .fill(SwissDesign.red)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Swiss Slider Row
struct SwissSliderRow: View {
    let label: String
    let code: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let isPercent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(code)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(SwissDesign.textSecondary)
                    .frame(width: 24, alignment: .leading)
                
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .foregroundColor(SwissDesign.black)
                
                Spacer()
                
                Text(isPercent ? "\(Int(value))%" : "\(Int(value))")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(SwissDesign.red)
            }

            Slider(value: $value, in: range, step: 1)
                .accentColor(SwissDesign.black)
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Main View (Swiss International Style)
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

    // Chrono & Precision Stopwatch State
    @State private var elapsedTimeString: String = "00:45.32"
    @State private var stopwatchActive: Bool = false
    @State private var startTimestamp: Date? = nil
    @State private var accumulatedTime: TimeInterval = 45.32
    @State private var timerSubscription: Timer? = nil

    private var selectedBundleID: String {
        gameTab == "ff" ? "com.dts.freefireth" : "com.dts.freefiremax"
    }

    private var availableTabs: [String] {
        var tabs: [String] = []
        if license.guiConfig.tab_menu { tabs.append("Menu") }
        if license.guiConfig.tab_profile { tabs.append("Profile") }
        return tabs
    }

    var body: some View {
        ZStack {
            // Swiss Off-white Background (#F5F5F5)
            SwissDesign.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── HEADER: Swiss Precision Grid ──
                VStack(spacing: 0) {
                    HStack(alignment: .lastTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SWISS INTERNATIONAL // MOD")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .tracking(1.8)
                                .foregroundColor(SwissDesign.red)
                            Text("3105.MEOMEO")
                                .font(.system(size: 22, weight: .black, design: .default))
                                .tracking(-0.5)
                                .foregroundColor(SwissDesign.black)
                        }
                        Spacer()
                        // Game Selector as rigid geometric toggle
                        HStack(spacing: 0) {
                            Button(action: {
                                gameTab = "ff"
                                if hasInjected { syncConfig() }
                            }) {
                                Text("FF")
                                    .font(.system(size: 11, weight: .black, design: .default))
                                    .foregroundColor(gameTab == "ff" ? SwissDesign.white : SwissDesign.black)
                                    .frame(width: 44, height: 28)
                                    .background(gameTab == "ff" ? SwissDesign.black : Color.clear)
                            }
                            Rectangle().fill(SwissDesign.black).frame(width: 1, height: 28)
                            Button(action: {
                                gameTab = "ffmax"
                                if hasInjected { syncConfig() }
                            }) {
                                Text("MAX")
                                    .font(.system(size: 11, weight: .black, design: .default))
                                    .foregroundColor(gameTab == "ffmax" ? SwissDesign.white : SwissDesign.black)
                                    .frame(width: 44, height: 28)
                                    .background(gameTab == "ffmax" ? SwissDesign.black : Color.clear)
                            }
                        }
                        .overlay(Rectangle().stroke(SwissDesign.black, lineWidth: 1.5))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    
                    Rectangle()
                        .fill(SwissDesign.black)
                        .frame(height: 1.5)
                }

                // ── REMOTE NOTICE BANNER ──
                if license.guiConfig.notice_active && !license.guiConfig.notice_text.isEmpty {
                    noticeBannerView
                }

                // ── CHRONO HERO: STOPWATCH & TIMER ──
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("CHRONOMETER // 01")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.6)
                            .foregroundColor(SwissDesign.textSecondary)
                        Spacer()
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(stopwatchActive ? SwissDesign.red : SwissDesign.black)
                                .frame(width: 8, height: 8)
                            Text(stopwatchActive ? "RUNNING" : "STOPPED")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(SwissDesign.black)
                        }
                    }
                    
                    // Elapsed time dominates the screen in bold black text
                    Text(elapsedTimeString)
                        .font(.system(size: 54, weight: .black, design: .default))
                        .tracking(-1.5)
                        .foregroundColor(SwissDesign.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Structural line
                    Rectangle()
                        .fill(SwissDesign.black)
                        .frame(height: 1.5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                // ── 'START' & 'STOP' CONTROLS: SIMPLE RED AND BLACK GEOMETRIC SQUARES ──
                HStack(spacing: 12) {
                    // START square (Black geometric square)
                    Button(action: {
                        startStopwatch()
                        injectGame()
                    }) {
                        VStack(spacing: 4) {
                            if isInjecting {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: SwissDesign.white))
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .black))
                                    .foregroundColor(SwissDesign.white)
                                Text("START")
                                    .font(.system(size: 11, weight: .black, design: .default))
                                    .tracking(1.0)
                                    .foregroundColor(SwissDesign.white)
                            }
                        }
                        .frame(width: 68, height: 68)
                        .background(SwissDesign.black)
                    }
                    .disabled(isInjecting)

                    // STOP square (International Red geometric square)
                    Button(action: {
                        stopStopwatch()
                        uninstallMod()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(SwissDesign.white)
                            Text("STOP")
                                .font(.system(size: 11, weight: .black, design: .default))
                                .tracking(1.0)
                                .foregroundColor(SwissDesign.white)
                        }
                        .frame(width: 68, height: 68)
                        .background(SwissDesign.red)
                    }

                    // Precision telemetry info
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CONTROL // MATRIX")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundColor(SwissDesign.textSecondary)
                        Text(hasInjected ? "MOD HOOK: ACTIVE" : "MOD HOOK: STANDBY")
                            .font(.system(size: 13, weight: .black, design: .default))
                            .foregroundColor(hasInjected ? SwissDesign.red : SwissDesign.black)
                        Text("RIGID GRID 1000HZ // FLAT DESIGN")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(SwissDesign.textSecondary)
                    }
                    .padding(.leading, 6)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                // ── LAP TIMES TABLE WITHOUT BORDERS ──
                VStack(alignment: .leading, spacing: 6) {
                    Text("LAP TIMES // TELEMETRY SPLITS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.4)
                        .foregroundColor(SwissDesign.textSecondary)
                    
                    // Header Row (without borders)
                    HStack(spacing: 0) {
                        Text("LAP")
                            .frame(width: 36, alignment: .leading)
                        Text("SPLIT")
                            .frame(width: 78, alignment: .leading)
                        Text("DIFF")
                            .frame(width: 58, alignment: .leading)
                        Text("SUBSYSTEM")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("STATE")
                            .frame(width: 60, alignment: .trailing)
                    }
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(SwissDesign.black)
                    .padding(.vertical, 2)

                    // Data Rows (clean without borders)
                    VStack(spacing: 3) {
                        LapRowView(lap: "01", split: "00:12.44", diff: "+12.44", subsys: "KERNEL_ARM64", state: "OK", isAccent: false)
                        LapRowView(lap: "02", split: "00:23.18", diff: "+10.74", subsys: "ESP_OVERLAY", state: "PASS", isAccent: false)
                        LapRowView(lap: "03", split: "00:34.90", diff: "+11.72", subsys: "AIM_MATRIX", state: "LOCKED", isAccent: false)
                        LapRowView(lap: "04", split: "00:45.32", diff: "+10.42", subsys: "SYNC_LOCAL", state: "ACTIVE", isAccent: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                Rectangle()
                    .fill(SwissDesign.line)
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)

                // ── CONTENT AREA ──
                if !license.guiConfig.gui_enabled {
                    lockedView
                } else {
                    if topTab == "Menu" && license.guiConfig.tab_menu {
                        if !license.isAuthed || !license.isCryptographicallyVerified {
                            authView
                        } else {
                            menuView
                        }
                    } else if topTab == "Profile" && license.guiConfig.tab_profile {
                        if !license.isAuthed || !license.isCryptographicallyVerified {
                            authView
                        } else {
                            profileView
                        }
                    } else if license.guiConfig.tab_menu {
                        if !license.isAuthed || !license.isCryptographicallyVerified { authView } else { menuView }
                    } else if license.guiConfig.tab_profile {
                        if !license.isAuthed || !license.isCryptographicallyVerified { authView } else { profileView }
                    } else {
                        lockedView
                    }
                }

                // ── RIGID GRID BOTTOM TABS ──
                if license.guiConfig.gui_enabled && availableTabs.count > 1 {
                    HStack(spacing: 0) {
                        ForEach(availableTabs, id: \.self) { tab in
                            Button(action: { topTab = tab }) {
                                Text(tab.uppercased())
                                    .font(.system(size: 11, weight: .black, design: .default))
                                    .tracking(1.4)
                                    .foregroundColor(topTab == tab ? SwissDesign.white : SwissDesign.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .background(topTab == tab ? SwissDesign.black : SwissDesign.surface)
                                    .overlay(
                                        Rectangle().stroke(SwissDesign.black, lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
            }
        }
        .onAppear {
            SecurityShield.enforceAntiDebug()
            loadConfig()
            license.fetchGuiConfig()
            licenseKeyInput = license.storedKey
            if let containerPath = ContainerStore.resolveAppContainerPath(bundleID: selectedBundleID) {
                let patchURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents/Assembly-CSharp-patch.bytes")
                if FileManager.default.fileExists(atPath: patchURL.path) {
                    hasInjected = true
                }
            }
            license.onLiveStateChanged = { active in
                self.syncConfig()
            }
            license.onTokenRefreshed = {
                self.syncConfig()
            }
            Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                if self.hasInjected && !self.license.isCryptographicallyVerified {
                    self.uninstallMod()
                }
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
        .onChange(of: license.guiConfig) { newCfg in
            if !newCfg.tab_menu && topTab == "Menu" && newCfg.tab_profile {
                topTab = "Profile"
            } else if !newCfg.tab_profile && topTab == "Profile" && newCfg.tab_menu {
                topTab = "Menu"
            }
        }
    }

    // MARK: - Chrono / Timer Logic
    private func startStopwatch() {
        stopwatchActive = true
        startTimestamp = Date()
        timerSubscription?.invalidate()
        timerSubscription = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            guard self.stopwatchActive, let start = self.startTimestamp else { return }
            let currentElapsed = self.accumulatedTime + Date().timeIntervalSince(start)
            let totalHundredths = Int(currentElapsed * 100)
            let mins = (totalHundredths / 6000) % 60
            let secs = (totalHundredths / 100) % 60
            let hundredths = totalHundredths % 100
            self.elapsedTimeString = String(format: "%02d:%02d.%02d", mins, secs, hundredths)
        }
    }

    private func stopStopwatch() {
        if let start = startTimestamp {
            accumulatedTime += Date().timeIntervalSince(start)
        }
        stopwatchActive = false
        timerSubscription?.invalidate()
        timerSubscription = nil
        startTimestamp = nil
    }

    // MARK: - Remote Notice Banner
    var noticeBannerView: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(SwissDesign.red)
                .frame(width: 4)
            Text(license.guiConfig.notice_text)
                .font(.system(size: 11, weight: .bold, design: .default))
                .foregroundColor(SwissDesign.black)
                .lineLimit(2)
            Spacer()
        }
        .padding(10)
        .background(SwissDesign.surface)
        .overlay(
            Rectangle().stroke(SwissDesign.line, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Remote Master Lock View
    var lockedView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Rectangle()
                    .stroke(SwissDesign.red, lineWidth: 2)
                    .frame(width: 64, height: 64)
                Image(systemName: "lock.fill")
                    .font(.system(size: 28))
                    .foregroundColor(SwissDesign.red)
            }
            Text("SYSTEM LOCKED")
                .font(.system(size: 18, weight: .black, design: .default))
                .tracking(1.5)
                .foregroundColor(SwissDesign.black)
            Text(license.guiConfig.notice_text.isEmpty ? "Menu is currently locked by administrator for maintenance." : license.guiConfig.notice_text)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundColor(SwissDesign.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: {
                license.fetchGuiConfig()
                if !license.storedKey.isEmpty {
                    license.authenticate(key: license.storedKey) { _, _ in }
                }
            }) {
                Text("REFRESH STATUS")
                    .font(.system(size: 11, weight: .black, design: .default))
                    .foregroundColor(SwissDesign.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(SwissDesign.black)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tamper Detected Trap
    var tamperDetectedView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Rectangle()
                    .fill(SwissDesign.red)
                    .frame(width: 64, height: 64)
                Image(systemName: "xmark")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(SwissDesign.white)
            }
            Text("INTEGRITY VIOLATION")
                .font(.system(size: 18, weight: .black, design: .default))
                .foregroundColor(SwissDesign.red)
                .tracking(1.5)
            Text("Unauthorized application tamper detected (Bypass / Proxy). Security termination triggered.")
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundColor(SwissDesign.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: { exit(0) }) {
                Text("EXIT APPLICATION")
                    .font(.system(size: 11, weight: .black, design: .default))
                    .foregroundColor(SwissDesign.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(SwissDesign.black)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SwissDesign.bg.edgesIgnoringSafeArea(.all))
        .onAppear {
            self.uninstallMod()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                exit(0)
            }
        }
    }

    // MARK: - Auth View (Swiss International Style)
    var authView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                SwissSection(number: "01", title: "LICENSE AUTHENTICATION") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ENTER LICENSE KEY")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(SwissDesign.textSecondary)

                        HStack {
                            TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKeyInput)
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundColor(SwissDesign.black)
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                        }
                        .padding(10)
                        .background(SwissDesign.surface)
                        .overlay(
                            Rectangle().stroke(SwissDesign.black, lineWidth: 1.5)
                        )

                        if let err = license.authError {
                            HStack(spacing: 6) {
                                Rectangle().fill(SwissDesign.red).frame(width: 4, height: 16)
                                Text(err)
                                    .font(.system(size: 11, weight: .bold, design: .default))
                                    .foregroundColor(SwissDesign.red)
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
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: SwissDesign.white))
                                } else {
                                    Text("VALIDATE LICENSE")
                                        .font(.system(size: 12, weight: .black, design: .default))
                                        .tracking(1.2)
                                        .foregroundColor(SwissDesign.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(SwissDesign.black)
                        }
                        .disabled(isAuthenticating || licenseKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                SwissSection(number: "02", title: "DEVICE TELEMETRY (HWID)") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("HARDWARE ID")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(SwissDesign.textSecondary)
                            Spacer()
                            Text(license.deviceId)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(SwissDesign.black)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Button(action: {
                            UIPasteboard.general.string = license.deviceId
                        }) {
                            Text("COPY HARDWARE ID")
                                .font(.system(size: 11, weight: .black, design: .default))
                                .foregroundColor(SwissDesign.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(SwissDesign.surface)
                                .overlay(
                                    Rectangle().stroke(SwissDesign.black, lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Menu Tab (Swiss International Style)
    var menuView: some View {
        Group {
            if !license.isCryptographicallyVerified {
                tamperDetectedView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // ── SILENT AIM ──
                        if license.guiConfig.card_silent_aim {
                            SwissSection(number: "01", title: "SILENT AIM") {
                                VStack(alignment: .leading, spacing: 6) {
                                    SwissToggleRow(label: "SILENT AIM", code: "01", isOn: $config.AimEnabled)

                                    if config.AimEnabled {
                                        Rectangle().fill(SwissDesign.line).frame(height: 1).padding(.vertical, 4)
                                        SwissToggleRow(label: "DRAW FOV CIRCLE", code: "02", isOn: $config.EspFov)
                                        SwissSliderRow(label: "SILENT FOV RADIUS", code: "03", value: $config.FovSize, range: 30...400, isPercent: false)
                                        SwissSliderRow(label: "HEADSHOT RATE", code: "04", value: $config.HeadshotRate, range: 0...100, isPercent: true)

                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text("05")
                                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                    .foregroundColor(SwissDesign.textSecondary)
                                                    .frame(width: 24, alignment: .leading)
                                                Text("TARGET BONE")
                                                    .font(.system(size: 11, weight: .bold, design: .default))
                                                    .foregroundColor(SwissDesign.black)
                                                Spacer()
                                            }
                                            HStack(spacing: 0) {
                                                ForEach(0..<3, id: \.self) { idx in
                                                    let name = idx == 0 ? "HEAD" : (idx == 1 ? "NECK" : "BODY")
                                                    Button(action: { config.AimTarget = idx }) {
                                                        Text(name)
                                                            .font(.system(size: 11, weight: .black, design: .default))
                                                            .foregroundColor(config.AimTarget == idx ? SwissDesign.white : SwissDesign.black)
                                                            .frame(maxWidth: .infinity)
                                                            .frame(height: 34)
                                                            .background(config.AimTarget == idx ? SwissDesign.black : SwissDesign.surface)
                                                            .overlay(
                                                                Rectangle().stroke(SwissDesign.black, lineWidth: 1)
                                                            )
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }

                        // ── AIM SYSTEM ──
                        if license.guiConfig.card_aim_system {
                            SwissSection(number: "02", title: "AIMBOT ENGINE") {
                                VStack(alignment: .leading, spacing: 6) {
                                    SwissToggleRow(label: "AIMBOT SYSTEM", code: "01", isOn: $config.AimSystemEnabled)

                                    if config.AimSystemEnabled {
                                        Rectangle().fill(SwissDesign.line).frame(height: 1).padding(.vertical, 4)
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text("02")
                                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                    .foregroundColor(SwissDesign.textSecondary)
                                                    .frame(width: 24, alignment: .leading)
                                                Text("TARGET BONE")
                                                    .font(.system(size: 11, weight: .bold, design: .default))
                                                    .foregroundColor(SwissDesign.black)
                                                Spacer()
                                            }
                                            HStack(spacing: 0) {
                                                ForEach(0..<3, id: \.self) { idx in
                                                    let name = idx == 0 ? "HEAD" : (idx == 1 ? "NECK" : "BODY")
                                                    Button(action: { config.AimTarget = idx }) {
                                                        Text(name)
                                                            .font(.system(size: 11, weight: .black, design: .default))
                                                            .foregroundColor(config.AimTarget == idx ? SwissDesign.white : SwissDesign.black)
                                                            .frame(maxWidth: .infinity)
                                                            .frame(height: 34)
                                                            .background(config.AimTarget == idx ? SwissDesign.black : SwissDesign.surface)
                                                            .overlay(
                                                                Rectangle().stroke(SwissDesign.black, lineWidth: 1)
                                                            )
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.vertical, 4)

                                        SwissToggleRow(label: "NO RECOIL STABILIZER", code: "03", isOn: $config.NoRecoil)
                                    }
                                }
                            }
                        }

                        // ── VISUALS (ESP) ──
                        if license.guiConfig.card_esp {
                            SwissSection(number: "03", title: "VISUALS (ESP)") {
                                VStack(alignment: .leading, spacing: 4) {
                                    SwissToggleRow(label: "ESP MASTER SWITCH", code: "01", isOn: $config.EspMaster)
                                    Rectangle().fill(SwissDesign.line).frame(height: 1).padding(.vertical, 2)
                                    SwissToggleRow(label: "2D BOUNDING BOX", code: "02", isOn: $config.EspBox)
                                    Rectangle().fill(SwissDesign.line).frame(height: 1).padding(.vertical, 2)
                                    SwissToggleRow(label: "SNAPLINE TRACER", code: "03", isOn: $config.EspLine)
                                    Rectangle().fill(SwissDesign.line).frame(height: 1).padding(.vertical, 2)
                                    SwissToggleRow(label: "PLAYER IDENTITY (NAME)", code: "04", isOn: $config.EspName)
                                    Rectangle().fill(SwissDesign.line).frame(height: 1).padding(.vertical, 2)
                                    SwissToggleRow(label: "HEALTH BAR INDICATOR", code: "05", isOn: $config.EspHealth)
                                    Rectangle().fill(SwissDesign.line).frame(height: 1).padding(.vertical, 2)
                                    SwissToggleRow(label: "DISTANCE TELEMETRY", code: "06", isOn: $config.EspDistance)
                                    Rectangle().fill(SwissDesign.line).frame(height: 1).padding(.vertical, 2)
                                    SwissToggleRow(label: "SKELETON WIREFRAME", code: "07", isOn: $config.EspSkeleton)
                                }
                            }
                        }

                        // ── COMBAT MODIFIERS ──
                        if license.guiConfig.card_other {
                            SwissSection(number: "04", title: "COMBAT MODIFIERS") {
                                VStack(alignment: .leading, spacing: 6) {
                                    SwissToggleRow(label: "DAMAGE MULTIPLIER (BUFF DAME)", code: "01", isOn: $config.BuffDame)
                                    Rectangle().fill(SwissDesign.line).frame(height: 1).padding(.vertical, 2)
                                    SwissToggleRow(label: "GHOST OCCLUSION (GHOST MODE)", code: "02", isOn: $config.GhostMode)
                                    Rectangle().fill(SwissDesign.line).frame(height: 1).padding(.vertical, 2)

                                    VStack(alignment: .leading, spacing: 4) {
                                        SwissToggleRow(label: "EXPANDED FOV (CAMXA)", code: "03", isOn: $config.CamXa)
                                        if config.CamXa {
                                            HStack {
                                                Text("SCALE: \(String(format: "%.1f", config.CamXaFloat))X")
                                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                                    .foregroundColor(SwissDesign.red)
                                                Spacer()
                                                Slider(value: $config.CamXaFloat, in: 1.0...10.0, step: 0.1)
                                                    .accentColor(SwissDesign.black)
                                                    .frame(width: 180)
                                            }
                                        }
                                    }
                                    Rectangle().fill(SwissDesign.line).frame(height: 1).padding(.vertical, 2)

                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("04")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(SwissDesign.textSecondary)
                                                .frame(width: 24, alignment: .leading)
                                            Text("SPEED MULTIPLIER")
                                                .font(.system(size: 11, weight: .bold, design: .default))
                                                .foregroundColor(SwissDesign.black)
                                            Spacer()
                                        }
                                        HStack(spacing: 0) {
                                            ForEach(1..<6, id: \.self) { idx in
                                                Button(action: { config.SpeedHack = idx }) {
                                                    Text("\(idx)X")
                                                        .font(.system(size: 11, weight: .black, design: .default))
                                                        .foregroundColor(config.SpeedHack == idx ? SwissDesign.white : SwissDesign.black)
                                                        .frame(maxWidth: .infinity)
                                                        .frame(height: 34)
                                                        .background(config.SpeedHack == idx ? SwissDesign.red : SwissDesign.surface)
                                                        .overlay(
                                                            Rectangle().stroke(SwissDesign.black, lineWidth: 1)
                                                        )
                                                }
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        // ── ANTI-BAN ──
                        if license.guiConfig.card_antiban {
                            SwissSection(number: "05", title: "SECURITY & ANTI-BAN") {
                                VStack(alignment: .leading, spacing: 6) {
                                    SwissToggleRow(label: "ANTI-BAN MEMORY SHIELD", code: "01", isOn: $config.AntiBan)
                                        .onChange(of: config.AntiBan) { _ in
                                            _ = saveConfigLocally()
                                            syncConfig()
                                        }
                                }
                            }
                        }

                        // ── GUEST UTILITIES ──
                        if license.guiConfig.card_guest {
                            SwissSection(number: "06", title: "GUEST ACCOUNT UTILITIES") {
                                VStack(alignment: .leading, spacing: 8) {
                                    SwissToggleRow(label: "SHOW LOBBY RESET BUTTON", code: "01", isOn: $config.ShowGuestBtn)
                                        .onChange(of: config.ShowGuestBtn) { _ in
                                            _ = saveConfigLocally()
                                            syncConfig()
                                        }

                                    SwissToggleRow(label: "AUTO RESET BEFORE LOGIN", code: "02", isOn: $config.reset_guest)
                                        .onChange(of: config.reset_guest) { newValue in
                                            if newValue {
                                                performResetGuest()
                                            } else {
                                                config.resetGuest = false
                                                config.resetGuestBeforeLogin = false
                                                _ = saveConfigLocally()
                                                syncConfig()
                                            }
                                        }

                                    Button(action: { performResetGuest() }) {
                                        Text("RESET GUEST IDENTIFIER NOW")
                                            .font(.system(size: 11, weight: .black, design: .default))
                                            .tracking(1.0)
                                            .foregroundColor(SwissDesign.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 40)
                                            .background(SwissDesign.black)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Profile Tab (Swiss International Style)
    var profileView: some View {
        Group {
            if !license.isCryptographicallyVerified {
                tamperDetectedView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        SwissSection(number: "01", title: "LICENSE SPECIFICATION") {
                            VStack(alignment: .leading, spacing: 10) {
                                // License Key
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("KEY IDENTIFIER")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .foregroundColor(SwissDesign.textSecondary)
                                    HStack {
                                        Text(license.storedKey.isEmpty ? "UNAUTHORIZED" : license.storedKey)
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundColor(SwissDesign.black)
                                            .lineLimit(1)
                                        Spacer()
                                        Button(action: { UIPasteboard.general.string = license.storedKey }) {
                                            Text("COPY")
                                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                                .foregroundColor(SwissDesign.black)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(SwissDesign.surface)
                                                .overlay(Rectangle().stroke(SwissDesign.black, lineWidth: 1))
                                        }
                                    }
                                }

                                Rectangle().fill(SwissDesign.line).frame(height: 1)

                                // HWID
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("HARDWARE HASH (HWID)")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .foregroundColor(SwissDesign.textSecondary)
                                    HStack {
                                        Text(license.deviceId)
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundColor(SwissDesign.black)
                                            .lineLimit(1)
                                        Spacer()
                                        Button(action: { UIPasteboard.general.string = license.deviceId }) {
                                            Text("COPY")
                                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                                .foregroundColor(SwissDesign.black)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(SwissDesign.surface)
                                                .overlay(Rectangle().stroke(SwissDesign.black, lineWidth: 1))
                                        }
                                    }
                                }

                                Rectangle().fill(SwissDesign.line).frame(height: 1)

                                // Expiration
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("EXPIRATION TELEMETRY")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .foregroundColor(SwissDesign.textSecondary)
                                    Text(license.deviceExpires.isEmpty ? "PERPETUAL / UNRESTRICTED" : license.deviceExpires)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(SwissDesign.black)
                                }

                                Rectangle().fill(SwissDesign.line).frame(height: 1)

                                // Status Indicator
                                HStack {
                                    Rectangle()
                                        .fill(license.isAuthed ? SwissDesign.red : SwissDesign.black)
                                        .frame(width: 8, height: 8)
                                    Text(license.isAuthed ? "STATUS: CRYPTO_VERIFIED // ACTIVE" : "STATUS: INACTIVE")
                                        .font(.system(size: 10, weight: .black, design: .monospaced))
                                        .foregroundColor(license.isAuthed ? SwissDesign.red : SwissDesign.black)
                                    Spacer()
                                }
                            }
                        }

                        SwissSection(number: "02", title: "SUPPORT CHANNELS") {
                            VStack(spacing: 8) {
                                Button(action: {
                                    if let url = URL(string: "https://t.me/cheatmeo") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Text("COMMUNITY CHANNEL")
                                            .font(.system(size: 11, weight: .black, design: .default))
                                            .foregroundColor(SwissDesign.black)
                                        Spacer()
                                        Text("@cheatmeo ->")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(SwissDesign.red)
                                    }
                                    .padding(10)
                                    .background(SwissDesign.surface)
                                    .overlay(Rectangle().stroke(SwissDesign.black, lineWidth: 1))
                                }

                                Button(action: {
                                    if let url = URL(string: "https://t.me/truongdeptrai7") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Text("ADMIN DIRECT")
                                            .font(.system(size: 11, weight: .black, design: .default))
                                            .foregroundColor(SwissDesign.black)
                                        Spacer()
                                        Text("@truongdeptrai7 ->")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(SwissDesign.red)
                                    }
                                    .padding(10)
                                    .background(SwissDesign.surface)
                                    .overlay(Rectangle().stroke(SwissDesign.black, lineWidth: 1))
                                }

                                Button(action: {
                                    license.storedKey = ""
                                    license.isAuthed = false
                                    license.stopHeartbeat()
                                    config.system_active = false
                                    syncConfig()
                                    topTab = "Menu"
                                }) {
                                    Text("CHANGE LICENSE KEY")
                                        .font(.system(size: 11, weight: .black, design: .default))
                                        .foregroundColor(SwissDesign.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 38)
                                        .background(SwissDesign.black)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Logic & Engine Operations
    private func log(_ msg: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logs.append("[\(ts)] \(msg)")
    }

    private func performResetGuest() {
        let fm = FileManager.default
        let secClasses = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity
        ]
        for secClass in secClasses {
            let query: [String: Any] = [kSecClass as String: secClass]
            SecItemDelete(query as CFDictionary)
        }

        let bundleCandidates = ["com.dts.freefireth", "com.dts.freefiremax"]
        for bundle in bundleCandidates {
            guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: bundle) else { continue }
            let docsURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents")
            let libURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Library")
            let prefsURL = libURL.appendingPathComponent("Preferences")
            let cachesURL = libURL.appendingPathComponent("Caches")
            
            if let files = try? fm.contentsOfDirectory(atPath: docsURL.path) {
                for file in files {
                    let lower = file.lowercased()
                    if lower == "assembly-csharp-patch.bytes" || lower == "localconfig.json" { continue }
                    if lower.contains("guest") || lower.contains("g_id") || lower.contains("device") || lower.contains("account") || lower.hasSuffix(".dat") {
                        try? fm.removeItem(at: docsURL.appendingPathComponent(file))
                    }
                }
            }
            
            let newUUID = UUID().uuidString.lowercased()
            let newDeviceId = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            try? newDeviceId.write(to: docsURL.appendingPathComponent("app_device_id.dat"), atomically: true, encoding: .utf8)
            try? newUUID.write(to: docsURL.appendingPathComponent("g_id.dat"), atomically: true, encoding: .utf8)
            try? "1".write(to: docsURL.appendingPathComponent("reset_guest.flag"), atomically: true, encoding: .utf8)
            
            if let plistFiles = try? fm.contentsOfDirectory(atPath: prefsURL.path) {
                for plist in plistFiles {
                    let pLower = plist.lowercased()
                    if pLower.contains("freefire") || pLower.contains("garena") || pLower.contains("msdk") {
                        try? fm.removeItem(at: prefsURL.appendingPathComponent(plist))
                    }
                }
            }
            try? fm.removeItem(at: prefsURL.appendingPathComponent("\(bundle).plist"))
            try? fm.removeItem(at: cachesURL.appendingPathComponent(bundle))
            
            let configURL = docsURL.appendingPathComponent("localConfig.json")
            var directConfig: [String: Any] = [:]
            if fm.fileExists(atPath: configURL.path),
               let existingData = try? Data(contentsOf: configURL),
               let existingObj = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
                directConfig = existingObj
            }
            directConfig["reset_guest"] = true
            directConfig["resetGuest"] = true
            directConfig["resetGuestBeforeLogin"] = true
            directConfig["ResetGuestEnabled"] = true
            directConfig["AutoResetGuest"] = true
            directConfig["ShowGuestBtn"] = config.ShowGuestBtn
            directConfig["testCodePatch"] = true
            directConfig["system_active"] = true
            if let directData = try? JSONSerialization.data(withJSONObject: directConfig, options: [.prettyPrinted]) {
                try? directData.write(to: configURL)
            }
        }

        let wasResetGuest = config.reset_guest
        config.reset_guest = true
        config.resetGuest = true
        config.resetGuestBeforeLogin = true
        _ = saveConfigLocally()
        syncConfig()
        if !wasResetGuest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.config.reset_guest = false
                self.config.resetGuest = false
                self.config.resetGuestBeforeLogin = false
            }
        }
    }

    private func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: "saved_esp_config") {
            if let decoded = try? JSONDecoder().decode(EspConfig.self, from: data) {
                config = decoded
                return
            }
        }
        
        do {
            let fm = FileManager.default
            let docsURL = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let configURL = docsURL.appendingPathComponent("localConfig.json")
            if fm.fileExists(atPath: configURL.path) {
                let data = try Data(contentsOf: configURL)
                if let decoded = try? JSONDecoder().decode(EspConfig.self, from: data) {
                    config = decoded
                }
            }
        } catch { }
    }

    private func saveConfigLocally() -> Data? {
        do {
            if license.systemActive && license.isCryptographicallyVerified {
                if !license.getMeomeo().isEmpty { config.meomeo = license.getMeomeo() }
                if !license.getSig().isEmpty { config.sig = license.getSig() }
                if !license.getToken().isEmpty { config.token = license.getToken() }
                if license.getTs() != 0 { config.ts = license.getTs() }
                config.system_active = true
            } else {
                config.meomeo = ""
                config.sig = ""
                config.token = ""
                config.ts = 0
                config.system_active = false
            }

            if let fullData = try? JSONEncoder().encode(config) {
                UserDefaults.standard.set(fullData, forKey: "saved_esp_config")
            }

            let minimalConfig: [String: Any] = [
                "token": config.system_active ? config.token : "",
                "system_active": config.system_active,
                "ts": config.system_active ? config.ts : 0,
                "meomeo": config.system_active ? config.meomeo : "",
                "sig": config.system_active ? config.sig : "",
                "device_id": license.deviceId,
                "license_key": license.storedKey,
                "AntiBan": config.AntiBan,
                "ShowGuestBtn": config.ShowGuestBtn,
                "reset_guest": config.reset_guest,
                "resetGuest": config.resetGuest,
                "resetGuestBeforeLogin": config.resetGuestBeforeLogin,
                "ResetGuestEnabled": config.reset_guest,
                "AutoResetGuest": config.reset_guest,
                "testCodePatch": true
            ]
            
            let data = try JSONSerialization.data(withJSONObject: minimalConfig, options: [.prettyPrinted])
            let fm = FileManager.default
            let docsURL = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            try data.write(to: docsURL.appendingPathComponent("localConfig.json"))
            return data
        } catch { return nil }
    }

    private func syncConfig() {
        guard hasInjected else { return }
        if !license.systemActive || !license.isCryptographicallyVerified {
            self.config.system_active = false
            self.config.token = ""
            self.config.ts = 0
            if let jsonData = self.saveConfigLocally(),
               let containerPath = ContainerStore.resolveAppContainerPath(bundleID: self.selectedBundleID) {
                let docsURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents")
                let configURL = docsURL.appendingPathComponent("localConfig.json")
                try? jsonData.write(to: configURL)
            }
            return
        }
        license.updateUserToggles(mask: config.userTogglesMask) { ok in
            if ok {
                self.config.token = self.license.getToken()
                guard let jsonData = self.saveConfigLocally() else { return }
                if let containerPath = ContainerStore.resolveAppContainerPath(bundleID: self.selectedBundleID) {
                    let docsURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents")
                    let configURL = docsURL.appendingPathComponent("localConfig.json")
                    try? jsonData.write(to: configURL)
                }
            }
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
        if SecurityShield.isDebuggerAttached || SecurityShield.isHooked {
            uninstallMod()
            exit(0)
        }
        guard license.isCryptographicallyVerified else {
            uninstallMod()
            return
        }
        isInjecting = true
        
        license.updateUserToggles(mask: config.userTogglesMask) { _ in
            self.config.token = self.license.getToken()
            guard let jsonData = self.saveConfigLocally() else {
                self.isInjecting = false
                return
            }

            self.license.checkStatus { ok in
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
                        self.topTab = "Menu"
                        self.license.startHeartbeat()
                    } catch { }
                    self.isInjecting = false
                }

                SecurityShield.secureSession.dataTask(with: request) { data, response, error in
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
    }
}
