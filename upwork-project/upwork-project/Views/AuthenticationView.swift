//
//  AuthenticationView.swift
//  upwork-project
//
//  Created by Boris Milev on 22.06.25.
//

import SwiftUI

struct AuthenticationView: View {
    @StateObject private var dataManager = DataManager()
    @State private var currentStep: AuthStep = .welcome
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var age = ""
    @State private var isSignUp = false
    @State private var showError = false
    
    enum AuthStep {
        case welcome
        case auth
        case paywall
        case onboarding
        case complete
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.black, .orange.opacity(0.3), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if dataManager.isAuthenticated {
                MainTabView()
                    .environmentObject(dataManager)
                    .transition(.opacity)
            } else {
                switch currentStep {
                case .welcome:
                    WelcomeScreen(onGetStarted: {
                        withAnimation {
                            currentStep = .auth
                        }
                    })
                    
                case .auth:
                    AuthScreen(
                        email: $email,
                        password: $password,
                        username: $username,
                        age: $age,
                        isSignUp: $isSignUp,
                        isLoading: dataManager.isLoading,
                        errorMessage: dataManager.errorMessage,
                        onAuth: authenticateUser,
                        onToggleMode: { isSignUp.toggle() }
                    )
                    
                case .paywall:
                    PaywallScreen(onSubscribe: {
                        withAnimation {
                            currentStep = .onboarding
                        }
                    })
                    
                case .onboarding:
                    OnboardingScreen(onComplete: {
                        withAnimation {
                            currentStep = .complete
                        }
                    })
                    
                case .complete:
                    MainTabView()
                        .environmentObject(dataManager)
                        .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(dataManager.errorMessage ?? "An unknown error occurred")
        }
        .onChange(of: dataManager.errorMessage) { oldValue, newValue in
            if newValue != nil {
                showError = true
            }
        }
    }
    
    private func authenticateUser() {
        if isSignUp {
            guard let ageInt = Int(age), !username.isEmpty else {
                dataManager.errorMessage = "Please fill in all fields with valid information"
                return
            }
            dataManager.register(username: username, email: email, password: password, age: ageInt)
        } else {
            dataManager.login(email: email, password: password)
        }
    }
}

struct WelcomeScreen: View {
    let onGetStarted: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App Icon and Title
            VStack(spacing: 20) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                
                VStack(spacing: 8) {
                    Text("Abandoned Explorer")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Discover forgotten places")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
            }
            
            // Features
            VStack(spacing: 24) {
                FeatureRow(
                    icon: "map.fill",
                    title: "Explore the Map",
                    subtitle: "Find abandoned places near you"
                )
                
                FeatureRow(
                    icon: "camera.fill",
                    title: "Share Discoveries",
                    subtitle: "Submit locations you've found"
                )
                
                FeatureRow(
                    icon: "heart.fill",
                    title: "Build Community",
                    subtitle: "Connect with fellow explorers"
                )
            }
            
            Spacer()
            
            // Get Started Button
            Button(action: onGetStarted) {
                Text("Get Started")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(16)
            }
            .padding(.horizontal)
            
            Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
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
        }
        .padding(.horizontal)
    }
}

struct AuthScreen: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var username: String
    @Binding var age: String
    @Binding var isSignUp: Bool
    let isLoading: Bool
    let errorMessage: String?
    let onAuth: () -> Void
    let onToggleMode: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text(isSignUp ? "Create Account" : "Welcome Back")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(isSignUp ? "Join the urban exploration community" : "Log in to continue")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 20) {
                if isSignUp {
                    TextField("Username", text: $username)
                        .textFieldStyle(AuthTextFieldStyle())
                        .autocapitalization(.none)
                    
                    TextField("Age", text: $age)
                        .textFieldStyle(AuthTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                TextField("Email", text: $email)
                    .textFieldStyle(AuthTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(AuthTextFieldStyle())
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
            
            Button(action: onAuth) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isLoading ? "Processing..." : (isSignUp ? "Sign Up" : "Log In"))
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .cornerRadius(16)
            }
            .disabled(email.isEmpty || password.isEmpty || (isSignUp && (username.isEmpty || age.isEmpty)) || isLoading)
            
            Button(action: onToggleMode) {
                Text(isSignUp ? "Already have an account? Log In" : "Don't have an account? Sign Up")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
    }
}

struct AuthTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
    }
}

struct PaywallScreen: View {
    let onSubscribe: () -> Void
    @State private var selectedPlan: PricingPlan = .monthly
    
    enum PricingPlan {
        case monthly
        case yearly
    }
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Unlock Full Access")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Get unlimited access to all abandoned locations and premium features")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 20) {
                PremiumFeature(
                    icon: "map.fill",
                    title: "Unlimited Locations",
                    subtitle: "Access thousands of abandoned places"
                )
                
                PremiumFeature(
                    icon: "camera.fill",
                    title: "Upload Photos",
                    subtitle: "Share your discoveries with HD photos"
                )
                
                PremiumFeature(
                    icon: "star.fill",
                    title: "Priority Support",
                    subtitle: "Get your submissions reviewed first"
                )
                
                PremiumFeature(
                    icon: "location.fill",
                    title: "GPS Coordinates",
                    subtitle: "Get exact locations for navigation"
                )
            }
            
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    PricingCard(
                        title: "Monthly",
                        price: "$4.99",
                        subtitle: "per month",
                        isSelected: selectedPlan == .monthly
                    ) {
                        selectedPlan = .monthly
                    }
                    
                    PricingCard(
                        title: "Yearly",
                        price: "$29.99",
                        subtitle: "per year",
                        badge: "Save 50%",
                        isSelected: selectedPlan == .yearly
                    ) {
                        selectedPlan = .yearly
                    }
                }
                
                Button(action: onSubscribe) {
                    Text("Start Free Trial")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(16)
                }
            }
            
            VStack(spacing: 8) {
                Text("7-day free trial, then \(selectedPlan == .monthly ? "$4.99/month" : "$29.99/year")")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("Cancel anytime in Settings")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct PremiumFeature: View {
    let icon: String
    let title: String
    let subtitle: String
    
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
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}

struct PricingCard: View {
    let title: String
    let price: String
    let subtitle: String
    var badge: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let badge = badge {
                    Text(badge)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(price)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.orange.opacity(0.1) : Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.orange : Color.white.opacity(0.2), lineWidth: 2)
            )
        }
    }
}

#Preview {
    AuthenticationView()
}
