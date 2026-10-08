import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void
    @State private var opacity: Double = 0.5

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)

                Text("Loading MeoMeo...")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(opacity)
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            opacity = 1.0
                        }
                    }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation {
                    onComplete()
                }
            }
        }
    }
}

enum OnboardingStore {
    static func shouldShow() -> Bool {
        return true
    }

    static func markCompleted() {
    }
}
