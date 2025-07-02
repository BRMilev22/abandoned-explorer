import SwiftUI

struct AnimatedGroupsButton: View {
    let action: () -> Void
    
    @State private var shimmerOffset: CGFloat = -60
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Groups")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "#7289da"))
            .cornerRadius(20)
            .overlay(
                // Safe shimmer effect that stays contained
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.6),
                                .white,
                                .white.opacity(0.6),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
                    .mask(
                        Rectangle()
                            .offset(x: shimmerOffset)
                            .frame(width: 40)
                    )
            )
            .scaleEffect(pulseScale)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // Simple shimmer sweep
            withAnimation(
                .linear(duration: 2.0)
                .repeatForever(autoreverses: false)
            ) {
                shimmerOffset = 120
            }
            
            // Subtle pulse
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.05
            }
        }
    }
}

struct ModernAnimatedButton: View {
    let title: String
    let action: () -> Void
    
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Base button
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.4, green: 0.6, blue: 1.0),
                                Color(red: 0.3, green: 0.5, blue: 0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 56)
                
                // Moving border animation
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                .white.opacity(0.0),
                                .white.opacity(0.3),
                                .white,
                                .white,
                                .white.opacity(0.3),
                                .white.opacity(0.0),
                                .white.opacity(0.0)
                            ],
                            center: .center,
                            startAngle: .degrees(Double(animationProgress * 360 - 45)),
                            endAngle: .degrees(Double(animationProgress * 360 + 45))
                        ),
                        lineWidth: 3
                    )
                    .frame(height: 56)
                
                // Button text
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear {
            withAnimation(
                .linear(duration: 2.0)
                .repeatForever(autoreverses: false)
            ) {
                animationProgress = 1.0
            }
        }
    }
}

struct AnimatedShimmerButton: View {
    let title: String
    let action: () -> Void
    
    @State private var animationOffset: CGFloat = -200
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Base button background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
                    .frame(height: 56)
                
                // Animated shimmer overlay
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .clear,
                                .green.opacity(0.3),
                                .green,
                                .green.opacity(0.8),
                                .green.opacity(0.3),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
                    .frame(height: 56)
                    .mask(
                        Rectangle()
                            .offset(x: animationOffset)
                            .frame(width: 100)
                    )
                
                // Inner glow effect
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .green.opacity(0.1),
                                .green.opacity(0.3),
                                .green.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(height: 56)
                
                // Button text
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear {
            startAnimation()
        }
        .onChange(of: isAnimating) { _ in
            if isAnimating {
                withAnimation(
                    .linear(duration: 2.0)
                    .repeatForever(autoreverses: false)
                ) {
                    animationOffset = 400
                }
            }
        }
    }
    
    private func startAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAnimating = true
        }
    }
}

struct PulsingShimmerButton: View {
    let title: String
    let action: () -> Void
    
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Base button
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
                    .frame(height: 56)
                
                // Rotating shimmer border
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                .clear,
                                .green.opacity(0.3),
                                .green,
                                .green.opacity(0.8),
                                .green,
                                .green.opacity(0.3),
                                .clear,
                                .clear
                            ],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        lineWidth: 2
                    )
                    .frame(height: 56)
                    .rotationEffect(.degrees(rotation))
                
                // Inner subtle glow
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        RadialGradient(
                            colors: [
                                .green.opacity(0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(height: 54)
                
                // Button text
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(scale)
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(
                .linear(duration: 3.0)
                .repeatForever(autoreverses: false)
            ) {
                rotation = 360
            }
            
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                scale = 1.02
            }
        }
        .onTapGesture {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }
    }
}

struct WaveShimmerButton: View {
    let title: String
    let action: () -> Void
    
    @State private var phase: CGFloat = 0
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Base button
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
                    .frame(height: 56)
                
                // Wave shimmer effect
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(lineWidth: 2)
                    .foregroundStyle(
                        .linearGradient(
                            colors: [
                                .clear,
                                .green.opacity(0.4),
                                .green,
                                .green.opacity(0.4),
                                .clear
                            ],
                            startPoint: UnitPoint(
                                x: 0.5 + 0.5 * cos(phase),
                                y: 0.5 + 0.5 * sin(phase)
                            ),
                            endPoint: UnitPoint(
                                x: 0.5 - 0.5 * cos(phase),
                                y: 0.5 - 0.5 * sin(phase)
                            )
                        )
                    )
                    .frame(height: 56)
                
                // Subtle inner border
                RoundedRectangle(cornerRadius: 15)
                    .strokeBorder(
                        .green.opacity(0.2),
                        lineWidth: 1
                    )
                    .frame(height: 54)
                
                // Button text with subtle glow
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .green.opacity(0.3), radius: 2)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear {
            withAnimation(
                .linear(duration: 2.5)
                .repeatForever(autoreverses: false)
            ) {
                phase = .pi * 2
            }
        }
    }
}

// Custom button style for press animation
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Preview
struct AnimatedButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            AnimatedGroupsButton {
                print("Animated Groups button tapped")
            }
            
            ModernAnimatedButton(title: "Groups") {
                print("Modern Animated tapped")
            }
            
            AnimatedShimmerButton(title: "Create Group") {
                print("Animated Shimmer tapped")
            }
            
            PulsingShimmerButton(title: "Join Group") {
                print("Pulsing Shimmer tapped")
            }
            
            WaveShimmerButton(title: "Beautiful Button") {
                print("Wave Shimmer tapped")
            }
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
} 