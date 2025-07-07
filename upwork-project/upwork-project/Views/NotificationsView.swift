//
//  NotificationsView.swift
//  upwork-project
//
//  Created by Boris Milev on 27.06.25.
//

import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: NotificationFilter = .all
    @State private var animateIn = false
    @State private var filterAnimationOffset: CGFloat = 0
    
    // Navigation state
    @State private var showingLocationDetail = false
    @State private var selectedLocation: AbandonedLocation?
    @State private var scrollToCommentId: Int?
    @State private var isNavigating = false
    
    // App color scheme
    private let accentColor = Color(hex: "#7289da")
    private let cardBackground = Color(white: 0.05)
    private let borderColor = Color(white: 0.1)
    
    enum NotificationFilter: String, CaseIterable {
        case all = "All"
        case unread = "Unread"
        case likes = "Likes"
        case comments = "Comments"
        case submissions = "Submissions"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .unread: return "circle.fill"
            case .likes: return "heart.fill"
            case .comments: return "message.fill"
            case .submissions: return "paperplane.fill"
            }
        }
        
        var gradient: LinearGradient {
            switch self {
            case .all: return LinearGradient(colors: [Color(hex: "#7289da"), Color(hex: "#5865F2")], startPoint: .leading, endPoint: .trailing)
            case .unread: return LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing)
            case .likes: return LinearGradient(colors: [Color.pink, Color.red], startPoint: .leading, endPoint: .trailing)
            case .comments: return LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .leading, endPoint: .trailing)
            case .submissions: return LinearGradient(colors: [Color.green, Color.mint], startPoint: .leading, endPoint: .trailing)
            }
        }
        
        var primaryColor: Color {
            switch self {
            case .all: return Color(hex: "#7289da")
            case .unread: return Color.orange
            case .likes: return Color.pink
            case .comments: return Color.blue
            case .submissions: return Color.green
            }
        }
    }
    
    private var filteredNotifications: [LocationNotification] {
        switch selectedFilter {
        case .all:
            return dataManager.notifications
        case .unread:
            return dataManager.notifications.filter { !$0.isRead }
        case .likes:
            return dataManager.notifications.filter { $0.type == .like }
        case .comments:
            return dataManager.notifications.filter { $0.type == .comment || $0.type == .reply }
        case .submissions:
            return dataManager.notifications.filter { 
                $0.type == .submission || $0.type == .approval || $0.type == .rejection 
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.black, Color(white: 0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notifications")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color(white: 0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        if dataManager.unreadNotificationCount > 0 {
                            Text("\(dataManager.unreadNotificationCount) new")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(accentColor)
                        } else {
                            Text("All caught up")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    // Close button
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dismiss()
                        }
                    }) {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .scaleEffect(animateIn ? 1 : 0.8)
                    .opacity(animateIn ? 1 : 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)
                
                // Filter tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(NotificationFilter.allCases.enumerated()), id: \.element) { index, filter in
                            ModernFilterTab(
                                filter: filter,
                                isSelected: selectedFilter == filter,
                                count: getCountForFilter(filter)
                            ) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedFilter = filter
                                    filterAnimationOffset = CGFloat(index) * 120
                                }
                            }
                            .scaleEffect(animateIn ? 1 : 0.8)
                            .opacity(animateIn ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.1), value: animateIn)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                
                // Mark all read button (only show if there are unread notifications)
                if dataManager.unreadNotificationCount > 0 {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                dataManager.markAllNotificationsAsRead()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Mark All Read")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                
                // Content
                if filteredNotifications.isEmpty {
                    ModernEmptyState(filter: selectedFilter)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeInOut(duration: 0.6).delay(0.3), value: animateIn)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(filteredNotifications.enumerated()), id: \.element.id) { index, notification in
                                ModernNotificationCard(notification: notification) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        handleNotificationTap(notification)
                                    }
                                }
                                .scaleEffect(animateIn ? 1 : 0.8)
                                .opacity(animateIn ? 1 : 0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05), value: animateIn)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                    .clipped()
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showingLocationDetail) {
            if let location = selectedLocation {
                LocationDetailModalView(
                    location: location, 
                    selectedLocation: $selectedLocation
                )
                .onDisappear {
                    // Clear navigation state when modal is dismissed
                    selectedLocation = nil
                    scrollToCommentId = nil
                }
            }
        }
        .onAppear {
            dataManager.loadNotifications()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateIn = true
            }
        }
    }
    
    private func getCountForFilter(_ filter: NotificationFilter) -> Int {
        switch filter {
        case .all:
            return dataManager.notifications.count
        case .unread:
            return dataManager.unreadNotificationCount
        case .likes:
            return dataManager.notifications.filter { $0.type == .like }.count
        case .comments:
            return dataManager.notifications.filter { $0.type == .comment || $0.type == .reply }.count
        case .submissions:
            return dataManager.notifications.filter { 
                $0.type == .submission || $0.type == .approval || $0.type == .rejection 
            }.count
        }
    }
    
    // MARK: - Navigation Functions
    
    private func handleNotificationTap(_ notification: LocationNotification) {
        // Mark as read first
        if !notification.isRead {
            dataManager.markNotificationAsRead(notification.id)
        }
        
        // Handle navigation based on notification type and data
        guard let relatedType = notification.relatedType,
              let relatedId = notification.relatedId else {
            print("⚠️ Notification missing navigation data: \(notification.type.rawValue)")
            return
        }
        
        isNavigating = true
        
        switch notification.type {
        case .like, .bookmark:
            // Navigate to the liked/bookmarked location
            if relatedType == "location" {
                navigateToLocation(locationId: relatedId)
            }
            
        case .comment:
            // Navigate to location and show comments section
            if relatedType == "location" {
                navigateToLocation(locationId: relatedId, scrollToComments: true)
            } else if relatedType == "comment" {
                // Find the location for this comment and navigate there
                fetchLocationForComment(commentId: relatedId)
            }
            
        case .reply:
            // Navigate to location and scroll to specific comment/reply
            if relatedType == "comment" {
                fetchLocationForComment(commentId: relatedId, scrollToComment: true)
            }
            
        case .submission:
            // Navigate to submitted location (if approved) or show submission status
            if relatedType == "location" {
                navigateToLocation(locationId: relatedId)
            }
            
        case .approval, .rejection:
            // Navigate to the approved/rejected location
            if relatedType == "location" {
                navigateToLocation(locationId: relatedId)
            }
            
        case .visit:
            // Navigate to the visited location
            if relatedType == "location" {
                navigateToLocation(locationId: relatedId)
            }
            
        case .groupJoin, .groupLeave, .groupInvite, .groupKick, .groupBan, .groupUnban, .groupMessage, .groupPromotion, .groupDemotion, .groupMemberKick, .groupMemberBan, .groupMemberRoleChange:
            // Group-related notifications - could navigate to group view in the future
            isNavigating = false
            print("ℹ️ Group notification received: \(notification.type.rawValue)")
            
        case .follow, .mention, .system:
            // These might not have direct navigation
            isNavigating = false
            print("ℹ️ No direct navigation for notification type: \(notification.type.rawValue)")
        }
    }
    
    private func navigateToLocation(locationId: Int, scrollToComments: Bool = false, scrollToComment: Bool = false) {
        // First check if location is already in cache
        if let cachedLocation = dataManager.getApprovedLocations().first(where: { $0.id == locationId }) {
            selectedLocation = cachedLocation
            if scrollToComment && scrollToCommentId != nil {
                // Keep the scrollToCommentId for the modal
            }
            showingLocationDetail = true
            isNavigating = false
            return
        }
        
        // Location not in cache, fetch it
        fetchLocationDetails(locationId: locationId, scrollToComments: scrollToComments, scrollToComment: scrollToComment)
    }
    
    private func fetchLocationDetails(locationId: Int, scrollToComments: Bool = false, scrollToComment: Bool = false) {
        Task {
            do {
                // Create a mock location for immediate display while fetching
                // This provides instant feedback to the user
                let mockLocation = AbandonedLocation(
                    id: locationId,
                    title: "Loading...",
                    description: "Loading location details...",
                    latitude: 0.0,
                    longitude: 0.0,
                    address: "Loading...",
                    categoryName: "Other",
                    dangerLevel: "Safe"
                )
                
                await MainActor.run {
                    selectedLocation = mockLocation
                    showingLocationDetail = true
                    isNavigating = false
                }
                
                // Fetch actual location details
                let location = try await fetchLocationById(locationId)
                
                await MainActor.run {
                    selectedLocation = location
                    // showingLocationDetail is already true from mock
                }
                
            } catch {
                await MainActor.run {
                    isNavigating = false
                    print("❌ Failed to fetch location \(locationId): \(error)")
                    // Could show an error alert here
                }
            }
        }
    }
    
    private func fetchLocationForComment(commentId: Int, scrollToComment: Bool = false) {
        if scrollToComment {
            scrollToCommentId = commentId
        }
        
        Task {
            do {
                print("🔍 Fetching location for comment ID: \(commentId)")
                
                // Use the new API to get location by comment ID
                let location = try await dataManager.fetchLocationByCommentId(commentId)
                
                await MainActor.run {
                    selectedLocation = location
                    if scrollToComment && scrollToCommentId != nil {
                        // Keep the scrollToCommentId for the modal
                    }
                    showingLocationDetail = true
                    isNavigating = false
                    print("✅ Successfully navigated to location for comment \(commentId)")
                }
                
            } catch {
                await MainActor.run {
                    isNavigating = false
                    print("❌ Failed to fetch location for comment \(commentId): \(error)")
                    // Could show an error alert here
                }
            }
        }
    }
    
    private func fetchLocationById(_ locationId: Int) async throws -> AbandonedLocation {
        return try await dataManager.fetchLocationDetails(locationId: locationId)
    }
    

}

// MARK: - Modern Filter Tab
struct ModernFilterTab: View {
    let filter: NotificationsView.NotificationFilter
    let isSelected: Bool
    let count: Int
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            HStack(spacing: 8) {
                Image(systemName: filter.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                
                Text(filter.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? .white.opacity(0.3) : Color(hex: "#7289da"))
                        )
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                SwiftUI.Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(filter.gradient)
                            .shadow(color: filter.primaryColor.opacity(0.4), radius: 12, x: 0, y: 6)
                    } else {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                }
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Modern Notification Card
struct ModernNotificationCard: View {
    let notification: LocationNotification
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: notification.createdAt, relativeTo: Date())
    }
    
    private var notificationGradient: LinearGradient {
        let color = notificationTypeColor(notification.type.color)
        return LinearGradient(
            colors: [color, color.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var notificationPrimaryColor: Color {
        return notificationTypeColor(notification.type.color)
    }
    
    private func notificationTypeColor(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "yellow": return .yellow
        case "indigo": return .indigo
        case "gray": return .gray
        default: return .gray
        }
    }
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            HStack(spacing: 16) {
                // Profile picture with gradient border
                ZStack {
                    Circle()
                        .fill(notificationGradient)
                        .frame(width: 58, height: 58)
                        .shadow(color: notificationPrimaryColor.opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    // Profile image placeholder with glassmorphism effect
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 48, height: 48)
                        .overlay(
                            // User's initials placeholder (for now showing icon)
                            Image(systemName: notification.type.icon)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // Title with gradient text
                    Text(notification.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(white: 0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    // Message with subtle opacity
                    Text(notification.message)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    
                    // Bottom row with metadata
                    HStack(spacing: 12) {
                        // Simplified notification type badge
                        Text(notification.type.displayName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(notificationPrimaryColor)
                            .cornerRadius(8)
                        
                        // Time ago
                        Text(timeAgo)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        // Unread indicator
                        if !notification.isRead {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: "#7289da"))
                                    .frame(width: 6, height: 6)
                                Text("New")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: "#7289da"))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#7289da").opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                
                // Navigation indicator
                SwiftUI.Group {
                    if isPressed {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .rotationEffect(.degrees(isPressed ? 8 : 0))
                .scaleEffect(isPressed ? 1.2 : 1.0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .stroke(notification.isRead ? Color.white.opacity(0.1) : Color(hex: "#7289da").opacity(0.4), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .opacity(notification.isRead ? 0.85 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private func hasNavigationData(_ notification: LocationNotification) -> Bool {
        return notification.relatedType != nil && notification.relatedId != nil
    }
}

// MARK: - Modern Empty State
struct ModernEmptyState: View {
    let filter: NotificationsView.NotificationFilter
    
    @State private var animateIcon = false
    @State private var animateText = false
    
    private var emptyStateConfig: (icon: String, title: String, message: String, gradient: LinearGradient) {
        switch filter {
        case .all:
            return (
                "bell",
                "No Notifications Yet",
                "When you receive likes, comments, or updates on your locations, they'll appear here.",
                LinearGradient(colors: [Color(hex: "#7289da"), Color(hex: "#5865F2")], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        case .unread:
            return (
                "bell.slash",
                "All Caught Up!",
                "You've read all your notifications. Great job staying on top of things!",
                LinearGradient(colors: [Color.green, Color.mint], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        case .likes:
            return (
                "heart",
                "No Likes Yet",
                "When people like your locations, you'll see those notifications here.",
                LinearGradient(colors: [Color.pink, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        case .comments:
            return (
                "message",
                "No Comments Yet",
                "Comments and replies on your locations will show up here.",
                LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        case .submissions:
            return (
                "paperplane",
                "No Submissions",
                "Updates about your location submissions and approvals will appear here.",
                LinearGradient(colors: [Color.orange, Color.yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        }
    }
    
    private var emptyStatePrimaryColor: Color {
        switch filter {
        case .all: return Color(hex: "#7289da")
        case .unread: return Color.green
        case .likes: return Color.pink
        case .comments: return Color.blue
        case .submissions: return Color.orange
        }
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Animated icon with gradient background
            ZStack {
                Circle()
                    .fill(emptyStateConfig.gradient)
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateIcon ? 1.1 : 1.0)
                    .shadow(color: emptyStatePrimaryColor.opacity(0.4), radius: 20, x: 0, y: 10)
                
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: emptyStateConfig.icon)
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.white)
                            .scaleEffect(animateIcon ? 1.2 : 1.0)
                    )
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    animateIcon = true
                }
            }
            
            // Text content
            VStack(spacing: 16) {
                Text(emptyStateConfig.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(white: 0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(animateText ? 1 : 0)
                    .offset(y: animateText ? 0 : 20)
                
                Text(emptyStateConfig.message)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                    .opacity(animateText ? 1 : 0)
                    .offset(y: animateText ? 0 : 20)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                    animateText = true
                }
            }
            
            Spacer()
            Spacer()
        }
    }
}



#Preview {
    NotificationsView()
        .environmentObject(DataManager())
        .preferredColorScheme(.dark)
} 

