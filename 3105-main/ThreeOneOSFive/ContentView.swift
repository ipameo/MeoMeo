import SwiftUI
import UIKit
import Foundation

struct EspConfig: Codable {
    var meomeo: String = "20ad475df3de47b1b9b2106f83fcd794"
    var testCodePatch: Bool = true
    var EspMaster: Bool = false
    var EspBox: Bool = false
    var EspHealth: Bool = false
    var EspTracer: Bool = false
    var EspSkeleton: Bool = false
    var AimEnabled: Bool = false
    var AimSystemEnabled: Bool = false
    var EspFov: Bool = false
    var NoRecoil: Bool = false
    var AimTarget: Int = 0 // 0=Head, 1=Neck, 2=Body
    var FovSize: Float = 0.0
}

struct ContentView: View {
    // Environment objects to keep App.swift happy without crashing
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore

    @State private var config = EspConfig()
    @State private var statusMessage = ""
    @State private var isSuccess = false
    @State private var isInjecting = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("ESP Settings")) {
                    Toggle("Enable ESP Master", isOn: $config.EspMaster)
                    Toggle("Show Box", isOn: $config.EspBox)
                    Toggle("Show Health", isOn: $config.EspHealth)
                    Toggle("Show Tracer", isOn: $config.EspTracer)
                    Toggle("Show Skeleton", isOn: $config.EspSkeleton)
                }
                
                Section(header: Text("Aimbot Settings")) {
                    Toggle("Silent Aim", isOn: $config.AimEnabled)
                    Toggle("Aim System", isOn: $config.AimSystemEnabled)
                    
                    Picker("Aim Target", selection: $config.AimTarget) {
                        Text("Head").tag(0)
                        Text("Neck").tag(1)
                        Text("Body").tag(2)
                    }
                    
                    Toggle("Show FOV Circle", isOn: $config.EspFov)
                    
                    VStack {
                        Text("FOV Size: \(config.FovSize, specifier: "%.1f")")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Slider(value: $config.FovSize, in: 0...360, step: 1.0)
                    }
                    
                    Toggle("No Recoil", isOn: $config.NoRecoil)
                }

                Section {
                    Button(action: { injectGame(target: "com.dts.freefireth") }) {
                        if isInjecting {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Inject Free Fire")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                    .disabled(isInjecting)

                    Button(action: { injectGame(target: "com.dts.freefiremax") }) {
                        if isInjecting {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Inject Free Fire Max")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(10)
                    .disabled(isInjecting)
                }

                if !statusMessage.isEmpty {
                    Section {
                        Text(statusMessage)
                            .foregroundColor(isSuccess ? .green : .red)
                    }
                }
            }
            .navigationTitle("FreeFire Mod Menu")
            .onAppear(perform: loadConfig)
        }
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

    private func injectGame(target: String) {
        guard let jsonData = saveConfigLocally() else {
            statusMessage = "Error saving config"
            isSuccess = false
            return
        }
        
        isInjecting = true
        statusMessage = "Downloading payload from Github..."
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
                guard let data = data else {
                    self.statusMessage = "No data received"
                    self.isSuccess = false
                    return
                }
                
                // Resolve game container path
                guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: target) else {
                    self.statusMessage = "Could not find \(target). Is it installed?"
                    self.isSuccess = false
                    return
                }
                
                let docsURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents")
                let bytesURL = docsURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
                let configURL = docsURL.appendingPathComponent("localConfig.json")
                
                do {
                    // Create Documents folder if not exists
                    let fm = FileManager.default
                    if !fm.fileExists(atPath: docsURL.path) {
                        try fm.createDirectory(at: docsURL, withIntermediateDirectories: true)
                    }

                    // Write patch bytes
                    try data.write(to: bytesURL)
                    
                    // Write config json
                    try jsonData.write(to: configURL)
                    
                    self.statusMessage = "Done Mod! Injected to \(target)"
                    self.isSuccess = true
                    
                } catch {
                    self.statusMessage = "File Write Error: \(error.localizedDescription)"
                    self.isSuccess = false
                }
            }
        }.resume()
    }
}
