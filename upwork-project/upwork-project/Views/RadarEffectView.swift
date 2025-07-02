import SwiftUI

struct RadarEffectView: View {
    @State private var animationScale1: CGFloat = 1.0
    @State private var animationScale2: CGFloat = 1.0
    @State private var animationScale3: CGFloat = 1.0
    @State private var animationOpacity1: Double = 1.0
    @State private var animationOpacity2: Double = 1.0
    @State private var animationOpacity3: Double = 1.0
    
    let baseSize: CGFloat = 60
    let primaryColor = Color(hex: "7289da") // App's blue color scheme
    
    var body: some View {
        ZStack {
            // Ring 1 (innermost)
            Circle()
                .stroke(primaryColor, lineWidth: 2)
                .frame(width: baseSize, height: baseSize)
                .scaleEffect(animationScale1)
                .opacity(animationOpacity1)
            
            // Ring 2 (middle)
            Circle()
                .stroke(primaryColor, lineWidth: 1.5)
                .frame(width: baseSize, height: baseSize)
                .scaleEffect(animationScale2)
                .opacity(animationOpacity2)
            
            // Ring 3 (outermost)
            Circle()
                .stroke(primaryColor, lineWidth: 1)
                .frame(width: baseSize, height: baseSize)
                .scaleEffect(animationScale3)
                .opacity(animationOpacity3)
            
            // Center dot (user location indicator)
            Circle()
                .fill(primaryColor)
                .frame(width: 12, height: 12)
                .shadow(color: primaryColor.opacity(0.5), radius: 3, x: 0, y: 0)
        }
        .onAppear {
            startRadarAnimation()
        }
    }
    
    private func startRadarAnimation() {
        // Ring 1 animation (fastest)
        withAnimation(
            .easeOut(duration: 2.0)
            .repeatForever(autoreverses: false)
        ) {
            animationScale1 = 3.0
            animationOpacity1 = 0.0
        }
        
        // Ring 2 animation (medium speed, delayed start)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(
                .easeOut(duration: 2.0)
                .repeatForever(autoreverses: false)
            ) {
                animationScale2 = 3.0
                animationOpacity2 = 0.0
            }
        }
        
        // Ring 3 animation (slowest, most delayed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(
                .easeOut(duration: 2.0)
                .repeatForever(autoreverses: false)
            ) {
                animationScale3 = 3.0
                animationOpacity3 = 0.0
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        RadarEffectView()
    }
} 