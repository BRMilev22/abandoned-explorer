//
//  ProfileView.swift
//  upwork-project
//
//  Created by Boris Milev on 22.06.25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showSettings = false
    @State private var showReviewPrompt = false
    @State private var showDebug = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if let user = dataManager.currentUser {
                        // Profile Header
                        ProfileHeader(user: user)
                        
                        // Stats Section
                        StatsSection(user: user)
                        
                        // Quick Actions
                        QuickActionsSection(
                            onReviewApp: { showReviewPrompt = true },
                            onSettings: { showSettings = true }
                        )
                        
                        // My Submissions
                        MySubmissionsSection()
                        
                        // Bookmarked Locations
                        BookmarkedSection()
                    } else {
                        // Not logged in state
                        VStack(spacing: 20) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 80))
                                .foregroundColor(.gray)
                            
                            Text("Please log in to view your profile")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Button("Log In") {
                                dataManager.logout() // This will trigger the auth flow
                            }
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(10)
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Debug button (remove in production)
                    Button("Debug") {
                        showDebug = true
                    }
                    .foregroundColor(.gray)
                    .font(.caption)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if dataManager.currentUser != nil {
                        Button("Settings") {
                            showSettings = true
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showDebug) {
                DebugAuthView()
            }
            .alert("Enjoying the app?", isPresented: $showReviewPrompt) {
                Button("Rate 5 Stars ⭐") {
                    // Open App Store rating
                }
                Button("Maybe Later") { }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Help others discover amazing abandoned places by leaving a review!")
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Always load user data when profile view appears
            if dataManager.isAuthenticated {
                dataManager.loadCurrentUser()
                // Refresh submissions and bookmarks to get latest status
                dataManager.loadUserSubmissions()
                dataManager.loadUserBookmarks()
            }
        }
    }
}

struct ProfileHeader: View {
    let user: User
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Picture
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 100, height: 100)
                
                Text(String(user.username.prefix(2)).uppercased())
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text(user.username)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Member since \(formatDate(user.joinDate))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                VStack(spacing: 4) {
                    if dataManager.isAdmin {
                        HStack {
                            Image(systemName: "shield.fill")
                            Text("Administrator")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(12)
                    }
                    
                    if user.isPremium {
                        HStack {
                            Image(systemName: "crown.fill")
                            Text("Premium Explorer")
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct StatsSection: View {
    @EnvironmentObject var dataManager: DataManager
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Stats")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                ProfileStatCard(
                    title: "Submitted",
                    value: "\(user.submittedLocations ?? 0)",
                    subtitle: "Total Submissions",
                    color: .orange
                )
                
                ProfileStatCard(
                    title: "Approved",
                    value: "\(user.approvedLocations ?? 0)",
                    subtitle: "Approved Places",
                    color: .green
                )
            }
            
            HStack(spacing: 16) {
                ProfileStatCard(
                    title: "Bookmarked",
                    value: "\(user.bookmarkedLocations ?? 0)",
                    subtitle: "Saved Places",
                    color: .blue
                )
                
                ProfileStatCard(
                    title: "Liked",
                    value: "\(user.likedLocations ?? 0)",
                    subtitle: "Liked Places",
                    color: .red
                )
            }
            
            if user.isPremium {
                HStack {
                    Spacer()
                    ProfileStatCard(
                        title: "Premium",
                        value: "Active",
                        subtitle: "Membership",
                        color: .purple
                    )
                    Spacer()
                }
            }
        }
    }
}

struct ProfileStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(white: 0.05))
        .cornerRadius(12)
    }
}

struct QuickActionsSection: View {
    let onReviewApp: () -> Void
    let onSettings: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                ActionRow(
                    icon: "star.fill",
                    title: "Rate the App",
                    subtitle: "Help us grow the community",
                    color: .yellow,
                    action: onReviewApp
                )
                
                ActionRow(
                    icon: "gearshape.fill",
                    title: "Settings",
                    subtitle: "Preferences and account",
                    color: .gray,
                    action: onSettings
                )
                
                ActionRow(
                    icon: "square.and.arrow.up",
                    title: "Share App",
                    subtitle: "Invite friends to explore",
                    color: .blue,
                    action: {}
                )
                
                ActionRow(
                    icon: "questionmark.circle.fill",
                    title: "Help & Support",
                    subtitle: "Get help and report issues",
                    color: .orange,
                    action: {}
                )
            }
        }
    }
}

struct ActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(white: 0.05))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MySubmissionsSection: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("My Submissions")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if !dataManager.userSubmissions.isEmpty {
                    let pendingCount = dataManager.userSubmissions.filter { !$0.isApproved }.count
                    if pendingCount > 0 {
                        Text("\(pendingCount) pending")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }
            
            if dataManager.isLoadingSubmissions {
                ProgressView("Loading submissions...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if dataManager.userSubmissions.isEmpty {
                EmptyStateView(
                    icon: "plus.circle",
                    title: "No submissions yet",
                    subtitle: "Start exploring and submit your first location!"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(dataManager.userSubmissions.prefix(3)) { location in
                        SubmissionRow(location: location)
                    }
                    
                    if dataManager.userSubmissions.count > 3 {
                        Button("View All Submissions") {
                            // Navigate to full list
                        }
                        .foregroundColor(.orange)
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            // Refresh submissions every time the section appears
            if dataManager.isAuthenticated {
                dataManager.loadUserSubmissions()
            }
        }
    }
}

struct SubmissionRow: View {
    let location: AbandonedLocation
    
    var body: some View {
        HStack(spacing: 12) {
            // Show image if available, otherwise show category icon
            if let firstImage = location.displayImages.first {
                CachedAsyncImage(url: firstImage) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                        )
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: location.category.icon)
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(location.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                // Show correct approval status
                Text(location.isApproved ? "Approved" : "Under Review")
                    .font(.caption)
                    .foregroundColor(location.isApproved ? .green : .orange)
                
                Text(formatDate(location.submissionDate))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: location.isApproved ? "checkmark.circle.fill" : "clock")
                .foregroundColor(location.isApproved ? .green : .orange)
        }
        .padding()
        .background(Color(white: 0.05))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct BookmarkedSection: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingLocationDetail: AbandonedLocation?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Bookmarked Places")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(dataManager.userBookmarks.count)")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            
            if dataManager.isLoadingBookmarks {
                ProgressView("Loading bookmarks...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if dataManager.userBookmarks.isEmpty {
                EmptyStateView(
                    icon: "bookmark",
                    title: "No bookmarks yet",
                    subtitle: "Bookmark interesting places to find them later"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(dataManager.userBookmarks.prefix(5)) { location in
                            BookmarkCard(location: location, showingLocationDetail: $showingLocationDetail)
                        }
                    }
                    .padding(.horizontal)
                }
                
                if dataManager.userBookmarks.count > 5 {
                    Button("View All Bookmarks") {
                        // Navigate to full list - could implement a dedicated bookmarks view
                    }
                    .foregroundColor(.blue)
                    .padding(.top, 8)
                }
            }
        }
        .sheet(item: $showingLocationDetail) { location in
            LocationDetailView(location: location)
        }
        .onAppear {
            // Refresh bookmarks every time the section appears
            if dataManager.isAuthenticated {
                dataManager.loadUserBookmarks()
            }
        }
    }
}

struct BookmarkCard: View {
    let location: AbandonedLocation
    @Binding var showingLocationDetail: AbandonedLocation?
    
    var body: some View {
        Button(action: {
            showingLocationDetail = location
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Show image if available, otherwise show category icon
                if let firstImage = location.displayImages.first {
                    CachedAsyncImage(url: firstImage) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                            )
                    }
                    .frame(width: 140, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 140, height: 100)
                        .overlay(
                            VStack {
                                Image(systemName: location.category.icon)
                                    .font(.title)
                                    .foregroundColor(.gray)
                                Text(location.category.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        )
                }
                
                Text(location.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .frame(width: 140, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.gray)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    ProfileView()
        .environmentObject(DataManager())
}
