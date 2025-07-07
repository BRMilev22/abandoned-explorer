//
//  FeedView.swift
//  upwork-project
//
//  Created by Boris Milev on 22.06.25.
//

import SwiftUI
import CoreLocation

struct FeedView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var selectedLocation: AbandonedLocation?
    @State private var showLocationDetail = false
    @State private var isLocalMode = true // false = worldwide, true = local (50km)
    let onBackToOutpost: (() -> Void)?
    
    init(onBackToOutpost: (() -> Void)? = nil) {
        self.onBackToOutpost = onBackToOutpost
    }
    
    // Helper to validate location data before showing detail
    private func isValidLocationData(_ location: AbandonedLocation) -> Bool {
        return !location.title.isEmpty && location.id > 0
    }
    
    private func preloadFeedImages() {
        // Preload images for first 10 items for smooth scrolling
        let itemsToPreload = Array(filteredLocations.prefix(10))
        let allImageUrls = itemsToPreload.flatMap { $0.displayImages }
        
        if !allImageUrls.isEmpty {
            print("🎯 Preloading \(allImageUrls.count) images for first 10 feed items")
            ImageCache.shared.preloadFeedImages(urls: allImageUrls, highPriority: true)
        }
    }
    
    // Filter locations based on mode
    private var filteredLocations: [AbandonedLocation] {
        let allLocations = dataManager.getApprovedLocations() // Use all approved locations, not just recent
        
        if isLocalMode, let userLocation = locationManager.userLocation {
            // Filter to 50km radius
            let nearbyLocations = allLocations.filter { location in
                let locationCoord = CLLocation(latitude: location.latitude, longitude: location.longitude)
                let userCoord = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                let distance = userCoord.distance(from: locationCoord)
                return distance <= 50000 // 50km in meters
            }
            print("🔍 FeedView: Filtering \(allLocations.count) locations to \(nearbyLocations.count) within 50km of user")
            return nearbyLocations
        } else {
            // Show all worldwide locations sorted by recent
            return allLocations.sorted { $0.submissionDate > $1.submissionDate }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and toggle
            HStack {
                // Back button
                Button(action: {
                    onBackToOutpost?()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Minimalistic toggle
                HStack(spacing: 0) {
                    // Worldwide button
                    Button(action: { isLocalMode = false }) {
                        Text("Worldwide")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isLocalMode ? .gray : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isLocalMode ? Color.clear : Color.white.opacity(0.1))
                            .cornerRadius(16, corners: [.topLeft, .bottomLeft])
                    }
                    
                    // Local button
                    Button(action: { isLocalMode = true }) {
                        Text("Local")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isLocalMode ? .white : .gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isLocalMode ? Color.white.opacity(0.1) : Color.clear)
                            .cornerRadius(16, corners: [.topRight, .bottomRight])
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                
                Spacer()
                
                // Invisible spacer to balance the back button
                Color.clear
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal)
            .padding(.top, 60) // Add more top padding to clear dynamic island
            .padding(.bottom, 8)
            .background(Color.black)
            
            if !dataManager.locations.isEmpty {
                // Debug info
                let _ = print("🔍 FeedView: Total locations: \(dataManager.locations.count)")
                let _ = print("🔍 FeedView: Filtered locations: \(filteredLocations.count)")
                let _ = print("🔍 FeedView: Local mode: \(isLocalMode)")
                let _ = print("🔍 FeedView: User location: \(locationManager.userLocation != nil ? "\(locationManager.userLocation!.latitude), \(locationManager.userLocation!.longitude)" : "nil")")
                
                if !filteredLocations.isEmpty {
                    // Pure feed - using filtered locations
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredLocations) { location in
                                FeedItemView(location: location) {
                                    if isValidLocationData(location) {
                                        selectedLocation = location
                                        showLocationDetail = true
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // No filtered content
                    Spacer()
                    VStack {
                        Image(systemName: "location.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text(isLocalMode ? "No local content found" : "No worldwide content found")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Try switching between Local and Worldwide")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
            } else if dataManager.isLoading {
                // Simple loading
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                Spacer()
            } else {
                // No content
                Spacer()
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No content available")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
        }
        .background(Color.black.ignoresSafeArea())
        .fullScreenCover(isPresented: $showLocationDetail) {
            if let location = selectedLocation, isValidLocationData(location) {
                LocationDetailModalView(location: location, selectedLocation: $selectedLocation)
            }
        }
        .onAppear {
            // Force load data immediately
            print("🔄 FeedView onAppear - requesting location permission and loading data")
            locationManager.requestLocationPermission()
            
            if let userLocation = locationManager.userLocation {
                print("🔄 FeedView onAppear - loading nearby locations for: \(userLocation.latitude), \(userLocation.longitude)")
                // Load nearby locations specifically for the feed
                dataManager.loadNearbyLocations(latitude: userLocation.latitude, longitude: userLocation.longitude)
            } else if dataManager.locations.isEmpty {
                print("🔄 FeedView onAppear - no user location, loading all locations")
                dataManager.loadAllLocations()
            } else {
                print("🔄 FeedView onAppear - locations already loaded: \(dataManager.locations.count)")
            }
            
            // Preload images for first 10 feed items for smooth scrolling
            preloadFeedImages()
        }
        .onChange(of: locationManager.userLocation) { newLocation in
            // When user location becomes available, load nearby locations
            if let userLocation = newLocation {
                print("🔄 FeedView location changed - loading nearby locations")
                dataManager.loadNearbyLocations(latitude: userLocation.latitude, longitude: userLocation.longitude)
            }
            // Preload images when user location changes
            preloadFeedImages()
        }
        .onChange(of: isLocalMode) { newMode in
            // When switching to local mode, ensure we have nearby locations
            if newMode, let userLocation = locationManager.userLocation {
                print("🔄 FeedView switched to local mode - loading nearby locations")
                dataManager.loadNearbyLocations(latitude: userLocation.latitude, longitude: userLocation.longitude)
            }
            // Preload images when switching modes
            preloadFeedImages()
        }
    }
}

struct FeedItemView: View {
    @EnvironmentObject var dataManager: DataManager
    let location: AbandonedLocation
    let onTap: () -> Void
    @State private var currentImageIndex = 0
    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var floatingOffset: CGFloat = 0
    @State private var floatingRotation: Double = 0
    @State private var floatingScale: CGFloat = 1.0
    @State private var floatingHorizontalOffset: CGFloat = 0
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background - media if available, map if no media
                if !location.displayImages.isEmpty {
                    // Show swipeable media when available with fast loading
                    TabView(selection: $currentImageIndex) {
                        ForEach(0..<location.displayImages.count, id: \.self) { index in
                            FeedImageLoader(url: location.displayImages[index])
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .ignoresSafeArea()
                    
                    // Media indicators for multiple images
                    if location.displayImages.count > 1 {
                        VStack {
                            HStack {
                                Spacer()
                                HStack(spacing: 6) {
                                    ForEach(0..<location.displayImages.count, id: \.self) { index in
                                        Circle()
                                            .fill(currentImageIndex == index ? Color.white : Color.white.opacity(0.5))
                                            .frame(width: 8, height: 8)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(16)
                                .padding(.top, 60)
                                .padding(.trailing, 20)
                            }
                            Spacer()
                        }
                    }
                } else {
                    // Show map with icon when no media available
                    MapboxMapView(
                        accessToken: "pk.eyJ1IjoiYm9yaXNtaWxldiIsImEiOiJjbTAycjJrdjMwMDEyMmtvYWJ2b2dpOTcyIn0.Lf_ixYD4lXwL2aKzXEsF4w",
                        styleURI: "mapbox://styles/mapbox/dark-v11",
                        locations: [], // Don't show location markers on background
                        activeUsers: [],
                        userLocation: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                        onLocationTap: { _ in },
                        onZoomChange: { _ in },
                        onMapCenterChange: { _ in }
                    )
                    .disabled(true) // Disable interaction
                    .allowsHitTesting(false)
                    
                    // Center content - show icon like Citizen
                    VStack {
                        Spacer()
                        
                        ZStack {
                            // Golden circle border
                            Circle()
                                .stroke(Color(red: 1.0, green: 0.84, blue: 0.0), lineWidth: 4)
                                .frame(width: 80, height: 80)
                                .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.4), radius: 8, x: 0, y: 4)
                            
                            // Category icon on golden background
                            Circle()
                                .fill(Color(red: 1.0, green: 0.84, blue: 0.0))
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Image(systemName: location.category.icon)
                                        .font(.system(size: 28, weight: .medium))
                                        .foregroundColor(.white)
                                )
                        }
                        
                        Spacer()
                    }
                }
                
                // Bottom overlay with info - more compact like Citizen
                VStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Title - smaller and more compact
                        Text(location.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        // Time and location info - more compact
                        HStack(spacing: 6) {
                            Text(formatTimeAgo(location.submissionDate))
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Text("•")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Text("Lat: \(String(format: "%.13f", location.latitude))")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                            
                            Text("•")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Text(formatDistance())
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        // Description - more compact
                        Text(location.description)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        // Bottom stats - more compact
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                // Share action
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 14))
                                    Text("Share")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.black.opacity(0.8),
                                Color.black.opacity(0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                
                // Fire reaction button positioned above share area
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 8) {
                            // Enhanced Fire emoji button with claymorphic 3D style and floating animation
                            Button(action: {
                                toggleLike()
                            }) {
                                ZStack {
                                    // Claymorphic background with 3D depth
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 1.0, green: 0.3, blue: 0.15).opacity(0.9),
                                                    Color(red: 0.9, green: 0.25, blue: 0.1).opacity(0.8),
                                                    Color(red: 0.8, green: 0.2, blue: 0.05).opacity(0.7)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 52, height: 52)
                                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                                        .shadow(color: Color.red.opacity(0.4), radius: 12, x: 0, y: 6)
                                        .shadow(color: Color.orange.opacity(0.3), radius: 16, x: 0, y: 8)
                                    
                                    // Inner highlight for 3D effect
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.4),
                                                    Color.white.opacity(0.1),
                                                    Color.clear
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 48, height: 48)
                                        .blendMode(.overlay)
                                    
                                    // Inner shadow for depth
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.black.opacity(0.2),
                                                    Color.clear,
                                                    Color.white.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                        .frame(width: 50, height: 50)
                                        .blendMode(.multiply)
                                    
                                    // Fire emoji with enhanced styling
                                    Text("🔥")
                                        .font(.system(size: 24))
                                        .scaleEffect(isLiked ? 1.3 : 1.0)
                                        .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 2)
                                        .shadow(color: .orange.opacity(0.8), radius: 6, x: 0, y: 0)
                                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isLiked)
                                }
                                .scaleEffect((isLiked ? 1.1 : 1.0) * floatingScale)
                                .offset(x: floatingHorizontalOffset, y: floatingOffset)
                                .rotationEffect(.degrees(floatingRotation))
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLiked)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onAppear {
                                // Start continuous floating animation with smooth up/down motion
                                withAnimation(
                                    .easeInOut(duration: 2.5)
                                    .repeatForever(autoreverses: true)
                                ) {
                                    floatingOffset = -8.0
                                }
                                
                                // Add subtle rotation for more natural floating
                                withAnimation(
                                    .easeInOut(duration: 3.0)
                                    .repeatForever(autoreverses: true)
                                ) {
                                    floatingRotation = 3.0
                                }
                                
                                // Add gentle scale pulsing
                                withAnimation(
                                    .easeInOut(duration: 1.8)
                                    .repeatForever(autoreverses: true)
                                ) {
                                    floatingScale = 1.05
                                }
                                
                                // Add subtle horizontal sway for realistic floating
                                withAnimation(
                                    .easeInOut(duration: 3.5)
                                    .repeatForever(autoreverses: true)
                                ) {
                                    floatingHorizontalOffset = 2.0
                                }
                            }
                            
                            // Enhanced like counter with claymorphic styling
                            Text("\(likeCount)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.black.opacity(0.7))
                                        .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
                                        .shadow(color: Color.white.opacity(0.1), radius: 1, x: 0, y: -1)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                )
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 100) // Moved up more to avoid collision with share button
                    }
                }
            }
        }
        .frame(height: UIScreen.main.bounds.height * 0.45) // Much slimmer like Citizen
        .cornerRadius(0)
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // Initialize like count from location data
            likeCount = location.likeCount ?? 0
            // Check if current user has already liked this location
            isLiked = dataManager.hasUserLikedLocation(locationId: location.id)
            print("📊 FeedItem initialized - Location: \(location.title), Likes: \(likeCount), User liked: \(isLiked)")
            
            // Preload images for this location with high priority
            if !location.displayImages.isEmpty {
                ImageCache.shared.preloadFeedImages(urls: location.displayImages, highPriority: true)
            }
        }
    }
    
    // Handle like toggle with database integration
    private func toggleLike() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Update UI immediately for responsive feel
            let wasLiked = isLiked
            isLiked.toggle()
            
            if isLiked {
                likeCount += 1
            } else {
                likeCount = max(0, likeCount - 1)
            }
            
            // Save to database using existing DataManager method
            dataManager.toggleLike(for: location.id)
            
            // The DataManager will handle updating the location model
            // but we maintain local state for immediate UI responsiveness
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 3600 { // Less than 1 hour
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 { // Less than 1 day
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
    
    private func formatDistance() -> String {
        // Mock distance - you'd calculate this based on user location
        return "27.8 mi"
    }
}

#Preview {
    FeedView(onBackToOutpost: {
        print("Back to outpost tapped")
    })
        .environmentObject(DataManager())
}
