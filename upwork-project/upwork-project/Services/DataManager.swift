//
//  DataManager.swift
//  upwork-project
//
//  Created by Boris Milev on 22.06.25.
//

import Foundation
import Combine
import CoreLocation
import UIKit

// MARK: - CLLocationCoordinate2D Extensions for Distance Calculation
extension CLLocationCoordinate2D {
    func distance(from coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location1.distance(from: location2)
    }
}

class DataManager: ObservableObject {
    @Published var locations: [AbandonedLocation] = []
    
    // Computed property for approved locations
    var approvedLocations: [AbandonedLocation] {
        return locations.filter { $0.isApproved }
    }
    @Published var userBookmarks: [AbandonedLocation] = []
    @Published var userSubmissions: [AbandonedLocation] = []
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var isLoadingSubmissions = false
    @Published var isLoadingBookmarks = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    @Published var submissionSuccess = false
    @Published var isAdmin = false
    @Published var pendingLocations: [AbandonedLocation] = []
    @Published var activeUsersCount: Int = 0
    @Published var activeUsers: [ActiveUser] = []
    @Published var isLoadingActiveUsers = false
    
    // MARK: - Dynamic Data Properties
    @Published var dynamicCategories: [DynamicCategory] = []
    @Published var dynamicDangerLevels: [DynamicDangerLevel] = []
    @Published var dynamicTags: [DynamicTag] = []
    @Published var notifications: [LocationNotification] = []
    @Published var unreadNotificationCount: Int = 0
    @Published var userPreferences: UserPreferences = UserPreferences()
    @Published var locationStats: LocationStats?
    @Published var visitedLocations: [AbandonedLocation] = []
    
    // Loading states for dynamic data
    @Published var isLoadingCategories = false
    @Published var isLoadingDangerLevels = false
    @Published var isLoadingNotifications = false
    @Published var isLoadingPreferences = false
    @Published var isLoadingStats = false
    @Published var isLoadingVisitedLocations = false
    
    // MARK: - Groups Properties
    @Published var userGroups: [Group] = []
    @Published var selectedGroup: Group?
    @Published var groupMembers: [GroupMember] = []
    @Published var groupMessages: [GroupMessage] = []
    @Published var isLoadingGroups = false
    @Published var isLoadingGroupMembers = false
    @Published var isLoadingGroupMessages = false
    @Published var isCreatingGroup = false
    @Published var isJoiningGroup = false
    @Published var isSendingMessage = false
    
    let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Prevent duplicate API calls
    private var isLoadingUser = false
    private var isCheckingAdminStatus = false
    private var isLoadingPendingLocations = false
    
    // MARK: - Smart Caching System
    
    // Regional cache storage
    private var cachedRegions: [String: CachedRegion] = [:]
    private var lastLocationRequest = Date()
    private let locationRequestThreshold: TimeInterval = 5.0 // Increased to 5 seconds minimum
    private var isLoadingLocations = false
    private var currentLoadedRegion: String?
    private var hasLoadedInitialLocations = false
    
    // Zoom-based caching
    private var currentZoomLevel: Double = 14.0
    private var lastSignificantMove = Date.distantPast
    private let significantMoveThreshold: CLLocationDistance = 10000 // 10km
    
    struct CachedRegion {
        let locations: [AbandonedLocation]
        let center: CLLocationCoordinate2D
        let radius: Double
        let zoomLevel: Double
        let timestamp: Date
        let cacheKey: String
        
        var isValid: Bool {
            Date().timeIntervalSince(timestamp) < 300 // 5 minutes cache
        }
    }
    
    init() {
        setupBindings()
        checkAuthenticationStatus()
        // Load global locations immediately on app start for instant visibility
        print("🚀 App startup - loading global locations for immediate display")
        loadAllLocations()
        
        // Load dynamic data
        loadDynamicData()
    }
    
    private func setupBindings() {
        apiService.$authToken
            .map { $0 != nil }
            .sink { [weak self] isAuthenticated in
                DispatchQueue.main.async {
                    print("DataManager: Authentication status changed to: \(isAuthenticated)")
                    self?.isAuthenticated = isAuthenticated
                    if isAuthenticated {
                        // Only check admin status if we haven't already done so
                        if !(self?.isCheckingAdminStatus ?? true) {
                            self?.checkAdminStatus()
                        }
                        // Load initial user data
                        self?.loadInitialUserData()
                        // Load user-specific dynamic data
                        self?.loadNotifications()
                        self?.loadUserPreferences()
                        self?.loadVisitedLocations()
                        self?.loadUserGroups()
                    } else {
                        // Clear user data on logout
                        self?.currentUser = nil
                        self?.isAdmin = false
                        self?.userBookmarks = []
                        self?.userSubmissions = []
                        self?.pendingLocations = []
                        self?.notifications = []
                        self?.unreadNotificationCount = 0
                        self?.userPreferences = UserPreferences()
                        self?.visitedLocations = []
                        self?.userGroups = []
                        self?.selectedGroup = nil
                        self?.groupMembers = []
                        self?.groupMessages = []
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkAuthenticationStatus() {
        print("DataManager: Checking authentication status...")
        if apiService.authToken != nil {
            print("DataManager: Token found, loading current user...")
            loadCurrentUser()
        } else {
            print("DataManager: No token found")
        }
    }
    
    // MARK: - Authentication Methods
    func register(username: String, email: String, password: String, age: Int) {
        isLoading = true
        errorMessage = nil
        
        apiService.register(username: username, email: email, password: password, age: age)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.currentUser = response.user
                    self?.isAuthenticated = true
                    // Check admin status after successful registration
                    if !(self?.isCheckingAdminStatus ?? true) {
                        self?.checkAdminStatus()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func login(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        apiService.login(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.currentUser = response.user
                    self?.isAuthenticated = true
                    // Check admin status after successful login
                    if !(self?.isCheckingAdminStatus ?? true) {
                        self?.checkAdminStatus()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func logout() {
        apiService.logout()
        currentUser = nil
        locations = []
        userBookmarks = []
        userSubmissions = []
        isAuthenticated = false
        isAdmin = false
        pendingLocations = []
        
        // Reset loading states
        isLoadingUser = false
        isLoadingBookmarks = false
        isLoadingSubmissions = false
        isCheckingAdminStatus = false
        isLoadingPendingLocations = false
    }
    
    // MARK: - User Data Methods
    func loadCurrentUser() {
        guard isAuthenticated, !isLoadingUser else { return }
        
        isLoadingUser = true
        print("DataManager: Loading current user...")
        
        apiService.getCurrentUser()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingUser = false
                    if case .failure(let error) = completion {
                        print("DataManager: Failed to load current user: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] user in
                    print("DataManager: Current user loaded successfully")
                    self?.currentUser = user
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Location Methods
    private func preloadImages(for locations: [AbandonedLocation]) {
        let imageUrls = locations.flatMap { $0.displayImages }
        if !imageUrls.isEmpty {
            print("DataManager: Preloading \(imageUrls.count) images...")
            ImageCache.shared.preloadImages(urls: imageUrls)
        }
    }
    
    // MARK: - Smart Regional Loading with Caching
    
    func loadAllLocations() {
        let cacheKey = "global_all"
        
        // Check cache first
        if let cached = cachedRegions[cacheKey], cached.isValid {
            print("📋 Using cached global locations (\(cached.locations.count) items)")
            DispatchQueue.main.async {
                self.locations = cached.locations
                self.isLoading = false
                self.currentLoadedRegion = cacheKey
            }
            return
        }
        
        print("🌍 Loading global locations (cache miss)")
        
        // Skip throttling for very first load
        let now = Date()
        if !hasLoadedInitialLocations {
            print("🚀 First-time load - bypassing throttling for immediate visibility")
        } else {
            guard now.timeIntervalSince(lastLocationRequest) >= locationRequestThreshold else {
                print("⏸️ Throttling global location request - too soon since last call (\(String(format: "%.1f", now.timeIntervalSince(lastLocationRequest)))s ago)")
                return
            }
            
            // Reset loading state if stuck
            if isLoadingLocations && now.timeIntervalSince(lastLocationRequest) > 10.0 {
                print("🔄 Resetting stuck loading state after 10+ seconds")
                isLoadingLocations = false
            }
            
            guard !isLoadingLocations else {
                print("⏸️ Already loading global locations, skipping request")
                return
            }
        }
        
        isLoadingLocations = true
        isLoading = true
        errorMessage = nil
        lastLocationRequest = now
        
        apiService.getAllLocations(userLocation: nil)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    self?.isLoadingLocations = false
                    if case .failure(let error) = completion {
                        self?.handleAPIError(error)
                    }
                },
                receiveValue: { [weak self] response in
                    self?.locations = response.locations
                    self?.hasLoadedInitialLocations = true
                    self?.errorMessage = nil
                    // Cache the result
                    let cachedRegion = CachedRegion(
                        locations: response.locations,
                        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radius: 0,
                        zoomLevel: 0,
                        timestamp: Date(),
                        cacheKey: cacheKey
                    )
                    self?.cachedRegions[cacheKey] = cachedRegion
                    self?.currentLoadedRegion = cacheKey
                    self?.preloadImages(for: response.locations)
                    print("📋 Cached global locations (\(response.locations.count) items)")
                }
            )
            .store(in: &cancellables)
    }
    
    func loadAllLocationsWithBypass() {
        print("🌍 Loading all locations with continental zoom bypass")
        
        let cacheKey = "global_all"
        
        // Check cache first for immediate response
        if let cached = cachedRegions[cacheKey], cached.isValid {
            print("💾 Using cached global locations for continental view (\(cached.locations.count) items)")
            DispatchQueue.main.async {
                self.locations = cached.locations
                self.isLoading = false
                self.currentLoadedRegion = cacheKey
            }
            return
        }
        
        // Force load regardless of throttling for continental zoom
        print("🚀 Force loading all approved locations for continental view...")
        
        isLoadingLocations = true
        isLoading = true
        errorMessage = nil
        lastLocationRequest = Date()
        
        apiService.getAllLocations(userLocation: nil)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    self?.isLoadingLocations = false
                    if case .failure(let error) = completion {
                        self?.handleAPIError(error)
                    }
                },
                receiveValue: { [weak self] response in
                    self?.locations = response.locations
                    self?.hasLoadedInitialLocations = true
                    self?.errorMessage = nil
                    // Cache the result
                    let cachedRegion = CachedRegion(
                        locations: response.locations,
                        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radius: 0,
                        zoomLevel: 0,
                        timestamp: Date(),
                        cacheKey: cacheKey
                    )
                    self?.cachedRegions[cacheKey] = cachedRegion
                    self?.currentLoadedRegion = cacheKey
                    self?.preloadImages(for: response.locations)
                    print("📋 Cached global locations from bypass (\(response.locations.count) items)")
                }
            )
            .store(in: &cancellables)
    }
    
    func loadAllLocationsWithPriority(userLocation: CLLocationCoordinate2D?) {
        print("🌍 Loading all locations with geographic prioritization")
        
        let cacheKey = userLocation != nil ? "prioritized_\(String(format: "%.3f", userLocation!.latitude))_\(String(format: "%.3f", userLocation!.longitude))" : "global_all"
        
        // Check cache first
        if let cached = cachedRegions[cacheKey], cached.isValid {
            print("📋 Using cached prioritized locations (\(cached.locations.count) items)")
            DispatchQueue.main.async {
                self.locations = cached.locations
                self.isLoading = false
                self.currentLoadedRegion = cacheKey
            }
            return
        }
        
        print("🌍 Loading with priority (user location: \(userLocation?.latitude ?? 0), \(userLocation?.longitude ?? 0))")
        
        isLoadingLocations = true
        isLoading = true
        errorMessage = nil
        lastLocationRequest = Date()
        
        apiService.getAllLocations(userLocation: userLocation)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    self?.isLoadingLocations = false
                    if case .failure(let error) = completion {
                        self?.handleAPIError(error)
                    }
                },
                receiveValue: { [weak self] response in
                    self?.locations = response.locations
                    self?.hasLoadedInitialLocations = true
                    self?.errorMessage = nil
                    // Cache the result
                    let cachedRegion = CachedRegion(
                        locations: response.locations,
                        center: userLocation ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radius: 0,
                        zoomLevel: 0,
                        timestamp: Date(),
                        cacheKey: cacheKey
                    )
                    self?.cachedRegions[cacheKey] = cachedRegion
                    self?.currentLoadedRegion = cacheKey
                    self?.preloadImages(for: response.locations)
                    print("📋 Cached prioritized locations (\(response.locations.count) items)")
                }
            )
            .store(in: &cancellables)
    }
    
    func loadNearbyLocations(latitude: Double, longitude: Double, radius: Int = 50) {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let cacheKey = generateCacheKey(center: center, radius: Double(radius), zoom: currentZoomLevel)
        
        // Check if we already have suitable cached data
        if let cached = findCachedRegion(for: center, radius: Double(radius)) {
            print("📋 Using cached nearby locations (\(cached.locations.count) items) for \(cacheKey)")
            DispatchQueue.main.async {
                self.locations = cached.locations
                self.isLoading = false
                self.currentLoadedRegion = cached.cacheKey
            }
            return
        }
        
        // Check if location has moved significantly since last request
        if let lastRegion = currentLoadedRegion,
           let cached = cachedRegions[lastRegion],
           cached.isValid,
           center.distance(from: cached.center) < significantMoveThreshold {
            print("📍 Location hasn't moved significantly (\(center.distance(from: cached.center)/1000)km), keeping current data")
            return
        }
        
        print("📍 Loading nearby locations (lat: \(latitude), lng: \(longitude), radius: \(radius)km)")
        
        // Skip throttling for very first load
        let now = Date()
        if !hasLoadedInitialLocations {
            print("🚀 First-time nearby load - bypassing throttling for immediate visibility")
        } else {
            guard now.timeIntervalSince(lastLocationRequest) >= locationRequestThreshold else {
                print("⏸️ Throttling nearby location request - too soon since last call (\(String(format: "%.1f", now.timeIntervalSince(lastLocationRequest)))s ago)")
                return
            }
            
            // Reset loading state if stuck
            if isLoadingLocations && now.timeIntervalSince(lastLocationRequest) > 10.0 {
                print("🔄 Resetting stuck nearby loading state after 10+ seconds")
                isLoadingLocations = false
            }
            
            guard !isLoadingLocations else {
                print("⏸️ Already loading nearby locations, skipping request")
                return
            }
        }
        
        isLoadingLocations = true
        isLoading = true
        errorMessage = nil
        lastLocationRequest = now
        lastSignificantMove = now
        
        apiService.getNearbyLocations(latitude: latitude, longitude: longitude, radius: radius)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    self?.isLoadingLocations = false
                    if case .failure(let error) = completion {
                        self?.handleAPIError(error)
                    }
                },
                receiveValue: { [weak self] response in
                    self?.locations = response.locations
                    self?.hasLoadedInitialLocations = true
                    self?.errorMessage = nil
                    // Cache the result
                    let cachedRegion = CachedRegion(
                        locations: response.locations,
                        center: center,
                        radius: Double(radius),
                        zoomLevel: self?.currentZoomLevel ?? 14.0,
                        timestamp: Date(),
                        cacheKey: cacheKey
                    )
                    self?.cachedRegions[cacheKey] = cachedRegion
                    self?.currentLoadedRegion = cacheKey
                    self?.preloadImages(for: response.locations)
                    print("📋 Cached nearby locations (\(response.locations.count) items) for \(cacheKey)")
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Caching Helper Methods
    
    private func generateCacheKey(center: CLLocationCoordinate2D, radius: Double, zoom: Double) -> String {
        let lat = String(format: "%.3f", center.latitude)
        let lng = String(format: "%.3f", center.longitude)
        let zoomBucket = Int(zoom / 2) * 2 // Group by zoom level buckets
        return "region_\(lat)_\(lng)_\(Int(radius))km_z\(zoomBucket)"
    }
    
    private func findCachedRegion(for center: CLLocationCoordinate2D, radius: Double) -> CachedRegion? {
        // Find cached region that covers the requested area
        for cached in cachedRegions.values {
            guard cached.isValid else { continue }
            
            let distance = center.distance(from: cached.center)
            let radiusDiff = abs(cached.radius - radius)
            
            // Check if cached region covers this request with some overlap
            if distance <= cached.radius * 0.7 && radiusDiff <= cached.radius * 0.3 {
                return cached
            }
        }
        return nil
    }
    
    private func handleAPIError(_ error: Error) {
        if error.localizedDescription.contains("429") {
            self.errorMessage = "Too many requests. Please wait a moment and try again."
            print("🚫 Rate limited - backing off for 10 seconds")
            // Automatically retry after a longer delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                self.errorMessage = nil
            }
        } else {
            self.errorMessage = error.localizedDescription
            print("❌ API Error: \(error.localizedDescription)")
        }
    }
    
    func updateZoomLevel(_ zoomLevel: Double) {
        currentZoomLevel = zoomLevel
    }
    
    func clearCache() {
        cachedRegions.removeAll()
        currentLoadedRegion = nil
        print("🗑️ Cache cleared")
    }
    
    // MARK: - Zoom-Based Regional Loading
    
    func loadLocationsForZoomLevel(_ zoomLevel: Double, center: CLLocationCoordinate2D) {
        currentZoomLevel = zoomLevel
        
        // Determine appropriate radius and loading strategy based on zoom level
        let (radius, shouldLoadGlobal) = getRadiusForZoomLevel(zoomLevel)
        
        if shouldLoadGlobal {
            print("🌍 Zoom level \(zoomLevel) - loading global data")
            loadAllLocations()
        } else {
            print("📍 Zoom level \(zoomLevel) - loading regional data (radius: \(radius)km)")
            loadNearbyLocations(latitude: center.latitude, longitude: center.longitude, radius: radius)
        }
    }
    
    private func getRadiusForZoomLevel(_ zoomLevel: Double) -> (radius: Int, shouldLoadGlobal: Bool) {
        switch zoomLevel {
        case 16.0...: // Street level - very local
            return (radius: 5, shouldLoadGlobal: false)
        case 14.0..<16.0: // Neighborhood level
            return (radius: 15, shouldLoadGlobal: false)
        case 12.0..<14.0: // City level
            return (radius: 50, shouldLoadGlobal: false)
        case 10.0..<12.0: // State/Region level
            return (radius: 200, shouldLoadGlobal: false)
        case 8.0..<10.0: // Country level
            return (radius: 500, shouldLoadGlobal: false)
        default: // Continental/Worldwide level
            return (radius: 0, shouldLoadGlobal: true)
        }
    }
    
    func submitLocation(
        title: String,
        description: String,
        latitude: Double,
        longitude: Double,
        address: String,
        category: LocationCategory,
        dangerLevel: DangerLevel,
        tags: [String],
        images: [UIImage] = [],
        videos: [URL] = []
    ) {
        guard isAuthenticated else {
            errorMessage = "You must be logged in to submit locations"
            return
        }
        
        isLoading = true
        errorMessage = nil
        submissionSuccess = false
        
        let submission = LocationSubmission(
            title: title,
            description: description,
            latitude: latitude,
            longitude: longitude,
            address: address,
            categoryId: category.id,
            dangerLevelId: dangerLevel.id,
            tags: tags
        )
        
        apiService.submitLocation(submission)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.isLoading = false
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    print("DataManager: Location submitted successfully with ID: \(response.locationId)")
                    
                    let hasImages = !images.isEmpty
                    let hasVideos = !videos.isEmpty
                    
                    // If we have both images and videos, upload images first then videos
                    if hasImages && hasVideos {
                        self?.uploadImagesAndVideos(for: response.locationId, images: images, videos: videos)
                    } else if hasImages {
                        self?.uploadImages(for: response.locationId, images: images)
                    } else if hasVideos {
                        self?.uploadVideos(for: response.locationId, videos: videos)
                    } else {
                        // No media to upload, we're done
                        self?.isLoading = false
                        self?.submissionSuccess = true
                        // Refresh locations to include the new submission
                        self?.loadAllLocations()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func toggleBookmark(for locationId: Int) {
        guard isAuthenticated else {
            errorMessage = "You must be logged in to bookmark locations"
            return
        }
        
        apiService.toggleBookmark(locationId: locationId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("❌ DataManager: Failed to toggle bookmark: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    print("✅ DataManager: Bookmark toggled successfully: \(response.isBookmarked)")
                    // Update the local location data
                    if let index = self?.locations.firstIndex(where: { $0.id == locationId }) {
                        self?.locations[index].isBookmarked = response.isBookmarked
                        // Note: we don't have bookmarkCount in ToggleBookmarkResponse, 
                        // so we'll increment/decrement locally
                        if response.isBookmarked {
                            self?.locations[index].bookmarkCount += 1
                        } else {
                            self?.locations[index].bookmarkCount = max(0, self?.locations[index].bookmarkCount ?? 1 - 1)
                        }
                    }
                    
                    // If bookmark was removed, remove from user bookmarks
                    if !response.isBookmarked {
                        self?.userBookmarks.removeAll { $0.id == locationId }
                    } else {
                        // If bookmark was added, refresh bookmarks to get the latest data
                        self?.loadUserBookmarks()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func toggleLike(for locationId: Int) {
        guard isAuthenticated else {
            errorMessage = "You must be logged in to like locations"
            return
        }
        
        apiService.toggleLike(locationId: locationId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("❌ DataManager: Failed to toggle like: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    print("✅ DataManager: Like toggled successfully: \(response.isLiked)")
                    // Update the local location data
                    if let index = self?.locations.firstIndex(where: { $0.id == locationId }) {
                        self?.locations[index].isLiked = response.isLiked
                        // Note: we don't have likeCount in ToggleLikeResponse, 
                        // so we'll increment/decrement locally
                        if response.isLiked {
                            self?.locations[index].likeCount += 1
                        } else {
                            self?.locations[index].likeCount = max(0, self?.locations[index].likeCount ?? 1 - 1)
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func loadUserBookmarks() {
        guard isAuthenticated, !isLoadingBookmarks else { return }
        
        isLoadingBookmarks = true
        print("DataManager: Loading user bookmarks...")
        
        apiService.getUserBookmarks()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingBookmarks = false
                    if case .failure(let error) = completion {
                        print("DataManager: Failed to load bookmarks: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    print("DataManager: Bookmarks loaded successfully: \(response.locations.count) items")
                    self?.userBookmarks = response.locations
                    // Preload images for bookmarks
                    self?.preloadImages(for: response.locations)
                }
            )
            .store(in: &cancellables)
    }
    
    func loadUserSubmissions() {
        guard isAuthenticated, !isLoadingSubmissions else { return }
        
        isLoadingSubmissions = true
        print("DataManager: Loading user submissions...")
        
        apiService.getUserSubmissions()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingSubmissions = false
                    if case .failure(let error) = completion {
                        print("DataManager: Failed to load submissions: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    print("DataManager: Submissions loaded successfully: \(response.locations.count) items")
                    self?.userSubmissions = response.locations
                    // Preload images for submissions
                    self?.preloadImages(for: response.locations)
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Admin Methods
    func checkAdminStatus() {
        guard isAuthenticated, !isCheckingAdminStatus else { 
            print("DataManager: Cannot check admin status - not authenticated or already checking")
            return 
        }
        
        isCheckingAdminStatus = true
        print("DataManager: Checking admin status...")
        
        apiService.checkAdminStatus()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isCheckingAdminStatus = false
                    if case .failure(let error) = completion {
                        print("DataManager: Failed to check admin status: \(error.localizedDescription)")
                        self?.isAdmin = false
                    }
                },
                receiveValue: { [weak self] response in
                    print("DataManager: Admin status received: \(response.isAdmin)")
                    self?.isAdmin = response.isAdmin
                }
            )
            .store(in: &cancellables)
    }
    
    func loadPendingLocations() {
        guard isAuthenticated && isAdmin, !isLoadingPendingLocations else {
            if !isAuthenticated || !isAdmin {
                errorMessage = "Admin access required"
            }
            return
        }
        
        isLoadingPendingLocations = true
        isLoading = true
        errorMessage = nil
        print("DataManager: Loading pending locations...")
        
        apiService.getPendingLocations()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingPendingLocations = false
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        print("DataManager: Failed to load pending locations: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    print("DataManager: Pending locations loaded successfully: \(response.locations.count) items")
                    self?.pendingLocations = response.locations
                }
            )
            .store(in: &cancellables)
    }
    
    func approveLocation(_ locationId: Int) {
        guard isAuthenticated && isAdmin else {
            errorMessage = "Admin access required"
            return
        }
        
        apiService.approveLocation(locationId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    // Remove from pending locations
                    self?.pendingLocations.removeAll { $0.id == locationId }
                    // Refresh all locations to show the approved location
                    self?.loadAllLocations()
                    // Send notification for real-time updates
                    NotificationCenter.default.post(name: NSNotification.Name("LocationApproved"), object: locationId)
                }
            )
            .store(in: &cancellables)
    }
    
    func rejectLocation(_ locationId: Int) {
        guard isAuthenticated && isAdmin else {
            errorMessage = "Admin access required"
            return
        }
        
        apiService.rejectLocation(locationId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    // Remove from pending locations
                    self?.pendingLocations.removeAll { $0.id == locationId }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Initial Data Loading
    func loadInitialUserData() {
        guard isAuthenticated else { return }
        
        // Load general locations data first
        if locations.isEmpty {
            loadAllLocations()
        }
        
        // Load user profile if we don't have it
        if currentUser == nil {
            loadCurrentUser()
        }
        
        // Load user-specific data
        if userBookmarks.isEmpty {
            loadUserBookmarks()
        }
        
        if userSubmissions.isEmpty {
            loadUserSubmissions()
        }
        
        // Load admin data if user is admin
        if isAdmin && pendingLocations.isEmpty {
            loadPendingLocations()
        }
    }
    
    // MARK: - Computed Properties
    func getApprovedLocations() -> [AbandonedLocation] {
        return locations.filter { $0.isApproved }
    }
    
    func getRecentLocations() -> [AbandonedLocation] {
        return locations.filter { $0.isApproved }
            .sorted { $0.submissionDate > $1.submissionDate }
    }
    
    func uploadImages(for locationId: Int, images: [UIImage]) {
        guard isAuthenticated else {
            errorMessage = "You must be logged in to upload images"
            return
        }
        
        guard !images.isEmpty else {
            errorMessage = "No images to upload"
            return
        }
        
        // If this is called from submitLocation, don't set isLoading again
        let wasLoadingBefore = isLoading
        if !wasLoadingBefore {
            isLoading = true
        }
        errorMessage = nil
        
        apiService.uploadImages(for: locationId, images: images)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if !wasLoadingBefore {
                        self?.isLoading = false
                    }
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        if wasLoadingBefore {
                            // If we were called from submitLocation, we need to end the loading state
                            self?.isLoading = false
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    print("DataManager: Images uploaded successfully: \(response.totalUploaded) images")
                    
                    if wasLoadingBefore {
                        // This was called from submitLocation, so complete the submission
                        self?.isLoading = false
                        self?.submissionSuccess = true
                    }
                    
                    // Refresh locations to show updated images
                    self?.loadAllLocations()
                }
            )
            .store(in: &cancellables)
    }
    
    func uploadVideos(for locationId: Int, videos: [URL]) {
        guard isAuthenticated else {
            errorMessage = "You must be logged in to upload videos"
            return
        }
        
        guard !videos.isEmpty else {
            errorMessage = "No videos to upload"
            return
        }
        
        // If this is called from submitLocation, don't set isLoading again
        let wasLoadingBefore = isLoading
        if !wasLoadingBefore {
            isLoading = true
        }
        errorMessage = nil
        
        apiService.uploadVideos(for: locationId, videos: videos)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if !wasLoadingBefore {
                        self?.isLoading = false
                    }
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        if wasLoadingBefore {
                            // If we were called from submitLocation, we need to end the loading state
                            self?.isLoading = false
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    print("DataManager: Videos uploaded successfully: \(response.totalUploaded) videos")
                    
                    if wasLoadingBefore {
                        // This was called from submitLocation, so complete the submission
                        self?.isLoading = false
                        self?.submissionSuccess = true
                    }
                    
                    // Refresh locations to show updated media
                    self?.loadAllLocations()
                }
            )
            .store(in: &cancellables)
    }
    
    func uploadImagesAndVideos(for locationId: Int, images: [UIImage], videos: [URL]) {
        guard isAuthenticated else {
            errorMessage = "You must be logged in to upload media"
            return
        }
        
        guard !images.isEmpty || !videos.isEmpty else {
            errorMessage = "No media to upload"
            return
        }
        
        // Track upload completion
        var uploadsCompleted = 0
        let totalUploads = (images.isEmpty ? 0 : 1) + (videos.isEmpty ? 0 : 1)
        
        func checkCompletion() {
            uploadsCompleted += 1
            if uploadsCompleted == totalUploads {
                self.isLoading = false
                self.submissionSuccess = true
                self.loadAllLocations()
            }
        }
        
        errorMessage = nil
        
        // Upload images first
        if !images.isEmpty {
            apiService.uploadImages(for: locationId, images: images)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            self?.errorMessage = error.localizedDescription
                            self?.isLoading = false
                        }
                    },
                    receiveValue: { [weak self] response in
                        print("DataManager: Images uploaded successfully: \(response.totalUploaded) images")
                        checkCompletion()
                    }
                )
                .store(in: &cancellables)
        }
        
        // Upload videos
        if !videos.isEmpty {
            apiService.uploadVideos(for: locationId, videos: videos)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            self?.errorMessage = error.localizedDescription
                            self?.isLoading = false
                        }
                    },
                    receiveValue: { [weak self] response in
                        print("DataManager: Videos uploaded successfully: \(response.totalUploaded) videos")
                        checkCompletion()
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Active Users Management
    
    func loadActiveUsers(latitude: Double, longitude: Double, radius: Double = 50.0) {
        // Prevent duplicate requests
        guard !isLoadingActiveUsers else {
            print("⏸️ Already loading active users, skipping request")
            return
        }
        
        isLoadingActiveUsers = true
        print("👥 Loading active users near: \(latitude), \(longitude) within \(radius)km")
        
        apiService.getActiveUsers(latitude: latitude, longitude: longitude, radius: radius)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingActiveUsers = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to load active users: \(error)")
                        self?.errorMessage = "Failed to load active users"
                    }
                },
                receiveValue: { [weak self] response in
                    print("👥 Active users loaded: \(response.totalCount) users")
                    self?.activeUsersCount = response.totalCount
                    
                    // Store the actual active users data for map visualization
                    self?.activeUsers = response.users
                    print("👥 Stored \(response.users.count) active users for map visualization")
                    
                    self?.isLoadingActiveUsers = false
                }
            )
            .store(in: &cancellables)
    }
    
    func updateUserLocation(latitude: Double, longitude: Double, locationName: String? = nil) {
        print("📍 Updating user location: \(latitude), \(longitude)")
        
        apiService.updateUserLocation(latitude: latitude, longitude: longitude, locationName: locationName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to update user location: \(error)")
                    }
                },
                receiveValue: { response in
                    print("📍 User location updated successfully")
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Dynamic Data Loading Methods
    
    func loadDynamicData() {
        print("📦 Loading dynamic data...")
        // Temporarily disable problematic API calls that are causing decoding errors
        // loadCategories()
        loadDangerLevels()
        loadTags()
        // loadLocationStats()
        
        print("⚠️ Categories and stats loading disabled to prevent API errors")
    }
    
    func loadCategories() {
        guard !isLoadingCategories else { return }
        
        isLoadingCategories = true
        print("📂 Loading categories...")
        
        apiService.getCategories()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingCategories = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to load categories: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] categories in
                    print("✅ Categories loaded: \(categories.count) items")
                    self?.dynamicCategories = categories
                }
            )
            .store(in: &cancellables)
    }
    
    func loadDangerLevels() {
        guard !isLoadingDangerLevels else { return }
        
        isLoadingDangerLevels = true
        print("⚠️ Loading danger levels...")
        
        apiService.getDangerLevels()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingDangerLevels = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to load danger levels: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] dangerLevels in
                    print("✅ Danger levels loaded: \(dangerLevels.count) items")
                    self?.dynamicDangerLevels = dangerLevels
                }
            )
            .store(in: &cancellables)
    }
    
    func loadTags() {
        apiService.getTags(popular: false, limit: 100)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to load tags: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] tags in
                    print("🏷️ Tags loaded: \(tags.count) items")
                    self?.dynamicTags = tags
                }
            )
            .store(in: &cancellables)
    }
    
    func loadLocationStats() {
        guard !isLoadingStats else { return }
        
        isLoadingStats = true
        print("📊 Loading location stats...")
        
        apiService.getLocationStats()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingStats = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to load location stats: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] stats in
                    print("✅ Location stats loaded")
                    self?.locationStats = stats
                }
            )
            .store(in: &cancellables)
    }
    
    func loadNotifications() {
        guard isAuthenticated, !isLoadingNotifications else { return }
        
        isLoadingNotifications = true
        print("🔔 Loading notifications...")
        
        apiService.getNotifications()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingNotifications = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to load notifications: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] response in
                    print("✅ Notifications loaded: \(response.notifications.count) items, \(response.unreadCount) unread")
                    self?.notifications = response.notifications
                    self?.unreadNotificationCount = response.unreadCount
                }
            )
            .store(in: &cancellables)
    }
    
    func loadUserPreferences() {
        guard isAuthenticated, !isLoadingPreferences else { return }
        
        isLoadingPreferences = true
        print("⚙️ Loading user preferences...")
        
        apiService.getUserPreferences()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingPreferences = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to load preferences: \(error.localizedDescription)")
                        // Use default preferences on error
                        self?.userPreferences = UserPreferences()
                    }
                },
                receiveValue: { [weak self] preferences in
                    print("✅ User preferences loaded")
                    self?.userPreferences = preferences
                }
            )
            .store(in: &cancellables)
    }
    
    func updateUserPreferences(_ preferences: UserPreferences) {
        guard isAuthenticated else { return }
        
        apiService.updateUserPreferences(preferences)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to update preferences: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    print("✅ User preferences updated")
                    self?.userPreferences = preferences
                }
            )
            .store(in: &cancellables)
    }
    
    func loadVisitedLocations() {
        guard isAuthenticated, !isLoadingVisitedLocations else { return }
        
        isLoadingVisitedLocations = true
        print("👣 Loading visited locations...")
        
        apiService.getVisitedLocations()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingVisitedLocations = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to load visited locations: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] response in
                    print("✅ Visited locations loaded: \(response.visitedLocations.count) items")
                    self?.visitedLocations = response.visitedLocations
                }
            )
            .store(in: &cancellables)
    }
    
    func fetchLocationDetails(locationId: Int) async throws -> AbandonedLocation {
        print("🔍 Fetching location details for ID: \(locationId)")
        
        // First check if location is in cache
        if let cachedLocation = getApprovedLocations().first(where: { $0.id == locationId }) {
            print("✅ Found location in cache: \(cachedLocation.title)")
            return cachedLocation
        }
        
        // Also check pending locations for admin users
        if currentUser?.id == 1 { // Admin user
            if let pendingLocation = pendingLocations.first(where: { $0.id == locationId }) {
                print("✅ Found pending location: \(pendingLocation.title)")
                return pendingLocation
            }
        }
        
        // If not in cache, fetch from API
        print("📡 Location not in cache, fetching from API...")
        
        return try await withCheckedThrowingContinuation { continuation in
            apiService.getLocationByIdFromAPI(locationId)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("❌ Failed to fetch location \(locationId): \(error)")
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { response in
                        print("✅ Successfully fetched location from API: \(response.location.title)")
                        
                        // Convert LocationDetails to AbandonedLocation
                        let abandonedLocation = AbandonedLocation(
                            id: response.location.id,
                            title: response.location.title,
                            description: response.location.description ?? "",
                            latitude: response.location.latitude,
                            longitude: response.location.longitude,
                            address: response.location.address ?? "",
                            tags: response.location.tags,
                            images: response.location.images.map { $0.imageUrl },
                            videos: response.location.videos.map { $0.videoUrl },
                            submittedBy: nil,
                            submittedByUsername: response.location.submittedByUsername,
                            submissionDate: self.parseSubmissionDate(response.location.submissionDate),
                            likeCount: response.location.likesCount,
                            bookmarkCount: response.location.bookmarksCount,
                            isBookmarked: response.location.userInteractions.isBookmarked,
                            isLiked: response.location.userInteractions.isLiked,
                            isApproved: true,
                            categoryName: response.location.categoryName ?? "",
                            dangerLevel: response.location.dangerLevel ?? ""
                        )
                        
                        // Add to cache for future use
                        DispatchQueue.main.async {
                            self.locations.append(abandonedLocation)
                        }
                        
                        continuation.resume(returning: abandonedLocation)
                    }
                )
                .store(in: &self.cancellables)
        }
    }
    
    private func parseSubmissionDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: dateString) ?? Date()
    }
    
    func fetchLocationByCommentId(_ commentId: Int) async throws -> AbandonedLocation {
        print("🔍 Fetching location for comment ID: \(commentId)")
        
        return try await withCheckedThrowingContinuation { continuation in
            apiService.getLocationByCommentId(commentId)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("❌ Failed to fetch location by comment \(commentId): \(error)")
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { response in
                        print("✅ Successfully fetched location by comment: \(response.location.title)")
                        
                        // Add to cache for future use if not already present
                        DispatchQueue.main.async {
                            if !self.locations.contains(where: { $0.id == response.location.id }) {
                                self.locations.append(response.location)
                            }
                        }
                        
                        continuation.resume(returning: response.location)
                    }
                )
                .store(in: &self.cancellables)
        }
    }
    
    func trackLocationVisit(_ locationId: Int) {
        apiService.trackLocationVisit(locationId: locationId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to track location visit: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] (response: VisitResponse) in
                    print("✅ Location visit tracked: \(response.message)")
                    // Update view count in local data
                    if let index = self?.locations.firstIndex(where: { $0.id == locationId }) {
                        self?.locations[index] = AbandonedLocation(
                            id: self?.locations[index].id ?? locationId,
                            title: self?.locations[index].title ?? "",
                            description: self?.locations[index].description ?? "",
                            latitude: self?.locations[index].latitude ?? 0.0,
                            longitude: self?.locations[index].longitude ?? 0.0,
                            address: self?.locations[index].address ?? "",
                            tags: self?.locations[index].tags ?? [],
                            images: self?.locations[index].images ?? [],
                            submittedBy: self?.locations[index].submittedBy,
                            submittedByUsername: self?.locations[index].submittedByUsername,
                            submissionDate: self?.locations[index].submissionDate ?? Date(),
                            likeCount: self?.locations[index].likeCount ?? 0,
                            bookmarkCount: self?.locations[index].bookmarkCount ?? 0,
                            isBookmarked: self?.locations[index].isBookmarked ?? false,
                            isLiked: self?.locations[index].isLiked ?? false,
                            isApproved: self?.locations[index].isApproved ?? false,
                            categoryName: self?.locations[index].categoryName ?? "",
                            dangerLevel: self?.locations[index].dangerLevel ?? ""
                        )
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func markNotificationAsRead(_ notificationId: Int) {
        apiService.markNotificationAsRead(notificationId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to mark notification as read: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] response in
                    print("✅ Notification marked as read")
                    // Update local notification
                    if let index = self?.notifications.firstIndex(where: { $0.id == notificationId }) {
                        // Create updated notification
                        let notification = self?.notifications[index]
                        if let notification = notification {
                            let updatedNotification = LocationNotification(
                                id: notification.id,
                                title: notification.title,
                                message: notification.message,
                                type: notification.type,
                                relatedType: notification.relatedType,
                                relatedId: notification.relatedId,
                                isRead: true,
                                createdAt: notification.createdAt
                            )
                            self?.notifications[index] = updatedNotification
                        }
                    }
                    // Update unread count
                    self?.unreadNotificationCount = max(0, (self?.unreadNotificationCount ?? 0) - 1)
                }
            )
            .store(in: &cancellables)
    }
    
    func markAllNotificationsAsRead() {
        // Mark all local notifications as read
        for i in 0..<notifications.count {
            if !notifications[i].isRead {
                let notification = notifications[i]
                let updatedNotification = LocationNotification(
                    id: notification.id,
                    title: notification.title,
                    message: notification.message,
                    type: notification.type,
                    relatedType: notification.relatedType,
                    relatedId: notification.relatedId,
                    isRead: true,
                    createdAt: notification.createdAt
                )
                notifications[i] = updatedNotification
            }
        }
        
        // Reset unread count
        unreadNotificationCount = 0
        
        // Call API to mark all as read
        apiService.markAllNotificationsAsRead()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to mark all notifications as read: \(error.localizedDescription)")
                    }
                },
                receiveValue: { response in
                    print("✅ All notifications marked as read")
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Groups Management
    
    func loadUserGroups() {
        guard isAuthenticated, !isLoadingGroups else { return }
        
        isLoadingGroups = true
        print("👥 Loading user groups...")
        
        apiService.getUserGroups()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingGroups = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to load user groups: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    print("✅ User groups loaded: \(response.groups.count) groups")
                    self?.userGroups = response.groups
                }
            )
            .store(in: &cancellables)
    }
    
    func createGroup(name: String, description: String?, isPrivate: Bool, memberLimit: Int, avatarColor: String, emoji: String) {
        guard isAuthenticated, !isCreatingGroup else { return }
        
        isCreatingGroup = true
        errorMessage = nil
        print("👥 Creating group: \(name)")
        
        let request = CreateGroupRequest(
            name: name,
            description: description,
            isPrivate: isPrivate,
            memberLimit: memberLimit,
            avatarColor: avatarColor,
            emoji: emoji
        )
        
        apiService.createGroup(request)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isCreatingGroup = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to create group: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    print("✅ Group created successfully: \(response.group.name)")
                    // Add to local groups
                    self?.userGroups.append(response.group)
                    self?.selectedGroup = response.group
                }
            )
            .store(in: &cancellables)
    }
    
    func joinGroup(inviteCode: String) {
        guard isAuthenticated, !isJoiningGroup else { return }
        
        isJoiningGroup = true
        errorMessage = nil
        print("👥 Joining group with code: \(inviteCode)")
        
        let request = JoinGroupRequest(inviteCode: inviteCode)
        
        apiService.joinGroup(request)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isJoiningGroup = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to join group: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    print("✅ Successfully joined group: \(response.group.name)")
                    // Add to local groups if not already present
                    if !(self?.userGroups.contains(where: { $0.id == response.group.id }) ?? false) {
                        self?.userGroups.append(response.group)
                    }
                    self?.selectedGroup = response.group
                }
            )
            .store(in: &cancellables)
    }
    
    func loadGroupMembers(_ groupId: Int) {
        guard isAuthenticated, !isLoadingGroupMembers else { return }
        
        isLoadingGroupMembers = true
        print("👥 Loading group members for group \(groupId)")
        
        apiService.getGroupMembers(groupId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingGroupMembers = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to load group members: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    print("✅ Group members loaded: \(response.members.count) members")
                    self?.groupMembers = response.members
                }
            )
            .store(in: &cancellables)
    }
    
    func loadGroupMessages(_ groupId: Int, before: Date? = nil, limit: Int = 50) {
        guard isAuthenticated, !isLoadingGroupMessages else { return }
        
        isLoadingGroupMessages = true
        print("💬 Loading group messages for group \(groupId)")
        
        apiService.getGroupMessages(groupId, before: before, limit: limit)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingGroupMessages = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to load group messages: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    print("✅ Group messages loaded: \(response.messages.count) messages")
                    if before == nil {
                        // New load - replace messages
                        self?.groupMessages = response.messages
                    } else {
                        // Load more - prepend messages
                        self?.groupMessages = response.messages + (self?.groupMessages ?? [])
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func sendGroupMessage(_ groupId: Int, content: String, messageType: MessageType = .text, locationId: Int? = nil, replyToId: Int? = nil) {
        guard isAuthenticated, !isSendingMessage else { return }
        
        isSendingMessage = true
        print("💬 Sending message to group \(groupId): \(content)")
        
        let request = SendMessageRequest(
            messageType: messageType.rawValue,
            content: content,
            locationId: locationId,
            replyToId: replyToId
        )
        
        apiService.sendGroupMessage(groupId, request)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSendingMessage = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to send message: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    print("✅ Message sent successfully")
                    // Add to local messages
                    self?.groupMessages.append(response.message)
                }
            )
            .store(in: &cancellables)
    }
    
    func leaveGroup(_ groupId: Int) {
        guard isAuthenticated else { return }
        
        print("👥 Leaving group \(groupId)")
        
        apiService.leaveGroup(groupId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to leave group: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    print("✅ Successfully left group")
                    // Remove from local groups
                    self?.userGroups.removeAll { $0.id == groupId }
                    // Clear selection if this was the selected group
                    if self?.selectedGroup?.id == groupId {
                        self?.selectedGroup = nil
                        self?.groupMembers = []
                        self?.groupMessages = []
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func shareLocationToGroup(_ groupId: Int, locationId: Int, notes: String? = nil, isPinned: Bool = false) {
        guard isAuthenticated else { return }
        
        print("📍 Sharing location \(locationId) to group \(groupId)")
        
        let request = ShareLocationRequest(
            locationId: locationId,
            notes: notes,
            isPinned: isPinned
        )
        
        apiService.shareLocationToGroup(groupId, request)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to share location: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    print("✅ Location shared to group successfully")
                    // Reload messages to show the shared location
                    self?.loadGroupMessages(groupId)
                }
            )
            .store(in: &cancellables)
    }
    
    func selectGroup(_ group: Group) {
        selectedGroup = group
        // Clear existing data
        groupMembers = []
        groupMessages = []
        // Load group data
        loadGroupMembers(group.id)
        loadGroupMessages(group.id)
    }
    
    func clearGroupSelection() {
        selectedGroup = nil
        groupMembers = []
        groupMessages = []
    }
    
    func updateMemberActivity(_ groupId: Int) {
        guard isAuthenticated else { return }
        
        apiService.updateMemberActivity(groupId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to update member activity: \(error.localizedDescription)")
                    }
                },
                receiveValue: { response in
                    print("✅ Member activity updated for group \(groupId)")
                }
            )
            .store(in: &cancellables)
    }
}
