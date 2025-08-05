//
//  LocationSuggestionView.swift
//  upwork-project
//
//  Created by Boris Milev on 02.07.25.
//

import SwiftUI
import CoreLocation

// MARK: - Gamification Models
struct ExplorerStats {
    var level: Int = 1
    var experience: Int = 0
    var locationsFound: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var rarityScore: Int = 0
    var achievements: [Achievement] = []
}

struct Achievement: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let rarity: AchievementRarity
    let isUnlocked: Bool
}

enum AchievementRarity: String, CaseIterable {
    case common = "Common"
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"
    
    var color: Color {
        switch self {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
    
    var glow: Color {
        switch self {
        case .common: return .white.opacity(0.3)
        case .rare: return .blue.opacity(0.6)
        case .epic: return .purple.opacity(0.6)
        case .legendary: return .orange.opacity(0.8)
        }
    }
}

enum LocationRarity: String, CaseIterable {
    case common = "Common"
    case uncommon = "Uncommon" 
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"
    
    var color: Color {
        switch self {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
    
    var sparkleCount: Int {
        switch self {
        case .common: return 0
        case .uncommon: return 1
        case .rare: return 2
        case .epic: return 3
        case .legendary: return 5
        }
    }
}

struct LocationSuggestionView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    let userLocation: CLLocationCoordinate2D?
    let currentLocationName: String
    
    @State private var suggestedLocations: [USALocation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedLocation: USALocation?
    @State private var showingLocationDetail = false
    
    // Animation states
    @State private var animationPhase: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var shimmerOffset: CGFloat = -200
    @State private var generationProgress: Double = 0
    @State private var showGenerationFlow = false
    @State private var discoveryParticles: [DiscoveryParticle] = []
    
    // Gamification states
    @State private var explorerStats = ExplorerStats()
    @State private var showingAchievement = false
    @State private var currentAchievement: Achievement?
    @State private var treasureChestScale: CGFloat = 1.0
    @State private var showingReward = false
    @State private var dailyStreak = 3
    @State private var todaysDiscoveries = 2
    @State private var isOnStreak = true
    
    var body: some View {
        ZStack {
            // Dynamic background with animated gradients
            AnimatedBackground()
            
            VStack(spacing: 0) {
                // Modern header with floating elements
                headerView
                
                // Content area with generation flow
                if isLoading {
                    GenerationFlowView(progress: $generationProgress)
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                } else if suggestedLocations.isEmpty {
                    ModernEmptyStateView(onRegenerate: loadRandomLocationSuggestions)
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                } else {
                    TreasureLocationGridView(locations: suggestedLocations, onLocationSelect: selectLocation)
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startDiscoveryAnimations()
            loadRandomLocationSuggestions()
        }
        .sheet(isPresented: $showingLocationDetail) {
            if let location = selectedLocation {
                USALocationDetailView(location: location)
            }
        }
        .overlay(
            // Floating particles
            ParticleOverlay(particles: discoveryParticles)
        )
        .overlay(
            // Achievement notification
            AchievementNotificationView(
                achievement: currentAchievement,
                isShowing: $showingAchievement
            )
        )
        .overlay(
            // Custom navigation overlay
            NavigationOverlay(onDismiss: { dismiss() }, onRefresh: loadRandomLocationSuggestions, isLoading: isLoading)
        )
        .preferredColorScheme(.dark)
    }
    
    private var headerView: some View {
        VStack(spacing: 24) {
            // Explorer Profile & Streak
            ExplorerProfileView(
                level: explorerStats.level,
                experience: explorerStats.experience,
                streak: dailyStreak,
                todaysFinds: todaysDiscoveries,
                isOnStreak: isOnStreak
            )
            
            // Treasure Hunt Title
            TreasureHuntHeader()
            
            // Mystery Orb with Treasure Chest
            MysteryOrbView(
                isAnimating: !isLoading,
                chestScale: treasureChestScale,
                onTap: {
                    if !isLoading {
                        triggerTreasureAnimation()
                    }
                }
            )
            .scaleEffect(pulseScale)
            .rotationEffect(.degrees(rotationAngle))
            
            // Stats dashboard
            if !suggestedLocations.isEmpty {
                GameifiedStatsView(locations: suggestedLocations, explorerStats: explorerStats)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    private func selectLocation(_ location: USALocation) {
        selectedLocation = location
        showingLocationDetail = true
    }
    
    private func loadRandomLocationSuggestions() {
        guard let userLoc = userLocation else {
            errorMessage = "Location not available"
            return
        }
        
        isLoading = true
        errorMessage = nil
        generationProgress = 0
        
        // Start generation animation
        startGenerationAnimation()
        
        Task {
            do {
                let locations = try await dataManager.getRandomUSALocations(
                    latitude: userLoc.latitude,
                    longitude: userLoc.longitude,
                    radius: 50,
                    limit: 10
                )
                
                // Wait for minimum animation time to complete
                try await Task.sleep(nanoseconds: 3_500_000_000) // 3.5 seconds
                
                await MainActor.run {
                    // Force update the state in the correct order
                    self.generationProgress = 1.0
                    self.suggestedLocations = locations
                    self.errorMessage = nil
                    
                    // Delay the loading state change to ensure smooth transition
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                            self.isLoading = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    self.generationProgress = 0
                }
            }
        }
    }
    
    private func startDiscoveryAnimations() {
        // Continuous pulsing
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
        
        // Continuous rotation
        withAnimation(.linear(duration: 10.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        // Shimmer effect
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            shimmerOffset = 200
        }
        
        // Generate particles
        generateDiscoveryParticles()
    }
    
    private func startGenerationAnimation() {
        // Start with immediate progress
        withAnimation(.easeInOut(duration: 3.0)) {
            generationProgress = 0.9
        }
        
        // This will be completed when the API call finishes
        // The final 0.1 progress will be set when locations are loaded
    }
    
    private func generateDiscoveryParticles() {
        discoveryParticles = []
        for _ in 0..<15 {
            let particle = DiscoveryParticle(
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: CGFloat.random(in: 0...UIScreen.main.bounds.height),
                size: CGFloat.random(in: 1...3),
                opacity: Double.random(in: 0.1...0.3),
                animationDelay: Double.random(in: 0...2)
            )
            discoveryParticles.append(particle)
        }
    }
    
    private func triggerTreasureAnimation() {
        // Prevent multiple simultaneous calls
        guard !isLoading else { return }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            treasureChestScale = 1.3
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                treasureChestScale = 1.0
            }
        }
        
        // Update stats and check for achievements
        todaysDiscoveries += 1
        explorerStats.locationsFound += 1
        
        checkForAchievements()
        
        // Clear previous results and trigger new search
        suggestedLocations = []
        errorMessage = nil
        loadRandomLocationSuggestions()
    }
    
    private func checkForAchievements() {
        // Check for various achievements
        if todaysDiscoveries == 1 {
            triggerAchievement(.init(
                title: "First Discovery",
                description: "Found your first treasure today!",
                icon: "🎯",
                rarity: .common,
                isUnlocked: true
            ))
        }
        
        if todaysDiscoveries == 5 {
            triggerAchievement(.init(
                title: "Daily Explorer",
                description: "Completed daily challenge!",
                icon: "🏆",
                rarity: .rare,
                isUnlocked: true
            ))
        }
        
        if dailyStreak >= 7 {
            triggerAchievement(.init(
                title: "Weekly Warrior",
                description: "7 days of consecutive exploration!",
                icon: "⚡",
                rarity: .epic,
                isUnlocked: true
            ))
        }
        
        if explorerStats.locationsFound >= 10 {
            triggerAchievement(.init(
                title: "Treasure Hunter",
                description: "Discovered 10 abandoned locations!",
                icon: "🗺️",
                rarity: .legendary,
                isUnlocked: true
            ))
        }
    }
    
    private func triggerAchievement(_ achievement: Achievement) {
        currentAchievement = achievement
        
        // Trigger achievement notification
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showingAchievement = true
        }
        
        // Update explorer stats
        explorerStats.experience += 25
        explorerStats.achievements.append(achievement)
        
        // Celebration haptic
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
}

// MARK: - Gamified Components

struct ExplorerProfileView: View {
    let level: Int
    let experience: Int
    let streak: Int
    let todaysFinds: Int
    let isOnStreak: Bool
    
    @State private var experienceBarProgress: CGFloat = 0
    @State private var streakPulse: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 16) {
            // Level Badge with XP Ring
            ZStack {
                // XP Progress Ring
                Circle()
                    .stroke(Color(hex: "#7289da").opacity(0.3), lineWidth: 3)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: experienceBarProgress)
                    .stroke(
                        AngularGradient(
                            colors: [Color(hex: "#7289da"), Color(hex: "#8b9dc3"), Color(hex: "#7289da")],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color(hex: "#7289da").opacity(0.6), radius: 4, x: 0, y: 0)
                
                // Level Number
                VStack(spacing: 2) {
                    Text("\(level)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("LVL")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(hex: "#7289da"))
                }
            }
            
            // Stats Column
            VStack(alignment: .leading, spacing: 8) {
                // Streak Fire
                HStack(spacing: 8) {
                    Image(systemName: isOnStreak ? "flame.fill" : "flame")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isOnStreak ? .orange : .gray)
                        .scaleEffect(streakPulse)
                    
                    Text("\(streak) Day Streak")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isOnStreak ? .orange : .gray)
                    
                    if isOnStreak {
                        Text("🔥")
                            .font(.system(size: 12))
                            .scaleEffect(streakPulse)
                    }
                }
                
                // Today's Progress
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)
                    
                    Text("Today: \(todaysFinds)/5 discoveries")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#7289da").opacity(0.4),
                                    Color.white.opacity(0.1),
                                    Color(hex: "#7289da").opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                experienceBarProgress = CGFloat(experience % 100) / 100.0
            }
            
            if isOnStreak {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    streakPulse = 1.2
                }
            }
        }
    }
}

struct TreasureHuntHeader: View {
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("🗺️")
                    .font(.system(size: 24))
                
                Text("Treasure Hunt")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        // Shimmer effect
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.6), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .mask(
                            Text("Treasure Hunt")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                        )
                        .offset(x: shimmerOffset)
                    )
                    .shadow(color: .orange.opacity(0.5), radius: 8, x: 0, y: 0)
                
                Text("💎")
                    .font(.system(size: 24))
            }
            
            Text("Discover hidden gems waiting to be found!")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                shimmerOffset = 200
            }
        }
    }
}

struct MysteryOrbView: View {
    let isAnimating: Bool
    let chestScale: CGFloat
    let onTap: () -> Void
    
    @State private var innerRotation: Double = 0
    @State private var outerRotation: Double = 0
    @State private var breatheScale: CGFloat = 1.0
    @State private var sparkleRotation: Double = 0
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Sparkle ring
                ForEach(0..<8, id: \.self) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.yellow)
                        .offset(
                            x: cos(Double(index) * .pi / 4) * 80,
                            y: sin(Double(index) * .pi / 4) * 80
                        )
                        .rotationEffect(.degrees(sparkleRotation))
                        .opacity(0.8)
                }
                
                // Outer magical ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                .yellow.opacity(0.1),
                                .orange.opacity(0.8),
                                .yellow,
                                .orange,
                                .yellow.opacity(0.8),
                                .yellow.opacity(0.1)
                            ],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(outerRotation))
                    .shadow(color: .orange.opacity(0.6), radius: 15, x: 0, y: 0)
                
                // Treasure chest
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .brown.opacity(0.8),
                                    .brown.opacity(0.4),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 90, height: 90)
                    
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Text("📦")
                                .font(.system(size: 32))
                                .scaleEffect(chestScale)
                        )
                }
                .scaleEffect(breatheScale)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            if isAnimating {
                withAnimation(.linear(duration: 12.0).repeatForever(autoreverses: false)) {
                    outerRotation = 360
                }
                withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                    innerRotation = -360
                }
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    breatheScale = 1.1
                }
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    sparkleRotation = 360
                }
            }
        }
    }
}

// MARK: - Discovery Orb

struct DiscoveryOrb: View {
    let isAnimating: Bool
    @State private var innerRotation: Double = 0
    @State private var outerRotation: Double = 0
    @State private var breatheScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(hex: "#7289da").opacity(0.1),
                            Color(hex: "#7289da").opacity(0.8),
                            Color(hex: "#5b6eae"),
                            Color(hex: "#7289da"),
                            Color(hex: "#8b9dc3"),
                            Color(hex: "#7289da").opacity(0.1)
                        ],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    lineWidth: 3
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(outerRotation))
                .shadow(color: Color(hex: "#7289da").opacity(0.4), radius: 20, x: 0, y: 0)
            
            // Inner core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#7289da").opacity(0.8),
                            Color(hex: "#7289da").opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 40
                    )
                )
                .frame(width: 80, height: 80)
                .overlay(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "location.magnifyingglass")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, Color(hex: "#7289da")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .rotationEffect(.degrees(innerRotation))
                        )
                )
                .scaleEffect(breatheScale)
        }
        .onAppear {
            if isAnimating {
                withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                    outerRotation = 360
                }
                withAnimation(.linear(duration: 6.0).repeatForever(autoreverses: false)) {
                    innerRotation = -360
                }
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    breatheScale = 1.15
                }
            }
        }
    }
}

// MARK: - Generation Flow View

struct GenerationFlowView: View {
    @Binding var progress: Double
    @State private var dots: [MovingDot] = []
    @State private var scanLine: CGFloat = 0
    @State private var glowIntensity: Double = 0.5
    
    var body: some View {
        VStack(spacing: 40) {
            // Progress indicator
            ZStack {
                // Background track
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(hex: "#7289da").opacity(0.3), lineWidth: 2)
                    )
                
                // Progress fill
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#7289da").opacity(0.6),
                                    Color(hex: "#7289da"),
                                    Color(hex: "#8b9dc3")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 56)
                        .overlay(
                            // Animated shimmer
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .clear,
                                            .white.opacity(0.3),
                                            .clear
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .offset(x: scanLine)
                                .mask(
                                    RoundedRectangle(cornerRadius: 18)
                                        .frame(width: geometry.size.width * progress, height: 56)
                                )
                        )
                        .shadow(color: Color(hex: "#7289da").opacity(0.4), radius: 10, x: 0, y: 0)
                }
                .frame(height: 56)
                .padding(2)
                
                // Progress text
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
                         .padding(.horizontal, 24)
             
             // Generation stages
             VStack(spacing: 20) {
                GenerationStage(
                    title: "Scanning satellite data",
                    isActive: progress > 0.1,
                    isCompleted: progress > 0.4
                )
                
                GenerationStage(
                    title: "Analyzing abandoned structures",
                    isActive: progress > 0.4,
                    isCompleted: progress > 0.7
                )
                
                GenerationStage(
                    title: "Generating personalized suggestions",
                    isActive: progress > 0.7,
                    isCompleted: progress > 0.95
                )
            }
                         .padding(.horizontal, 24)
         
         // Animated dots
         MovingDotsView(dots: dots)
             .frame(height: 100)
             .padding(.top, 8)
        }
        .onAppear {
            generateMovingDots()
            startScanAnimation()
        }
    }
    
    private func generateMovingDots() {
        dots = []
        for i in 0..<20 {
            let dot = MovingDot(
                id: i,
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: CGFloat.random(in: 0...100),
                size: CGFloat.random(in: 2...4),
                speed: Double.random(in: 0.5...2.0),
                delay: Double.random(in: 0...1)
            )
            dots.append(dot)
        }
    }
    
    private func startScanAnimation() {
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            scanLine = 200
        }
        
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            glowIntensity = 1.0
        }
    }
}

// MARK: - Generation Stage

struct GenerationStage: View {
    let title: String
    let isActive: Bool
    let isCompleted: Bool
    
    @State private var checkmarkScale: CGFloat = 0
    @State private var spinnerRotation: Double = 0
    
    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(isActive ? Color(hex: "#7289da").opacity(0.2) : Color.white.opacity(0.1))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(
                                isActive ? Color(hex: "#7289da") : Color.white.opacity(0.3),
                                lineWidth: 2
                            )
                    )
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(checkmarkScale)
                        .onAppear {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                checkmarkScale = 1.0
                            }
                        }
                } else if isActive {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#7289da")))
                        .scaleEffect(0.6)
                        .rotationEffect(.degrees(spinnerRotation))
                        .onAppear {
                            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                                spinnerRotation = 360
                            }
                        }
                }
            }
            
            // Title
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isActive ? .white : .white.opacity(0.6))
                .animation(.easeInOut(duration: 0.3), value: isActive)
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? Color(hex: "#7289da").opacity(0.1) : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isActive ? Color(hex: "#7289da").opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.5), value: isActive)
    }
}

// MARK: - Gamified Stats Cards

struct GameifiedStatsView: View {
    let locations: [USALocation]
    let explorerStats: ExplorerStats
    
    var body: some View {
        VStack(spacing: 16) {
            // Treasure Stats Row
            HStack(spacing: 12) {
                TreasureStatCard(
                    icon: "🏆",
                    title: "Found",
                    value: "\(locations.count)",
                    subtitle: "treasures",
                    color: Color(hex: "#7289da"),
                    gradient: LinearGradient(
                        colors: [Color(hex: "#7289da"), Color(hex: "#8b9dc3")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                TreasureStatCard(
                    icon: "💎",
                    title: "Rarity",
                    value: calculateAverageRarity(),
                    subtitle: "avg level",
                    color: .purple,
                    gradient: LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                TreasureStatCard(
                    icon: "🎯",
                    title: "Closest",
                    value: "\(String(format: "%.1f", locations.first?.distanceKm ?? 0))km",
                    subtitle: "away",
                    color: .green,
                    gradient: LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            
            // Daily Challenge Progress
            DailyChallengeCard()
        }
        .padding(.horizontal, 24)
    }
    
    private func calculateAverageRarity() -> String {
        let rarities = locations.map { _ in Int.random(in: 1...5) }
        let average = rarities.reduce(0, +) / max(rarities.count, 1)
        
        switch average {
        case 1: return "⚪"
        case 2: return "🟢" 
        case 3: return "🔵"
        case 4: return "🟣"
        case 5: return "🟠"
        default: return "⚪"
        }
    }
}

struct TreasureStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let gradient: LinearGradient
    
    @State private var bounce: CGFloat = 0
    @State private var shimmer: CGFloat = -100
    
    var body: some View {
        VStack(spacing: 6) {
            // Icon with treasure glow
            Text(icon)
                .font(.system(size: 20))
                .scaleEffect(1.0 + bounce)
                .shadow(color: color.opacity(0.6), radius: 4, x: 0, y: 2)
            
            // Value with shimmer
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .overlay(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.8), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .mask(
                        Text(value)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    )
                    .offset(x: shimmer)
                )
            
            // Title & subtitle
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(gradient, lineWidth: 2)
                        .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
                )
        )
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double.random(in: 0...0.5))) {
                bounce = 0.15
            }
            
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false).delay(1.0)) {
                shimmer = 100
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    bounce = 0
                }
            }
        }
    }
}

struct DailyChallengeCard: View {
    @State private var progressAnimation: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("🎮")
                    .font(.system(size: 18))
                
                Text("Daily Challenge")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("2/5")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.orange)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressAnimation, height: 8)
                        .shadow(color: .orange.opacity(0.6), radius: 4, x: 0, y: 0)
                }
            }
            .frame(height: 8)
            
            Text("Discover 5 locations today for a bonus reward! 🎁")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.orange.opacity(0.6), .yellow.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2)) {
                progressAnimation = 0.4 // 2/5 progress
            }
        }
    }
}

struct StatsCardsView: View {
    let locations: [USALocation]
    
    var body: some View {
        HStack(spacing: 16) {
            ModernStatCard(
                icon: "location.fill",
                title: "Found",
                value: "\(locations.count)",
                color: Color(hex: "#7289da"),
                gradient: LinearGradient(
                    colors: [Color(hex: "#7289da"), Color(hex: "#8b9dc3")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            ModernStatCard(
                icon: "square.grid.3x3.fill",
                title: "Types",
                value: "\(Set(locations.map { $0.categoryName ?? "Other" }).count)",
                color: .orange,
                gradient: LinearGradient(
                    colors: [.orange, .red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            ModernStatCard(
                icon: "arrow.up.right",
                title: "Closest",
                value: "\(String(format: "%.1f", locations.first?.distanceKm ?? 0))km",
                color: .green,
                gradient: LinearGradient(
                    colors: [.green, .mint],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .padding(.horizontal, 24)
    }
}

struct ModernStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let gradient: LinearGradient
    
    @State private var bounce: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 10) {
            // Icon with glow
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(gradient)
                        .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
                )
                .scaleEffect(1.0 + bounce)
            
            // Value
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Title
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(gradient, lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double.random(in: 0...0.5))) {
                bounce = 0.1
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    bounce = 0
                }
            }
        }
    }
}

// MARK: - Treasure Location Grid

struct TreasureLocationGridView: View {
    let locations: [USALocation]
    let onLocationSelect: (USALocation) -> Void
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20)
            ], spacing: 20) {
                ForEach(Array(locations.enumerated()), id: \.element.id) { index, location in
                    TreasureLocationCard(
                        location: location,
                        animationDelay: Double(index) * 0.1
                    ) {
                        onLocationSelect(location)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }
}

struct TreasureLocationCard: View {
    let location: USALocation
    let animationDelay: Double
    let onTap: () -> Void
    
    @State private var cardScale: CGFloat = 0
    @State private var cardOpacity: Double = 0
    @State private var glowIntensity: Double = 0.3
    @State private var treasureGlow: Double = 0
    @State private var sparkleRotation: Double = 0
    @State private var rewardPulse: CGFloat = 1.0
    
    private let rarity: LocationRarity = [.common, .uncommon, .rare, .epic, .legendary].randomElement() ?? .common
    
    var body: some View {
        Button(action: {
            // Haptic feedback for treasure discovery
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            ZStack {
                // Background treasure card
                VStack(alignment: .leading, spacing: 12) {
                    // Rarity header with sparkles
                    HStack {
                        // Rarity badge
                        HStack(spacing: 4) {
                            ForEach(0..<rarity.sparkleCount, id: \.self) { _ in
                                Image(systemName: "sparkle")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(rarity.color)
                                    .rotationEffect(.degrees(sparkleRotation))
                            }
                            
                            Text(rarity.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(rarity.color)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(rarity.color.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .stroke(rarity.color.opacity(0.6), lineWidth: 1)
                                )
                        )
                        
                        Spacer()
                        
                        // Treasure reward
                        Text("💎")
                            .font(.system(size: 16))
                            .scaleEffect(rewardPulse)
                            .shadow(color: rarity.color.opacity(0.8), radius: 4, x: 0, y: 0)
                    }
                    
                    // Treasure location icon
                    HStack {
                        Image(systemName: location.categoryIcon ?? "building.2.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(rarity.color)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(rarity.color.opacity(0.2))
                                    .overlay(
                                        Circle()
                                            .stroke(rarity.color.opacity(0.6), lineWidth: 2)
                                    )
                            )
                        
                        Spacer()
                        
                        // Distance with treasure map styling
                        HStack(spacing: 4) {
                            Text("🗺️")
                                .font(.system(size: 12))
                            
                            Text("\(String(format: "%.1f", location.distanceKm))km")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.orange.opacity(0.8))
                                .overlay(
                                    Capsule()
                                        .stroke(.orange, lineWidth: 1)
                                )
                        )
                    }
                    
                    // Treasure name
                    Text(location.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    // Treasure description
                    Text(location.description)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    // Bottom treasure info
                    HStack {
                        if let buildingType = location.buildingType {
                            HStack(spacing: 4) {
                                Text("🏛️")
                                    .font(.system(size: 10))
                                
                                Text(buildingType.capitalized)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                        }
                        
                        Spacer()
                        
                        // Treasure hunt indicator
                        HStack(spacing: 4) {
                            Text("⚡")
                                .font(.system(size: 12))
                            
                            Text("EXPLORE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            rarity.color.opacity(0.8),
                                            rarity.color.opacity(0.3),
                                            rarity.color.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: rarity.color.opacity(0.4), radius: 15, x: 0, y: 8)
                )
                
                // Floating sparkles for rare items
                if rarity.sparkleCount > 0 {
                    ForEach(0..<rarity.sparkleCount, id: \.self) { index in
                        Image(systemName: "sparkle")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(rarity.color)
                            .offset(
                                x: cos(Double(index) * .pi * 2 / Double(rarity.sparkleCount)) * 70,
                                y: sin(Double(index) * .pi * 2 / Double(rarity.sparkleCount)) * 70
                            )
                            .rotationEffect(.degrees(sparkleRotation))
                            .opacity(treasureGlow)
                    }
                }
                
                // Legendary treasure aura
                if rarity == .legendary {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.orange, .yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .scaleEffect(1.05)
                        .opacity(treasureGlow)
                        .blur(radius: 2)
                }
            }
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(animationDelay)) {
                    cardScale = 1.0
                    cardOpacity = 1.0
                }
                
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(animationDelay)) {
                    treasureGlow = 0.8
                }
                
                withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false).delay(animationDelay)) {
                    sparkleRotation = 360
                }
                
                if rarity == .legendary || rarity == .epic {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(animationDelay)) {
                        rewardPulse = 1.3
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Modern Empty State

struct ModernEmptyStateView: View {
    let onRegenerate: () -> Void
    
    @State private var floatingOffset: CGFloat = 0
    @State private var sparkleRotation: Double = 0
    
    var body: some View {
        VStack(spacing: 32) {
            // Floating icon with sparkles
            ZStack {
                // Sparkle effects
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(Color(hex: "#7289da").opacity(0.6))
                        .frame(width: 4, height: 4)
                        .offset(
                            x: cos(Double(index) * .pi / 4) * 60,
                            y: sin(Double(index) * .pi / 4) * 60
                        )
                        .rotationEffect(.degrees(sparkleRotation))
                        .opacity(0.7)
                }
                
                // Main icon
                Image(systemName: "location.magnifyingglass")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#7289da"), .white, Color(hex: "#7289da")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "#7289da").opacity(0.3), lineWidth: 2)
                            )
                    )
                    .offset(y: floatingOffset)
                    .shadow(color: Color(hex: "#7289da").opacity(0.3), radius: 20, x: 0, y: 10)
            }
            
            // Text content
            VStack(spacing: 16) {
                Text("No Hidden Gems Found")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(hex: "#7289da")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("The AI is still learning about this area.\nTry expanding your search or check back later.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // Regenerate button
            Button(action: onRegenerate) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("Regenerate")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "#7289da"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color(hex: "#7289da").opacity(0.4), radius: 10, x: 0, y: 5)
                )
            }
            .buttonStyle(CardButtonStyle())
        }
        .padding(.horizontal, 32)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                floatingOffset = -10
            }
            
            withAnimation(.linear(duration: 6.0).repeatForever(autoreverses: false)) {
                sparkleRotation = 360
            }
        }
    }
}

// MARK: - Supporting Views and Models

struct AnimatedBackground: View {
    @State private var gradientRotation: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Animated gradient overlay
            LinearGradient(
                colors: [
                    Color(hex: "#7289da").opacity(0.1),
                    Color.black,
                    Color(hex: "#7289da").opacity(0.05),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .rotationEffect(.degrees(gradientRotation))
            .animation(.linear(duration: 20.0).repeatForever(autoreverses: false), value: gradientRotation)
            .onAppear {
                gradientRotation = 360
            }
        }
    }
}

struct NavigationOverlay: View {
    let onDismiss: () -> Void
    let onRefresh: () -> Void
    let isLoading: Bool
    
    var body: some View {
        VStack {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                
                Spacer()
                
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isLoading ? .gray : Color(hex: "#7289da"))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(Color(hex: "#7289da").opacity(0.3), lineWidth: 1)
                                )
                        )
                        .shadow(color: Color(hex: "#7289da").opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            
            Spacer()
        }
    }
}

struct ParticleOverlay: View {
    let particles: [DiscoveryParticle]
    
    var body: some View {
        ZStack {
            ForEach(particles, id: \.id) { particle in
                Circle()
                    .fill(Color(hex: "#7289da").opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
                    .position(x: particle.x, y: particle.y)
                    .animation(.linear(duration: 3.0).repeatForever(autoreverses: false).delay(particle.animationDelay), value: particle.y)
            }
        }
        .allowsHitTesting(false)
    }
}

struct MovingDotsView: View {
    let dots: [MovingDot]
    
    var body: some View {
        ZStack {
            ForEach(dots, id: \.id) { dot in
                Circle()
                    .fill(Color(hex: "#7289da").opacity(0.4))
                    .frame(width: dot.size, height: dot.size)
                    .position(x: dot.x, y: dot.y)
                    .animation(.linear(duration: dot.speed).repeatForever(autoreverses: false).delay(dot.delay), value: dot.x)
            }
        }
    }
}

// MARK: - Achievement Notification System

struct AchievementNotificationView: View {
    let achievement: Achievement?
    @Binding var isShowing: Bool
    
    var body: some View {
        if let achievement = achievement, isShowing {
            VStack {
                HStack {
                    Spacer()
                    
                    // Achievement notification card
                    VStack(spacing: 12) {
                        // Achievement icon with glow
                        Text(achievement.icon)
                            .font(.system(size: 32))
                            .scaleEffect(1.2)
                            .shadow(color: achievement.rarity.color.opacity(0.8), radius: 10, x: 0, y: 0)
                        
                        // Achievement unlocked text
                        Text("🎉 Achievement Unlocked!")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        // Achievement title
                        Text(achievement.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(achievement.rarity.color)
                            .multilineTextAlignment(.center)
                        
                        // Achievement description
                        Text(achievement.description)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [achievement.rarity.color, achievement.rarity.color.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    )
                    .shadow(color: achievement.rarity.color.opacity(0.4), radius: 20, x: 0, y: 10)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 100)
                
                Spacer()
            }
            .transition(.scale.combined(with: .opacity))
            .onAppear {
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        isShowing = false
                    }
                }
            }
        }
    }
}

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}



// MARK: - Data Models

struct DiscoveryParticle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    let animationDelay: Double
}

struct MovingDot: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let speed: Double
    let delay: Double
}

// MARK: - Models

// USALocation model is now defined in APIService.swift

struct USALocationDetailView: View {
    let location: USALocation
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(location.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(location.description)
                            .font(.body)
                            .foregroundColor(.gray)
                        
                        if let address = location.address {
                            Text(address)
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Details
                    VStack(alignment: .leading, spacing: 12) {
                        if let category = location.categoryName {
                            DetailRow(title: "Category", value: category)
                        }
                        
                        if let danger = location.dangerLevel {
                            DetailRow(title: "Safety Level", value: danger)
                        }
                        
                        if let building = location.buildingType {
                            DetailRow(title: "Building Type", value: building)
                        }
                        
                        DetailRow(title: "Distance", value: "\(String(format: "%.1f", location.distanceKm)) km away")
                        
                        DetailRow(title: "Source", value: "OpenStreetMap USA")
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .background(Color.black)
            .navigationBarHidden(true)
            .overlay(
                VStack {
                    HStack {
                        Button("Close") {
                            dismiss()
                        }
                        .foregroundColor(.orange)
                        
                        Spacer()
                    }
                    .padding()
                    
                    Spacer()
                }
            )
        }
        .preferredColorScheme(.dark)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LocationSuggestionView(
        userLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        currentLocationName: "San Francisco, CA"
    )
} 