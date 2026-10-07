import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Background
            Color(white: 0.04).ignoresSafeArea()
            
            // Ambient Glows
            Circle()
                .fill(Color.blue.opacity(0.2))
                .blur(radius: 100)
                .frame(width: 300, height: 300)
                .offset(x: -150, y: -250)
                
            Circle()
                .fill(Color.purple.opacity(0.2))
                .blur(radius: 100)
                .frame(width: 300, height: 300)
                .offset(x: 150, y: 350)

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 35) {
                        
                        // Header / Logo
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 96, height: 96)
                                    .shadow(color: Color.purple.opacity(0.5), radius: 20, x: 0, y: 10)
                                    
                                Image(systemName: "pawprint.fill")
                                    .font(.system(size: 46))
                                    .foregroundColor(.white)
                            }
                            .scaleEffect(isAnimating ? 1.0 : 0.7)
                            .opacity(isAnimating ? 1.0 : 0.0)
                            
                            VStack(spacing: 8) {
                                Text("MeoMeoExt")
                                    .font(.system(size: 34, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    
                                Text("PREMIUM FREE FIRE EXPERIENCE")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.6))
                                    .tracking(3)
                            }
                            .offset(y: isAnimating ? 0 : 20)
                            .opacity(isAnimating ? 1.0 : 0.0)
                        }
                        .padding(.top, 50)
                        
                        // Features
                        VStack(spacing: 16) {
                            FeatureRow(icon: "eye.fill", title: "Visuals / ESP", subtitle: "Hiển thị khung xương, khoảng cách, tên & lượng máu", color: .blue, delay: 0.2)
                            FeatureRow(icon: "scope", title: "Aimbot Memory", subtitle: "Khoá mục tiêu siêu nhạy, tự động ghim tâm vào đầu", color: .red, delay: 0.3)
                            FeatureRow(icon: "star.fill", title: "Tính Năng Mở Rộng", subtitle: "Speed Hack, Buff Sát Thương, Xoá Acc Khách nhanh chóng", color: .orange, delay: 0.4)
                            FeatureRow(icon: "bolt.shield.fill", title: "Anti-Ban An Toàn", subtitle: "Tránh quét ứng dụng, bảo vệ tài khoản của bạn", color: .green, delay: 0.5)
                        }
                        .padding(.horizontal, 24)
                        
                    }
                    .padding(.bottom, 40)
                }
                
                // Footer / Button
                VStack {
                    Button(action: {
                        let impactMed = UIImpactFeedbackGenerator(style: .medium)
                        impactMed.impactOccurred()
                        OnboardingStore.markCompleted()
                        onComplete()
                    }) {
                        HStack {
                            Text("TRẢI NGHIỆM NGAY")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .black))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.blue.opacity(0.3), radius: 15, x: 0, y: 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 34)
                    .padding(.top, 20)
                }
                .background(
                    Rectangle()
                        .fill(Color(white: 0.04))
                        .shadow(color: .black.opacity(0.5), radius: 20, y: -10)
                )
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8, blendDuration: 0.5)) {
                isAnimating = true
            }
        }
    }
}

struct FeatureRow: View {
    var icon: String
    var title: String
    var subtitle: String
    var color: Color
    var delay: Double
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 54, height: 54)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.55))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .offset(y: isVisible ? 0 : 30)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(delay)) {
                isVisible = true
            }
        }
    }
}

enum OnboardingStore {
    static let completedVersionKey = "onboarding.completedVersion"
    static let completedFingerprintKey = "onboarding.completedFingerprint"

    static var currentVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\\(v) (\\(b))"
    }

    static var bundleToken: String {
        if let exe = Bundle.main.executablePath,
           let attrs = try? FileManager.default.attributesOfItem(atPath: exe),
           let date = attrs[.modificationDate] as? Date {
            return String(Int(date.timeIntervalSince1970))
        }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: Bundle.main.bundlePath),
           let date = (attrs[.creationDate] as? Date) ?? (attrs[.modificationDate] as? Date) {
            return String(Int(date.timeIntervalSince1970))
        }
        return "0"
    }

    static var currentFingerprint: String { "\\(currentVersion)#\\(bundleToken)" }

    static var completedVersion: String? {
        UserDefaults.standard.string(forKey: completedVersionKey)
    }

    static var completedFingerprint: String? {
        UserDefaults.standard.string(forKey: completedFingerprintKey)
    }

    static func shouldShow() -> Bool {
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--skip-onboarding") { return false }
        if ProcessInfo.processInfo.arguments.contains("--reset-onboarding") { return true }
#endif
        let fp = currentFingerprint
        if let stored = completedFingerprint, !stored.isEmpty {
            return stored != fp
        }
        if let completed = completedVersion, !completed.isEmpty {
            if completed == currentVersion {
                UserDefaults.standard.set(fp, forKey: completedFingerprintKey)
                return false
            }
            return true
        }
        return true
    }

    static func markCompleted() {
        UserDefaults.standard.set(currentVersion, forKey: completedVersionKey)
        UserDefaults.standard.set(currentFingerprint, forKey: completedFingerprintKey)
    }
}
