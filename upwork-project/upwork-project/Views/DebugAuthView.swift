//
//  DebugAuthView.swift
//  upwork-project
//
//  Created by Boris Milev on 23.06.25.
//

import SwiftUI

struct DebugAuthView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var apiService = APIService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Debug Authentication Status")
                .font(.title)
                .fontWeight(.bold)
            
            Group {
                Text("Is Authenticated: \(dataManager.isAuthenticated ? "✅" : "❌")")
                Text("Is Admin: \(dataManager.isAdmin ? "✅" : "❌")")
                Text("Current User: \(dataManager.currentUser?.username ?? "None")")
                Text("Token Available: \(apiService.authToken != nil ? "✅" : "❌")")
                
                if let token = apiService.authToken {
                    Text("Token Preview: \(String(token.prefix(20)))...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Text("Error Message: \(dataManager.errorMessage ?? "None")")
                    .foregroundColor(.red)
            }
            .padding(.leading)
            
            Divider()
            
            VStack(spacing: 12) {
                Button("Test Login") {
                    dataManager.login(email: "test@example.com", password: "password123")
                }
                .buttonStyle(.borderedProminent)
                
                Button("Test Load Current User") {
                    dataManager.loadCurrentUser()
                }
                .buttonStyle(.bordered)
                
                Button("Test Check Admin Status") {
                    dataManager.checkAdminStatus()
                }
                .buttonStyle(.bordered)
                
                Button("Toggle Admin (Debug)") {
                    dataManager.isAdmin.toggle()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
                
                Button("Clear Token") {
                    dataManager.logout()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    DebugAuthView()
        .environmentObject(DataManager())
        .preferredColorScheme(.dark)
}
