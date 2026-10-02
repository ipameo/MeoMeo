import SwiftUI
import UIKit
import Foundation

// MARK: - Config Model
struct EspConfig: Codable, Equatable {
    var meomeo: String = "20ad475df3de47b1b9b2106f83fcd794"
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

    @State private var config = EspConfig()
    @State private var isInjecting = false
    @State private var hasInjected = false
    @State private var topTab: String = "Menu"   // "Menu" | "Log"
    @State private var gameTab: String = "ff"    // "ff" | "ffmax"
    @State private var logs: [String] = []

    private var selectedBundleID: String {
        gameTab == "ff" ? "com.dts.freefireth" : "com.dts.freefiremax"
    }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.07).ignoresSafeArea()

            VStack(spacing: 0) {
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
                .padding(.top, 16)
                .padding(.bottom, 10)

                // ── GAME SELECTOR ─────────────────────────────────────
                HStack(spacing: 0) {
                    ForEach([("Free Fire", "ff"), ("Free Fire MAX", "ffmax")], id: \.1) { label, id in
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
                    menuView
                } else {
                    logView
                }
            }
        }
        .onAppear(perform: loadConfig)
        .onChange(of: config) { _ in
            if hasInjected { syncConfig() }
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
                                    ForEach([(0,"Head"),(1,"Neck"),(2,"Body")], id: \.0) { idx, name in
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
                                    ForEach([(0,"Head"),(1,"Neck"),(2,"Body")], id: \.0) { idx, name in
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
                    ForEach(logs.reversed(), id: \.self) { line in
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
        } catch {
            log("❌ Uninstall error: \(error)")
        }
    }

    private func injectGame() {
        guard let jsonData = saveConfigLocally() else {
            log("❌ Error saving config")
            return
        }
        isInjecting = true
        log("⏳ Downloading payload from GitHub...")
        topTab = "Log"

        let token = "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"
        let urlStr = "https://raw.githubusercontent.com/xuantrun/vipmof/main/Assembly-CSharp-patch.bytes"
        guard let url = URL(string: urlStr) else {
            log("❌ Invalid URL"); isInjecting = false; return
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
                    try jsonData.write(to: configURL)
                    self.log("✅ Done Mod — launch \(self.gameTab == \"ff\" ? \"Free Fire\" : \"Free Fire MAX\") now!")
                    self.hasInjected = true
                    self.topTab = "Menu"
                } catch {
                    self.log("❌ Write error: \(error)")
                }
            }
        }.resume()
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
