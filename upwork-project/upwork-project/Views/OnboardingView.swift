//
//  OnboardingView.swift
//  upwork-project
//
//  Created by Boris Milev on 22.06.25.
//

import SwiftUI

struct OnboardingScreen: View {
    let onComplete: () -> Void
    @State private var currentStep = 0
    @State private var selectedAge: Int = 25
    @State private var selectedPreferences: Set<LocationCategory> = []
    @State private var allowNotifications = true
    @State private var allowLocation = true
    
    private let steps = ["Age", "Preferences", "Permissions", "Ready"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress Indicator
            OnboardingProgressBar(currentStep: currentStep, totalSteps: steps.count)
                .padding()
            
            // Step Content
            TabView(selection: $currentStep) {
                AgeSelectionStep(selectedAge: $selectedAge)
                    .tag(0)
                
                PreferencesStep(selectedPreferences: $selectedPreferences)
                    .tag(1)
                
                PermissionsStep(
                    allowNotifications: $allowNotifications,
                    allowLocation: $allowLocation
                )
                .tag(2)
                
                ReadyStep(onComplete: onComplete)
                    .tag(3)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Navigation
            OnboardingNavigation(
                currentStep: $currentStep,
                totalSteps: steps.count,
                canProceed: canProceedToNextStep(),
                onComplete: onComplete
            )
            .padding()
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
    
    private func canProceedToNextStep() -> Bool {
        switch currentStep {
        case 0: return true // Age is always valid
        case 1: return !selectedPreferences.isEmpty
        case 2: return true // Permissions are optional
        case 3: return true
        default: return false
        }
    }
}

struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.orange : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                    
                    if step < totalSteps - 1 {
                        Rectangle()
                            .fill(step < currentStep ? Color.orange : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
            
            Text("Step \(currentStep + 1) of \(totalSteps)")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct AgeSelectionStep: View {
    @Binding var selectedAge: Int
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 16) {
                Text("How old are you?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("This helps us recommend age-appropriate locations and ensure safety")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 20) {
                Text("\(selectedAge)")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                
                Slider(value: Binding(
                    get: { Double(selectedAge) },
                    set: { selectedAge = Int($0) }
                ), in: 13...65, step: 1)
                .accentColor(.orange)
                .padding(.horizontal, 40)
                
                HStack {
                    Text("13")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("65+")
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 40)
                .font(.caption)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct PreferencesStep: View {
    @Binding var selectedPreferences: Set<LocationCategory>
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Text("What interests you?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Select the types of abandoned places you'd like to explore")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(LocationCategory.allCases, id: \.self) { category in
                    PreferenceCard(
                        category: category,
                        isSelected: selectedPreferences.contains(category)
                    ) {
                        if selectedPreferences.contains(category) {
                            selectedPreferences.remove(category)
                        } else {
                            selectedPreferences.insert(category)
                        }
                    }
                }
            }
            
            if !selectedPreferences.isEmpty {
                Text("Selected: \(selectedPreferences.count) type\(selectedPreferences.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct PreferenceCard: View {
    let category: LocationCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.title)
                    .foregroundColor(isSelected ? .black : .white)
                
                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .black : .white)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.orange : Color.white.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.orange : Color.white.opacity(0.2), lineWidth: 2)
            )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct PermissionsStep: View {
    @Binding var allowNotifications: Bool
    @Binding var allowLocation: Bool
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Text("Enable Permissions")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("These permissions help us provide you with the best experience")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 20) {
                PermissionRow(
                    icon: "location.fill",
                    title: "Location Access",
                    subtitle: "Find abandoned places near you and navigate to them",
                    isEnabled: $allowLocation
                )
                
                PermissionRow(
                    icon: "bell.fill",
                    title: "Push Notifications",
                    subtitle: "Get notified about new locations and community updates",
                    isEnabled: $allowNotifications
                )
            }
            
            VStack(spacing: 8) {
                Text("You can change these settings anytime in the app")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .orange))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

struct ReadyStep: View {
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("You're All Set!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Welcome to the urban exploration community. Start discovering abandoned places around you!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                QuickTip(
                    icon: "map.fill",
                    text: "Explore the map to find locations near you"
                )
                
                QuickTip(
                    icon: "camera.fill",
                    text: "Submit your own discoveries to help others"
                )
                
                QuickTip(
                    icon: "heart.fill",
                    text: "Like and bookmark your favorite places"
                )
            }
            
            Button("Start Exploring") {
                onComplete()
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange)
            .cornerRadius(16)
            
            Spacer()
        }
        .padding()
    }
}

struct QuickTip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

struct OnboardingNavigation: View {
    @Binding var currentStep: Int
    let totalSteps: Int
    let canProceed: Bool
    let onComplete: () -> Void
    
    var body: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .foregroundColor(.gray)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            
            Spacer()
            
            if currentStep < totalSteps - 1 {
                Button("Next") {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .foregroundColor(canProceed ? .black : .gray)
                .padding()
                .background(canProceed ? Color.orange : Color.gray.opacity(0.3))
                .cornerRadius(12)
                .disabled(!canProceed)
            }
        }
    }
}

#Preview {
    OnboardingScreen(onComplete: {})
}
