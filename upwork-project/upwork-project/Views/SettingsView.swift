//
//  SettingsView.swift
//  upwork-project
//
//  Created by Boris Milev on 23.06.25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showLogoutAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Account") {
                    if let user = dataManager.currentUser {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(user.username)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            if user.isPremium {
                                Text("Premium")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Preferences") {
                    HStack {
                        Image(systemName: "bell")
                        Text("Notifications")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Image(systemName: "location")
                        Text("Location Services")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                
                Section("Support") {
                    HStack {
                        Image(systemName: "questionmark.circle")
                        Text("Help & FAQ")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Image(systemName: "envelope")
                        Text("Contact Support")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Image(systemName: "star")
                        Text("Rate App")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                
                Section("Legal") {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Terms of Service")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                
                Section {
                    Button("Log Out") {
                        showLogoutAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
            .alert("Log Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    dataManager.logout()
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SettingsView()
        .environmentObject({
            let mockDataManager = DataManager()
            mockDataManager.currentUser = User(
                id: 1,
                username: "PreviewUser",
                email: "preview@example.com",
                age: 25,
                preferences: ["Hospital", "Factory"],
                isPremium: true,
                submittedLocations: 5,
                approvedLocations: 3,
                bookmarkedLocations: 12,
                likedLocations: 8
            )
            return mockDataManager
        }())
}
