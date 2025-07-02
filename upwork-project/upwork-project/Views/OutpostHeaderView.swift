import SwiftUI

struct OutpostHeaderView: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var selectedCategory: String
    @Binding var showingSelector: Bool
    @Binding var showingProfile: Bool
    @Binding var showingNotifications: Bool
    let nearbyUserCount: Int
    let isGlobalView: Bool
    let currentLocationName: String
    let geocodingService: GeocodingService
    let currentZoomLevel: Double
    let onRefreshUsers: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Top header with perfectly centered layout
            ZStack {
                // Center - Category selector button (perfectly centered)
                Button(action: {
                    showingSelector = true
                }) {
                    HStack(spacing: 8) {
                        // White diamond symbol
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text(selectedCategory)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                
                // Left and right content overlaid on top
                HStack {
                    // Left side - Profile and notifications
                    HStack(spacing: 12) {
                        // Profile button with online indicator
                        Button(action: {
                            showingProfile = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                    )
                                
                                // Green online indicator
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 10, height: 10)
                                    .offset(x: 10, y: 10)
                            }
                        }
                        
                        // Notifications button with badge
                        Button(action: {
                            showingNotifications = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "bell.fill")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                    )
                                
                                // Red notification badge
                                if dataManager.unreadNotificationCount > 0 {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 18, height: 18)
                                        .overlay(
                                            Text("\(min(dataManager.unreadNotificationCount, 999))")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                        .offset(x: 10, y: -10)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Right side - Search button only
                    Button(action: {
                        // Search action
                    }) {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
            // User count and location indicator (centered)
            VStack(spacing: 4) {
                // Always show active users count
                Button(action: {
                    onRefreshUsers?()
                }) {
                    Text("\(formatUserCount(nearbyUserCount)) users")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(geocodingService.getHeaderLocationText(zoomLevel: currentZoomLevel))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.gray)
            }
            .padding(.top, 16)
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.9), Color.black.opacity(0.7), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func formatUserCount(_ count: Int) -> String {
        if count >= 1000 {
            let thousands = Double(count) / 1000.0
            return String(format: "%.1fK", thousands)
        }
        return String(count)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            OutpostHeaderView(
                selectedCategory: .constant("Outpost"),
                showingSelector: .constant(false),
                showingProfile: .constant(false),
                showingNotifications: .constant(false),
                nearbyUserCount: 42,
                isGlobalView: false,
                currentLocationName: "Sofia, Bulgaria",
                geocodingService: GeocodingService(),
                currentZoomLevel: 15.0,
                onRefreshUsers: {}
            )
            .environmentObject(DataManager())
            
            Spacer()
        }
    }
} 