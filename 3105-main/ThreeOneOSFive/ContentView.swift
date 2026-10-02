import SwiftUI
import UIKit
import Foundation

struct EspConfig: Codable, Equatable {
    var meomeo: String = "20ad475df3de47b1b9b2106f83fcd794"
    var testCodePatch: Bool = true
    var EspMaster: Bool = false
    var EspBox: Bool = false
    var EspLine: Bool = false
    var EspName: Bool = false
    var EspHealth: Bool = false
    var EspDistance: Bool = false
    var EspTracer: Bool = false
    var EspSkeleton: Bool = false
    var AimEnabled: Bool = false
    var AimSystemEnabled: Bool = false
    var EspFov: Bool = false
    var NoRecoil: Bool = false
    var AimTarget: Int = 0 // 0=Head, 1=Neck, 2=Body
    var FovSize: Float = 60.0
    var HeadshotRate: Float = 60.0 // Added for the UI
}

// Minimalist Toggle Style resembling the image (White thumb, grey/white track)
struct MinimalistToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(configuration.isOn ? Color.white : Color.gray.opacity(0.3))
                .frame(width: 50, height: 30)
                .overlay(
                    Circle()
                        .fill(configuration.isOn ? Color.black : Color.white)
                        .padding(3)
                        .offset(x: configuration.isOn ? 10 : -10)
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
    }
}

// Minimalist custom slider
struct MinimalistSlider: View {
    var title: String
    @Binding var value: Float
    var range: ClosedRange<Float>
    var isPercentage: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(Color(white: 0.6))
                
                Spacer()
                
                Text(isPercentage ? "\(Int(value))%" : "\(Int(value))")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(white: 0.2))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    let width = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width
                    
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: width, height: 4)
                        .cornerRadius(2)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(radius: 2)
                        .offset(x: width - 8)
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    let percentage = min(max(0, gesture.location.x / geometry.size.width), 1)
                                    let newValue = Float(percentage) * (range.upperBound - range.lowerBound) + range.lowerBound
                                    value = newValue
                                }
                        )
                }
            }
            .frame(height: 20)
        }
    }
}

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore

    @State private var config = EspConfig()
    @State private var statusMessage = ""
    @State private var isSuccess = false
    @State private var isInjecting = false
    
    @AppStorage("selectedTarget") private var selectedTarget = "com.dts.freefireth"
    @AppStorage("hasInjected") private var hasInjected = false

    @State private var activeTab = "Menu"

    var body: some View {
        HStack(spacing: 0) {
            // LEFT SIDEBAR (Tabs)
            VStack(spacing: 30) {
                Spacer()
                
                // Rotated Log Tab
                Button(action: { activeTab = "Log" }) {
                    Text("Log")
                        .font(.system(size: 15, weight: activeTab == "Log" ? .bold : .medium))
                        .foregroundColor(activeTab == "Log" ? .white : Color(white: 0.5))
                        .frame(width: 80)
                }
                .rotationEffect(.degrees(-90))
                .frame(width: 40, height: 80)
                
                // Rotated Menu Tab
                Button(action: { activeTab = "Menu" }) {
                    Text("Menu")
                        .font(.system(size: 15, weight: activeTab == "Menu" ? .bold : .medium))
                        .foregroundColor(activeTab == "Menu" ? .white : Color(white: 0.5))
                        .frame(width: 80)
                }
                .rotationEffect(.degrees(-90))
                .frame(width: 40, height: 80)
                
                Spacer()
            }
            .frame(width: 60)
            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
            
            // GAME SELECTION COLUMN (or just top bar in a VStack)
            VStack(spacing: 0) {
                // GAMES TABS
                HStack(spacing: 10) {
                    GameTab(title: "Free Fire", isSelected: selectedTarget == "com.dts.freefireth") {
                        selectedTarget = "com.dts.freefireth"
                    }
                    GameTab(title: "Free Fire MAX", isSelected: selectedTarget == "com.dts.freefiremax") {
                        selectedTarget = "com.dts.freefiremax"
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // MAIN CONTENT
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 25) {
                        
                        // AIMING SECTION
                        SectionHeader(title: "AIMING")
                        
                        VStack(spacing: 20) {
                            // Top Row: Icon + Texts + Toggle
                            HStack(spacing: 15) {
                                // Icon Box
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(white: 0.9))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Image(systemName: "wind")
                                            .foregroundColor(.black)
                                            .font(.system(size: 20, weight: .bold))
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Aim Silent")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("Silent aim with headshot rate and FOV")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(Color(white: 0.5))
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $config.AimEnabled)
                                    .toggleStyle(MinimalistToggleStyle())
                                    .labelsHidden()
                            }
                            
                            Divider().background(Color(white: 0.2))
                            
                            // Sliders
                            MinimalistSlider(title: "Silent FOV", value: $config.FovSize, range: 0...360, isPercentage: false)
                            MinimalistSlider(title: "Headshot", value: $config.HeadshotRate, range: 0...100, isPercentage: true)
                        }
                        .padding(20)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                        .cornerRadius(16)
                        
                        // VISUALS SECTION
                        SectionHeader(title: "VISUALS")
                        
                        VStack(spacing: 20) {
                            VisualToggleRow(icon: "eye", title: "Enable ESP", desc: "Master switch for all visuals", isOn: $config.EspMaster)
                            Divider().background(Color(white: 0.2))
                            VisualToggleRow(icon: "person.crop.square", title: "Show Box", desc: "Draw box around players", isOn: $config.EspBox)
                            Divider().background(Color(white: 0.2))
                            VisualToggleRow(icon: "lines.measurement.horizontal", title: "Show Line", desc: "Draw line to players", isOn: $config.EspLine)
                            Divider().background(Color(white: 0.2))
                            VisualToggleRow(icon: "heart.fill", title: "Show Health", desc: "Display player HP", isOn: $config.EspHealth)
                            Divider().background(Color(white: 0.2))
                            VisualToggleRow(icon: "textformat", title: "Show Name", desc: "Display player name above box", isOn: $config.EspName)
                        }
                        .padding(20)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                        .cornerRadius(16)

                        // ENEMY COUNT SECTION
                        SectionHeader(title: "ENEMY COUNTER")

                        HStack(spacing: 0) {
                            Image(systemName: "person.3.fill")
                                .foregroundColor(Color(white: 0.5))
                                .font(.system(size: 18))
                                .padding(.trailing, 12)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Enemy Count")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("MeoMeo iOS counter shown in-game")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(white: 0.45))
                            }
                            Spacer()
                            Text("IN-GAME")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white)
                                .cornerRadius(6)
                        }
                        .padding(20)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                        .cornerRadius(16)
                        
                        // INJECT/UNINSTALL BUTTON
                        VStack {
                            if !hasInjected {
                                Button(action: { injectGame(target: selectedTarget) }) {
                                    Text(isInjecting ? "INJECTING..." : "INJECT MOD")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 54)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                }
                                .disabled(isInjecting)
                            } else {
                                Button(action: { uninstallMod(target: selectedTarget) }) {
                                    Text("UNINSTALL MOD")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 54)
                                        .background(Color.red.opacity(0.8))
                                        .cornerRadius(12)
                                }
                            }
                            
                            if !statusMessage.isEmpty {
                                Text(statusMessage)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(isSuccess ? .green : .red)
                                    .padding(.top, 10)
                            }
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 40)
                    }
                    .padding(20)
                }
            }
            .background(Color(red: 0.05, green: 0.05, blue: 0.06))
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear(perform: loadConfig)
        .onChange(of: config) { _ in
            if hasInjected {
                syncConfigToGame(target: selectedTarget)
            }
        }
        .colorScheme(.dark)
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
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            let fm = FileManager.default
            let docsURL = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let configURL = docsURL.appendingPathComponent("localConfig.json")
            try data.write(to: configURL)
            return data
        } catch {
            return nil
        }
    }

    private func syncConfigToGame(target: String) {
        guard let jsonData = saveConfigLocally() else { return }
        guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: target) else {
            hasInjected = false
            return
        }
        let docsURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents")
        let configURL = docsURL.appendingPathComponent("localConfig.json")
        do {
            if FileManager.default.fileExists(atPath: docsURL.path) {
                try jsonData.write(to: configURL)
            }
        } catch { }
    }

    private func uninstallMod(target: String) {
        guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: target) else {
            statusMessage = "Cannot find game container."
            isSuccess = false
            hasInjected = false
            return
        }
        let docsURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents")
        let bytesURL = docsURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
        let configURL = docsURL.appendingPathComponent("localConfig.json")
        
        do {
            let fm = FileManager.default
            if fm.fileExists(atPath: bytesURL.path) { try fm.removeItem(at: bytesURL) }
            if fm.fileExists(atPath: configURL.path) { try fm.removeItem(at: configURL) }
            
            statusMessage = "Uninstall Mod Done!"
            isSuccess = true
            hasInjected = false
        } catch {
            statusMessage = "Uninstall Error: \(error.localizedDescription)"
            isSuccess = false
        }
    }

    private func injectGame(target: String) {
        // ALWAYS SYNC config.AimEnabled to config.EspFov if they want the circle!
        if config.AimEnabled {
            config.EspFov = true
        }
        
        guard let jsonData = saveConfigLocally() else {
            statusMessage = "Error saving config"
            isSuccess = false
            return
        }
        
        isInjecting = true
        statusMessage = "Downloading payload from GitHub..."
        isSuccess = true
        
        let token = "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"
        let urlStr = "https://raw.githubusercontent.com/xuantrun/vipmof/main/Assembly-CSharp-patch.bytes"
        
        guard let url = URL(string: urlStr) else {
            self.statusMessage = "Invalid URL"
            self.isSuccess = false
            self.isInjecting = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isInjecting = false
                if let error = error {
                    self.statusMessage = "Download Error: \(error.localizedDescription)"
                    self.isSuccess = false
                    return
                }
                
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
                    self.statusMessage = "GitHub API Error: \(httpResp.statusCode)"
                    self.isSuccess = false
                    return
                }
                
                guard let data = data else {
                    self.statusMessage = "No data received"
                    self.isSuccess = false
                    return
                }
                
                guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: target) else {
                    self.statusMessage = "Could not find \(target)."
                    self.isSuccess = false
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
                    try jsonData.write(to: configURL)
                    
                    self.statusMessage = "Done Mod"
                    self.isSuccess = true
                    self.hasInjected = true
                } catch {
                    self.statusMessage = "File Write Error: \(error.localizedDescription)"
                    self.isSuccess = false
                }
            }
        }.resume()
    }
}

struct SectionHeader: View {
    var title: String
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundColor(Color(white: 0.4))
            .padding(.leading, 5)
    }
}

struct GameTab: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.white : Color(white: 0.15))
                )
        }
    }
}

struct VisualToggleRow: View {
    var icon: String
    var title: String
    var desc: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.15))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(white: 0.5))
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(MinimalistToggleStyle())
                .labelsHidden()
        }
    }
}
