//
//  MapView.swift
//  upwork-project
//
//  Created by Boris Milev on 22.06.25.
//

import SwiftUI
import MapboxMaps
import CoreLocation
import Combine

struct MapView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var geocodingService = GeocodingService()
    @State private var selectedLocation: AbandonedLocation?
    @State private var showLocationDetail = false
    @State private var lastLocationUpdate = Date()
    @State private var showingLocationSelector = false
    @State private var selectedLocationCategory = "Abandoned"
    @State private var showingProfile = false
    @State private var showingKeyAlerts = false
    @State private var currentZoomLevel: Double = 14.0
    @State private var currentMapCenter: CLLocationCoordinate2D?
    private let locationUpdateThreshold: TimeInterval = 5.0 // Increased from 3.0
    private let initialZoomLevel: Double = 14.0
    @State private var lastZoomApiCall = Date()
    private let zoomApiThreshold: TimeInterval = 10.0 // Increased from 5.0 - minimum 10 seconds between zoom-triggered API calls
    private let activeUserUpdateThreshold: TimeInterval = 15.0 // Minimum 15 seconds between active user API calls
    
    // Smart API call management - cache by geographic context
    @State private var lastApiCallLocation: CLLocationCoordinate2D?
    @State private var lastApiCallZoomLevel: Double = 0.0
    @State private var lastApiCallRadius: Double = 0.0
    @State private var cachedLocationContext: String = ""
    @State private var lastWasGlobalView: Bool? = nil
    @State private var lastWasLocalView: Bool? = nil
    @State private var hasPerformedInitialLoad = false
    
    // Rate limiting and cooldown management
    @State private var lastActiveUsersApiCall = Date.distantPast
    @State private var lastApiResponse: String = ""
    @State private var apiCallCooldownSeconds: TimeInterval = 30.0 // Increased cooldown
    @State private var isApiCallInProgress = false
    @State private var lastActiveUserApiCall = Date.distantPast // Track active user API calls separately
    
    // Mapbox configuration
    private let accessToken = MapboxConfiguration.accessToken
    private let customStyleURL = MapboxConfiguration.customStyleURL
    
    private var nearbyUserCount: Int {
        // Always show active users count based on current location context
        return dataManager.activeUsersCount
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Mapbox Map
            MapboxMapView(
                accessToken: accessToken,
                styleURI: customStyleURL,
                locations: dataManager.getApprovedLocations(),
                activeUsers: dataManager.activeUsers,
                userLocation: locationManager.userLocation,
                onLocationTap: { location in
                    selectedLocation = location
                    showLocationDetail = true
                },
                onZoomChange: { zoomLevel in
                    currentZoomLevel = zoomLevel
                    handleZoomBasedLocationLoading(zoomLevel: zoomLevel)
                },
                onMapCenterChange: { center in
                    currentMapCenter = center
                    // Update location name when map center changes
                    geocodingService.reverseGeocode(coordinate: center, zoomLevel: currentZoomLevel)
                    // Use smart active users loading with geographic context
                    loadActiveUsers()
                }
            )
            .ignoresSafeArea()
            
            // Header Overlay
            VStack {
                MapHeaderView(
                    selectedCategory: $selectedLocationCategory,
                    showingSelector: $showingLocationSelector,
                    showingProfile: $showingProfile,
                    nearbyUserCount: nearbyUserCount,
                    isGlobalView: currentZoomLevel < 10.0,
                    currentLocationName: geocodingService.currentLocationName,
                    geocodingService: geocodingService,
                    currentZoomLevel: currentZoomLevel,
                    onRefreshUsers: {
                        // Force refresh active users when user taps on count
                        print("🔄 Forcing active users refresh from header tap")
                        clearActiveUsersCache()
                        loadActiveUsers()
                    }
                )
                
                Spacer()
                
                // Bottom location info section (like Texas in Citizen)
                BottomLocationInfo(
                    locations: dataManager.getApprovedLocations(),
                    userLocation: locationManager.userLocation,
                    currentZoomLevel: currentZoomLevel,
                    currentLocationName: geocodingService.currentLocationName,
                    onKeyAlertsPressed: {
                        showingKeyAlerts = true
                    }
                )
            }
            
            // Loading indicator
            if dataManager.isLoading {
                VStack {
                    Spacer()
                    LoadingIndicator()
                    Spacer()
                }
            }
            
            // Error message overlay
            if let errorMessage = dataManager.errorMessage {
                VStack {
                    Spacer()
                    ErrorMessageView(message: errorMessage) {
                        dataManager.errorMessage = nil
                    }
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showLocationDetail) {
            if let location = selectedLocation {
                LocationDetailView(location: location)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingLocationSelector) {
            LocationCategorySelector(selectedCategory: $selectedLocationCategory)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
        }
        .sheet(isPresented: $showingKeyAlerts) {
            KeyAlertsView(
                locations: dataManager.getApprovedLocations(),
                userLocation: currentMapCenter ?? locationManager.userLocation,
                currentLocationName: geocodingService.currentLocationName
            )
        }
        .onAppear {
            print("🗺️ MapView appeared")
            print("🔍 Initial location manager status: \(locationManager.authorizationStatus.rawValue)")
            
            // Reset to locating state initially
            geocodingService.resetLocationToLocating()
            
            if let userLoc = locationManager.userLocation {
                print("📍 Initial user location: \(userLoc.latitude), \(userLoc.longitude)")
                currentMapCenter = userLoc
                geocodingService.forceInitialGeocode(coordinate: userLoc, zoomLevel: currentZoomLevel)
                // Update user's location in the backend
                dataManager.updateUserLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
                // Load active users with continent-level context initially for maximum coverage
                loadInitialActiveUsers()
            } else {
                print("📍 Initial user location: nil - will wait for location updates")
                // Don't geocode a default location - wait for actual user location
                // This prevents showing incorrect location names like "KS" before user location is available
            }
            
            // Request location permission if not already granted
            if locationManager.authorizationStatus == .notDetermined {
                print("🔒 Requesting location permission...")
                locationManager.requestLocationPermission()
            } else if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                print("✅ Location already authorized, starting updates")
                locationManager.startLocationUpdates()
            }
            loadInitialData()
        }
        .onChange(of: locationManager.userLocation) {
            if let location = locationManager.userLocation {
                print("📍 User location changed: \(location.latitude), \(location.longitude)")
                print("🎯 Updating map center to user location: \(location.latitude), \(location.longitude)")
                
                // Check if this is a significant location change that should clear cache
                if let lastLocation = lastApiCallLocation {
                    let distance = CLLocationCoordinate2D.distance(from: lastLocation, to: location) / 1000.0
                    if distance > 50.0 { // Clear cache if user moved more than 50km
                        print("🚀 User moved \(String(format: "%.1f", distance))km - clearing API cache")
                        clearActiveUsersCache()
                    }
                }
                
                currentMapCenter = location
                // Force geocoding when user location first becomes available
                geocodingService.forceInitialGeocode(coordinate: location, zoomLevel: currentZoomLevel)
                loadInitialData() // Use initial data loading for first location update
                
                // Update user's location in the backend for active users tracking
                dataManager.updateUserLocation(latitude: location.latitude, longitude: location.longitude)
            } else {
                print("📍 User location changed: nil")
            }
        }
        .onChange(of: locationManager.userLocation?.latitude) { _ in
            throttledLocationUpdate()
        }
        .onChange(of: locationManager.userLocation?.longitude) { _ in
            throttledLocationUpdate()
        }
        .onChange(of: locationManager.authorizationStatus) {
            print("🔄 Authorization status changed to: \(locationManager.authorizationStatus.rawValue)")
            if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                print("✅ Location now authorized, starting updates")
                locationManager.startLocationUpdates()
                // Trigger immediate location update when permission is granted
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if let userLoc = locationManager.userLocation {
                        currentMapCenter = userLoc
                        geocodingService.forceInitialGeocode(coordinate: userLoc, zoomLevel: currentZoomLevel)
                        // Update user's location in the backend
                        dataManager.updateUserLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
                        // Load active users for newly authorized location
                        loadInitialActiveUsers()
                    }
                }
            }
        }
    }
    
    private func throttledLocationUpdate() {
        let now = Date()
        guard now.timeIntervalSince(lastLocationUpdate) >= locationUpdateThreshold else {
            return
        }
        lastLocationUpdate = now
        updateLocationAndLoad()
    }
    
    private func loadInitialData() {
        // Load both locations and active users with continent-level context for maximum coverage
        // Only perform initial load once
        guard !hasPerformedInitialLoad else {
            print("⏸️ Initial data already loaded, using normal loading")
            loadNearbyLocations()
            return
        }
        
        hasPerformedInitialLoad = true
        print("🚀 Initial data load - using continent-level coverage")
        
        // Load locations with continent-level context
        if let userLocation = locationManager.userLocation {
            print("📍 Loading locations for continent-level context around user location")
            // For initial load, use continent-level context to get broader coverage
            dataManager.loadAllLocations() // Global load for maximum initial coverage
        } else {
            print("📍 No user location - loading all locations globally")
            dataManager.loadAllLocations()
        }
        
        // Load active users with continent-level context
        loadInitialActiveUsers()
    }
    
    private func loadNearbyLocations() {
        print("🌍 Loading locations based on current zoom level: \(currentZoomLevel)")
        
        // Smart location loading based on zoom context
        let contextLevel = geocodingService.getActiveUsersContextName(zoomLevel: currentZoomLevel)
        
        // For very zoomed out views (continent/worldwide), load all locations globally
        if contextLevel == "Europe" || contextLevel == "United States" || contextLevel == "Worldwide" {
            print("📍 Context level '\(contextLevel)' - loading all locations globally")
            dataManager.loadAllLocations()
        } else if let userLocation = locationManager.userLocation {
            print("📍 Context level '\(contextLevel)' - loading nearby locations: \(userLocation)")
            dataManager.loadNearbyLocations(
                latitude: userLocation.latitude,
                longitude: userLocation.longitude
            )
        } else {
            print("📍 No user location available - loading all locations as fallback")
            dataManager.loadAllLocations()
        }
        print("📊 Current approved locations count: \(dataManager.getApprovedLocations().count)")
        
        // Also load active users count with smart caching
        loadActiveUsers()
    }
    
    private func getContextNameForZoomLevel(_ zoomLevel: Double) -> String {
        // Determine context name based on zoom level without relying on geocoding data
        switch zoomLevel {
        case 16.0...: // Street level
            return "street"
        case 14.0..<16.0: // Neighborhood  
            return "neighborhood"
        case 12.0..<14.0: // City level
            return "city"
        case 10.0..<12.0: // State/Region level
            return "state"
        case 8.0..<10.0: // Country level
            return "country"
        case 6.0..<8.0: // Continental level
            return "continent"
        default: // Worldwide
            return "worldwide"
        }
    }
    
    private func loadInitialActiveUsers() {
        // Load active users with country-level context for good coverage on app launch
        // This ensures users see relevant active users in their country/region initially
        
        guard let centerCoordinate = currentMapCenter ?? locationManager.userLocation else {
            print("📍 No location available for initial active users loading")
            return
        }
        
        // Use country-level zoom (9.0) for initial loading to get good coverage without being too broad
        let countryZoomLevel: Double = 9.0
        let countryRadius = geocodingService.getActiveUsersRadius(zoomLevel: countryZoomLevel)
        let contextName = getContextNameForZoomLevel(countryZoomLevel)
        
        print("🌍 Initial active users load - country-level context")
        print("   Center: \(centerCoordinate.latitude), \(centerCoordinate.longitude)")
        print("   Radius: \(countryRadius)km")
        print("   Context: \(contextName)")
        print("   Zoom level used: \(countryZoomLevel)")
        
        // Update cache for initial load
        lastApiCallLocation = centerCoordinate
        lastApiCallRadius = countryRadius
        lastApiCallZoomLevel = countryZoomLevel
        cachedLocationContext = contextName
        
        dataManager.loadActiveUsers(
            latitude: centerCoordinate.latitude,
            longitude: centerCoordinate.longitude,
            radius: countryRadius
        )
    }
    
    private func loadActiveUsers() {
        // Smart location-based API call limiting
        // Only make API calls when crossing significant geographic boundaries
        
        // Check if we should throttle API calls to prevent rate limiting
        let now = Date()
        if now.timeIntervalSince(lastActiveUserApiCall) < activeUserUpdateThreshold {
            print("⏸️ Throttling active users API call - too soon since last call (\(String(format: "%.1f", now.timeIntervalSince(lastActiveUserApiCall)))s ago)")
            return
        }
        
        // Determine center coordinate for active users query
        let centerCoordinate: CLLocationCoordinate2D
        
        if let mapCenter = currentMapCenter {
            centerCoordinate = mapCenter
        } else if let userLocation = locationManager.userLocation {
            centerCoordinate = userLocation
        } else {
            // No location available, skip active users loading
            print("📍 No location available for loading active users")
            return
        }
        
        // Use geocoding service to get synchronized radius and context
        let radius = geocodingService.getActiveUsersRadius(zoomLevel: currentZoomLevel)
        let contextName = geocodingService.getActiveUsersContextName(zoomLevel: currentZoomLevel)
        
        // Fallback to zoom-based context if geocoding context is not available
        let finalContextName = contextName.isEmpty ? getContextNameForZoomLevel(currentZoomLevel) : contextName
        
        // Debug: Log current zoom and expected radius (reduced logging)
        if Bool.random() { // Only log 50% of the time to reduce spam
            print("🔍 Current zoom level: \(currentZoomLevel)")
            print("🔍 Expected radius: \(radius)km")
            print("🔍 Context: \(finalContextName)")
            print("🔍 Currently loaded users: \(dataManager.activeUsersCount)")
        }
        
        // Check if we need to make an API call based on geographic context
        if shouldMakeActiveUsersApiCall(
            centerCoordinate: centerCoordinate,
            radius: radius,
            zoomLevel: currentZoomLevel,
            contextLevel: finalContextName
        ) {
            print("👥 Making active users API call - center: \(centerCoordinate.latitude), \(centerCoordinate.longitude), radius: \(radius)km, zoom: \(currentZoomLevel), context: \(finalContextName)")
            
            // Update cache before making the call
            lastApiCallLocation = centerCoordinate
            lastApiCallRadius = radius
            lastApiCallZoomLevel = currentZoomLevel
            cachedLocationContext = finalContextName
            lastActiveUserApiCall = now
            
            dataManager.loadActiveUsers(
                latitude: centerCoordinate.latitude,
                longitude: centerCoordinate.longitude,
                radius: radius
            )
        } else {
            // Check if we have a mismatch between expected coverage and actual data
            // This can happen when zooming out and the cached data doesn't cover the new view
            let expectedCoverageRadius = radius
            let cachedCoverageRadius = lastApiCallRadius
            
            if expectedCoverageRadius > cachedCoverageRadius * 3.0 { // Increased threshold to reduce API calls
                print("🔄 Expected coverage (\(expectedCoverageRadius)km) much larger than cached (\(cachedCoverageRadius)km) - forcing refresh")
                clearActiveUsersCache()
                loadActiveUsers() // Recursive call will now pass the shouldMakeApiCall check
                return
            }
            
            // Only log occasionally to reduce spam
            if Bool.random() {
                print("⏸️ Skipping active users API call - using cached data for context: \(cachedLocationContext)")
            }
        }
    }
    
    private func shouldMakeActiveUsersApiCall(
        centerCoordinate: CLLocationCoordinate2D,
        radius: Double,
        zoomLevel: Double,
        contextLevel: String
    ) -> Bool {
        // Always make the first call
        guard let lastLocation = lastApiCallLocation else {
            print("🆕 First active users API call")
            return true
        }
        
        // If context level changed significantly, make new call
        if cachedLocationContext != contextLevel {
            print("🔄 Context changed from '\(cachedLocationContext)' to '\(contextLevel)' - making new API call")
            return true
        }
        
        // Check if we've moved outside the cached area
        let distanceFromLastCall = CLLocationCoordinate2D.distance(
            from: lastLocation,
            to: centerCoordinate
        ) / 1000.0 // Convert to km
        
        // Use much larger thresholds to reduce API calls and prevent rate limiting
        let movementThreshold: Double
        switch contextLevel {
        case "street":
            movementThreshold = 5.0 // Increased from 1km
        case "neighborhood":
            movementThreshold = 10.0 // Increased from 2.5km
        case "city":
            movementThreshold = 25.0 // Increased from 7.5km
        case "state":
            movementThreshold = 100.0 // Increased from 25km
        case "country":
            movementThreshold = 200.0 // Increased from 75km
        case "continent":
            movementThreshold = 500.0 // Increased from 250km
        case "worldwide":
            movementThreshold = 1000.0 // Increased from 1000km - keep same
        default:
            movementThreshold = 100.0 // Increased default
        }
        
        if distanceFromLastCall > movementThreshold {
            print("🚀 Moved \(String(format: "%.1f", distanceFromLastCall))km (threshold: \(movementThreshold)km) - making new API call")
            return true
        }
        
        // Check significant zoom level changes within same context
        let zoomDifference = abs(zoomLevel - lastApiCallZoomLevel)
        if zoomDifference > 1.5 && contextLevel == cachedLocationContext {
            print("🔍 Significant zoom change (\(String(format: "%.1f", zoomDifference))) within same context - making new API call")
            return true
        }
        
        print("📍 Staying within cached area - distance: \(String(format: "%.1f", distanceFromLastCall))km, threshold: \(movementThreshold)km")
        return false
    }
    
    private func updateLocationAndLoad() {
        if locationManager.userLocation != nil {
            loadNearbyLocations()
        }
    }
    
    private func handleZoomBasedLocationLoading(zoomLevel: Double) {
        // Smart zoom-based loading with geographic context awareness
        let newContextLevel = geocodingService.getActiveUsersContextName(zoomLevel: zoomLevel)
        let previousContextLevel = geocodingService.getActiveUsersContextName(zoomLevel: lastApiCallZoomLevel)
        
        // Use fallback context determination if geocoding is not available
        let finalNewContext = newContextLevel.isEmpty ? getContextNameForZoomLevel(zoomLevel) : newContextLevel
        let finalPreviousContext = previousContextLevel.isEmpty ? getContextNameForZoomLevel(lastApiCallZoomLevel) : previousContextLevel
        
        let now = Date()
        guard now.timeIntervalSince(lastZoomApiCall) >= zoomApiThreshold else {
            print("⏸️ Throttling zoom-based API call - too soon since last call")
            return
        }
        
        // Only make API calls when crossing significant context boundaries
        var shouldMakeApiCall = false
        
        // Check if we've moved to a different geographic context
        if finalNewContext != finalPreviousContext {
            print("🔄 Context changed from '\(finalPreviousContext)' to '\(finalNewContext)' (zoom: \(zoomLevel))")
            shouldMakeApiCall = true
        }
        
        // Legacy compatibility for major zoom threshold changes
        let globalViewThreshold: Double = 6.0 // Country level
        let localViewThreshold: Double = 12.0 // District level
        
        let isGlobalView = zoomLevel < globalViewThreshold
        let isLocalView = zoomLevel >= localViewThreshold
        
        if isGlobalView && self.lastWasGlobalView != true {
            print("🌍 Switched to global view (zoom: \(zoomLevel)) - Loading all approved locations")
            shouldMakeApiCall = true
            self.lastWasGlobalView = true
            self.lastWasLocalView = false
        } else if isLocalView && self.lastWasLocalView != true && locationManager.userLocation != nil {
            print("📍 Switched to local view (zoom: \(zoomLevel)) - Loading nearby locations")
            shouldMakeApiCall = true
            self.lastWasLocalView = true
            self.lastWasGlobalView = false
        }
        
        if shouldMakeApiCall {
            lastZoomApiCall = now
            
            // Use the smart location loading system - sync with geocoding contexts
            if finalNewContext == "continent" || finalNewContext == "worldwide" {
                dataManager.loadAllLocations()
            } else if let userLocation = locationManager.userLocation {
                dataManager.loadNearbyLocations(
                    latitude: userLocation.latitude,
                    longitude: userLocation.longitude
                )
            } else {
                dataManager.loadAllLocations()
            }
            
            // Load active users with smart caching
            loadActiveUsers()
        } else {
            print("⏸️ Staying within same context '\(finalNewContext)' - no API call needed")
        }
    }
    
    private func clearActiveUsersCache() {
        lastApiCallLocation = nil
        lastApiCallZoomLevel = 0.0
        lastApiCallRadius = 0.0
        cachedLocationContext = ""
        print("🗑️ Cleared active users API cache")
    }
    
    private func logCacheStatus() {
        if let lastLocation = lastApiCallLocation {
            print("📊 Cache Status:")
            print("   Last API call: \(lastLocation.latitude), \(lastLocation.longitude)")
            print("   Context: \(cachedLocationContext)")
            print("   Radius: \(lastApiCallRadius)km")
            print("   Zoom: \(String(format: "%.2f", lastApiCallZoomLevel))")
        } else {
            print("📊 Cache Status: Empty")
        }
    }
}

// MARK: - Mapbox Map View
struct MapboxMapView: UIViewRepresentable {
    typealias UIViewType = MapboxMaps.MapView
    
    let accessToken: String
    let styleURI: String
    let locations: [AbandonedLocation]
    let activeUsers: [ActiveUser]
    let userLocation: CLLocationCoordinate2D?
    let onLocationTap: (AbandonedLocation) -> Void
    let onZoomChange: (Double) -> Void
    let onMapCenterChange: ((CLLocationCoordinate2D) -> Void)?
    
    func makeUIView(context: Context) -> MapboxMaps.MapView {
        let mapView = MapboxMaps.MapView(frame: .zero)
        mapView.backgroundColor = UIColor.black
        
        // Configure access token and load style
        mapView.mapboxMap.loadStyle(StyleURI(rawValue: styleURI) ?? .dark)
        
        // Add gesture recognizer for location taps
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        // Add zoom change listener for UI updates only
        mapView.mapboxMap.onCameraChanged.observe { _ in
            let zoomLevel = mapView.mapboxMap.cameraState.zoom
            let center = mapView.mapboxMap.cameraState.center
            context.coordinator.parent.onZoomChange(zoomLevel)
            context.coordinator.parent.onMapCenterChange?(center)
            
            // Only scale existing markers, don't clear/reload them
            context.coordinator.scaleAnnotationsForZoom(zoomLevel: zoomLevel)
            // Also update active user markers for zoom changes
            context.coordinator.updateActiveUserMarkers(activeUsers: activeUsers, zoomLevel: zoomLevel)
        }.store(in: &context.coordinator.cancellables)
        
        // Trigger initial location detection after map is loaded
        mapView.mapboxMap.onStyleLoaded.observeNext { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let center = mapView.mapboxMap.cameraState.center
                let zoomLevel = mapView.mapboxMap.cameraState.zoom
                context.coordinator.parent.onMapCenterChange?(center)
                print("🗺️ Initial map loaded, triggering geocoding for center: \(center)")
            }
        }.store(in: &context.coordinator.cancellables)
        
        context.coordinator.mapView = mapView
        return mapView
    }
    
    func updateUIView(_ uiView: MapboxMaps.MapView, context: Context) {
        // Set initial camera position to user location when available
        if !context.coordinator.hasSetInitialCamera {
            if let userLocation = userLocation {
                print("🎯 Setting initial camera to user location: \(userLocation)")
                let cameraOptions = CameraOptions(
                    center: userLocation,
                    zoom: 14.0
                )
                uiView.mapboxMap.setCamera(to: cameraOptions)
                print("📸 Camera set to user location with zoom 14.0")
                context.coordinator.hasSetInitialCamera = true
                context.coordinator.hasUserLocation = true
                print("✅ Initial camera set flag = true")
            } else {
                print("🌍 No user location available yet, using default location (NYC)")
                // Default to a reasonable location (NYC) if no user location
                let defaultLocation = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
                let cameraOptions = CameraOptions(
                    center: defaultLocation,
                    zoom: 10.0
                )
                uiView.mapboxMap.setCamera(to: cameraOptions)
                print("📸 Camera set to default location (NYC) with zoom 10.0")
                context.coordinator.hasSetInitialCamera = true
                print("✅ Initial camera set to default, waiting for user location")
            }
        } else if let userLocation = userLocation, !context.coordinator.hasUserLocation {
            // User location became available after initial setup - center on it
            print("🎯 User location now available, centering camera: \(userLocation)")
            let cameraOptions = CameraOptions(
                center: userLocation,
                zoom: 14.0
            )
            uiView.mapboxMap.setCamera(to: cameraOptions)
            context.coordinator.hasUserLocation = true
            print("📸 Camera recentered to user location with zoom 14.0")
        } else {
            print("⏩ Skipping camera update - already centered on user location")
        }
        
        // Update annotations with current zoom level
        let currentZoom = uiView.mapboxMap.cameraState.zoom
        context.coordinator.updateAnnotations(locations: locations, userLocation: userLocation, zoomLevel: currentZoom)
        context.coordinator.updateActiveUserMarkers(activeUsers: activeUsers, zoomLevel: currentZoom)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: MapboxMapView
        var mapView: MapboxMaps.MapView?
        private var pointAnnotationManager: PointAnnotationManager?
        private var userAnnotationManager: PointAnnotationManager?
        var cancellables: Set<AnyCancellable> = []
        var hasSetInitialCamera = false
        var hasUserLocation = false
        
        // Debounce mechanism to prevent marker flickering
        private var debounceTimer: Timer?
        private var pendingLocations: [AbandonedLocation] = []
        private var pendingUserLocation: CLLocationCoordinate2D?
        private var pendingZoomLevel: Double = 0.0
        private let debounceDelay: TimeInterval = 0.8 // Increased to 800ms debounce to reduce flicker
        
        // Throttling for scaling updates
        private var lastScaleTime: TimeInterval = 0
        
        init(_ parent: MapboxMapView) {
            self.parent = parent
        }
        
        deinit {
            debounceTimer?.invalidate()
            cancellables.removeAll()
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = mapView else { return }
            
            let point = gesture.location(in: mapView)
            let coordinate = mapView.mapboxMap.coordinate(for: point)
            
            // Find the closest location to the tap
            let closestLocation = parent.locations.min { location1, location2 in
                let distance1 = CLLocationCoordinate2D.distance(from: coordinate, to: location1.coordinate)
                let distance2 = CLLocationCoordinate2D.distance(from: coordinate, to: location2.coordinate)
                return distance1 < distance2
            }
            
            if let location = closestLocation {
                let distance = CLLocationCoordinate2D.distance(from: coordinate, to: location.coordinate)
                if distance < 100 { // 100 meters threshold
                    parent.onLocationTap(location)
                }
            }
        }
        
        func debounceAnnotationUpdate(locations: [AbandonedLocation], userLocation: CLLocationCoordinate2D?, zoomLevel: Double) {
            // Store pending data for debounced update
            pendingLocations = locations
            pendingUserLocation = userLocation
            pendingZoomLevel = zoomLevel
            
            // Cancel existing timer and start new one
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceDelay, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.performDebouncedUpdate()
                }
            }
        }
        
        func updateAnnotations(locations: [AbandonedLocation], userLocation: CLLocationCoordinate2D?, zoomLevel: Double) {
            // Don't clear existing markers if we're getting empty locations during a reload
            // This prevents flicker when the API is reloading data
            if locations.isEmpty && !(pointAnnotationManager?.annotations.isEmpty ?? true) {
                print("⚠️ Skipping annotation update - empty locations array but we have existing markers")
                return
            }
            
            // Store pending data for debounced update
            pendingLocations = locations
            pendingUserLocation = userLocation
            pendingZoomLevel = zoomLevel
            
            // If we have no current annotations, update immediately (first load)
            let shouldUpdateImmediately = pointAnnotationManager?.annotations.isEmpty ?? true
            
            if shouldUpdateImmediately {
                // Immediate update for first load
                performDebouncedUpdate()
            } else {
                // Cancel existing timer and start new one for subsequent updates
                debounceTimer?.invalidate()
                debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceDelay, repeats: false) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.performDebouncedUpdate()
                    }
                }
            }
        }
        
        func scaleAnnotationsForZoom(zoomLevel: Double) {
            guard let annotationManager = pointAnnotationManager else { return }
            
            // Throttle scaling updates to avoid excessive calls
            let now = Date.timeIntervalSinceReferenceDate
            let scaleThreshold: TimeInterval = 0.1 // Only scale every 100ms
            
            if now - lastScaleTime < scaleThreshold {
                return
            }
            lastScaleTime = now
            
            // Only update the size of existing markers without clearing them
            let scaleFactor = calculateScaleFactor(zoomLevel: zoomLevel)
            
            // Update existing annotations with new scale
            var updatedAnnotations: [PointAnnotation] = []
            
            for annotation in annotationManager.annotations {
                var updatedAnnotation = annotation
                updatedAnnotation.iconSize = scaleFactor
                updatedAnnotations.append(updatedAnnotation)
            }
            
            // Update annotations without clearing
            annotationManager.annotations = updatedAnnotations
            
            print("📏 Scaled \(updatedAnnotations.count) markers for zoom level \(String(format: "%.2f", zoomLevel)) with scale \(String(format: "%.2f", scaleFactor))")
        }
        
        private func calculateUserScaleFactor(zoomLevel: Double) -> Double {
            // Special scaling for user markers - keep them more visible at continental levels
            let minZoom: Double = 4.0   // Global view - very zoomed out
            let maxZoom: Double = 18.0  // Street level - very zoomed in
            let minScale: Double = 0.6  // Larger minimum for better visibility at continental level
            let maxScale: Double = 1.0  // Normal size for street level
            
            // Smooth curve - less dramatic scaling than location markers
            let normalizedZoom = max(0, min(1, (zoomLevel - minZoom) / (maxZoom - minZoom)))
            
            // Use less aggressive curve for user markers to keep them visible
            let curve = pow(normalizedZoom, 0.5) // Less dramatic scaling than location markers
            let scaleFactor = minScale + (maxScale - minScale) * curve
            
            print("👤 User marker zoom: \(String(format: "%.2f", zoomLevel)) -> Scale: \(String(format: "%.3f", scaleFactor))")
            return scaleFactor
        }
        
        private func calculateScaleFactor(zoomLevel: Double) -> Double {
            // Citizen-style scaling: very small when zoomed out, normal size when zoomed in
            let minZoom: Double = 4.0   // Global view - very zoomed out
            let maxZoom: Double = 18.0  // Street level - very zoomed in
            let minScale: Double = 0.3  // Very small for global view (like in photos)
            let maxScale: Double = 1.2  // Normal size for street level
            
            // Smooth curve - more dramatic scaling at lower zoom levels
            let normalizedZoom = max(0, min(1, (zoomLevel - minZoom) / (maxZoom - minZoom)))
            
            // Use exponential curve for more dramatic scaling at low zoom levels
            let curve = pow(normalizedZoom, 0.7) // Makes scaling more gradual at high zoom
            let scaleFactor = minScale + (maxScale - minScale) * curve
            
            print("🔍 Zoom: \(String(format: "%.2f", zoomLevel)) -> Scale: \(String(format: "%.3f", scaleFactor))")
            return scaleFactor
        }
        
        private func performDebouncedUpdate() {
            guard let mapView = mapView else { return }
            
            print("📍 Performing debounced update with \(pendingLocations.count) locations at zoom \(pendingZoomLevel)")
            
            // Initialize annotation manager if needed
            if pointAnnotationManager == nil {
                pointAnnotationManager = mapView.annotations.makePointAnnotationManager()
            }
            
            guard let annotationManager = pointAnnotationManager else { return }
            
            // Clear existing annotations
            annotationManager.annotations = []
            
            // Calculate scale factor first for consistent use throughout
            let scaleFactor = calculateScaleFactor(zoomLevel: pendingZoomLevel)
            
            // Apply clustering/crowd effect based on zoom level
            let processedLocations = applyCrowdEffect(locations: pendingLocations, zoomLevel: pendingZoomLevel)
            
            // Register custom images with the map style (zoom-aware sizing)
            registerCustomImages(mapView: mapView, locations: processedLocations, zoomLevel: pendingZoomLevel)
            
            // Add user location annotation (blue dot like in Citizen)
            if let userLocation = pendingUserLocation {
                var userAnnotation = PointAnnotation(coordinate: userLocation)
                userAnnotation.iconImage = "user_location_marker"
                userAnnotation.iconSize = scaleFactor * 1.1 // Slightly larger than location markers
                userAnnotation.iconAnchor = .center // Center the user location dot
                annotationManager.annotations.append(userAnnotation)
                print("📍 Added user location marker at \(userLocation) with scale \(String(format: "%.3f", scaleFactor))")
            }
            
            // Add location annotations with Citizen-style markers and scaling
            for (index, location) in processedLocations.enumerated() {
                var annotation = PointAnnotation(coordinate: location.coordinate)
                
                // Use unique marker based on location ID
                let markerImageId = "marker_\(location.id)"
                annotation.iconImage = markerImageId
                annotation.iconSize = scaleFactor // Use calculated scale factor for bubble effect
                annotation.iconAnchor = .center // Center the circular marker
                
                print("📍 Adding marker \(index + 1): \(location.title) (\(location.category.rawValue)) at \(location.coordinate) with image \(markerImageId) and scale \(String(format: "%.3f", scaleFactor))")
                
                annotationManager.annotations.append(annotation)
            }
            
            print("📍 Total annotations added: \(annotationManager.annotations.count) (processed from \(pendingLocations.count) original locations)")
        }
        
        // Apply crowd effect - cluster nearby markers when zoomed out
        private func applyCrowdEffect(locations: [AbandonedLocation], zoomLevel: Double) -> [AbandonedLocation] {
            // At high zoom levels (close up), show all markers
            if zoomLevel >= 14.0 {
                return locations
            }
            
            // At lower zoom levels, apply clustering to prevent overcrowding
            let clusterDistance: Double
            if zoomLevel >= 12.0 {
                clusterDistance = 0.001 // ~100 meters
            } else if zoomLevel >= 10.0 {
                clusterDistance = 0.003 // ~300 meters  
            } else if zoomLevel >= 8.0 {
                clusterDistance = 0.01  // ~1 km
            } else {
                clusterDistance = 0.05  // ~5 km for very zoomed out
            }
            
            var clusteredLocations: [AbandonedLocation] = []
            var processedIndices: Set<Int> = []
            
            for (index, location) in locations.enumerated() {
                if processedIndices.contains(index) { continue }
                
                // Find nearby locations to cluster
                var cluster: [AbandonedLocation] = [location]
                processedIndices.insert(index)
                
                for (otherIndex, otherLocation) in locations.enumerated() {
                    if otherIndex == index || processedIndices.contains(otherIndex) { continue }
                    
                    let distance = CLLocationCoordinate2D.distance(from: location.coordinate, to: otherLocation.coordinate)
                    if distance <= clusterDistance * 111000 { // Convert degrees to meters roughly
                        cluster.append(otherLocation)
                        processedIndices.insert(otherIndex)
                    }
                }
                
                // For clusters, use the most important location (dangerous > unsafe > safe)
                let representativeLocation = cluster.max { loc1, loc2 in
                    loc1.danger.rawValue < loc2.danger.rawValue
                } ?? location
                
                clusteredLocations.append(representativeLocation)
                
                if cluster.count > 1 {
                    print("🔗 Clustered \(cluster.count) locations at zoom \(String(format: "%.2f", zoomLevel)) using representative: \(representativeLocation.title)")
                }
            }
            
            return clusteredLocations
        }
        
        private func registerCustomImages(mapView: MapboxMaps.MapView, locations: [AbandonedLocation], zoomLevel: Double) {
            print("📷 Registering custom images with smooth clustering at zoom level: \(zoomLevel)...")
            
            // Register user location marker
            let userMarker = createUserLocationMarker()
            do {
                try mapView.mapboxMap.addImage(userMarker, id: "user_location_marker")
                print("✅ Added user location image")
            } catch {
                print("❌ Error adding user location image: \(error)")
            }
            
            // Register markers with smooth zoom-based sizing
            for location in locations {
                let markerImage = createMarkerForLocation(location, zoomLevel: zoomLevel)
                let imageId = "marker_\(location.id)"
                do {
                    try mapView.mapboxMap.addImage(markerImage, id: imageId)
                    print("✅ Added smooth marker for location \(location.id) (\(location.category.rawValue)) at zoom \(zoomLevel)")
                } catch {
                    print("❌ Error adding marker image for location \(location.id): \(error)")
                }
            }
        }
        
        private func createMarkerForDangerLevel(_ dangerLevel: DangerLevel) -> UIImage {
            let size = CGSize(width: 44, height: 44) // Circular design like Citizen
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                let cgContext = context.cgContext
                let rect = CGRect(origin: .zero, size: size)
                let center = CGPoint(x: rect.midX, y: rect.midY)
                let radius = min(rect.width, rect.height) / 2 - 2
                
                // Draw outer golden ring (like Citizen)
                let ringColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Golden yellow
                cgContext.setFillColor(ringColor.cgColor)
                cgContext.setShadow(offset: CGSize(width: 0, height: 2), blur: 6, color: ringColor.withAlphaComponent(0.6).cgColor)
                cgContext.fillEllipse(in: rect)
                
                // Draw transparent/semi-transparent inner circle
                let innerRadius = radius - 4
                let innerRect = CGRect(
                    x: center.x - innerRadius, 
                    y: center.y - innerRadius, 
                    width: innerRadius * 2, 
                    height: innerRadius * 2
                )
                cgContext.setFillColor(UIColor.black.withAlphaComponent(0.2).cgColor) // Very transparent dark background
                cgContext.fillEllipse(in: innerRect)
                
                // Add subtle inner border
                cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
                cgContext.setLineWidth(1)
                cgContext.strokeEllipse(in: innerRect)
            }
        }
        
        // Smooth Citizen-style markers with detailed icons at all zoom levels
        private func createMarkerForLocation(_ location: AbandonedLocation, zoomLevel: Double) -> UIImage {
            // Dynamic sizing based on zoom level for bubble effect
            let baseSize: CGFloat = 48 // Reduced base size for better scaling
            let size = CGSize(width: baseSize, height: baseSize)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                let cgContext = context.cgContext
                let rect = CGRect(origin: .zero, size: size)
                let center = CGPoint(x: rect.midX, y: rect.midY)
                
                // Drop shadow for depth (more subtle at smaller sizes)
                let shadowAlpha = max(0.2, min(0.4, zoomLevel / 15.0))
                cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, 
                                  color: UIColor.black.withAlphaComponent(shadowAlpha).cgColor)
                
                // GOLDEN RING - scales with zoom for bubble effect
                let ringRadius: CGFloat = 18 // Smaller ring for better scaling
                let strokeWidth: CGFloat = 2.0 // Thinner stroke
                
                // Golden ring (Citizen-style)
                cgContext.setStrokeColor(UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0).cgColor)
                cgContext.setLineWidth(strokeWidth)
                let strokeRect = CGRect(x: center.x - ringRadius, y: center.y - ringRadius, 
                                      width: ringRadius * 2, height: ringRadius * 2)
                cgContext.strokeEllipse(in: strokeRect)
                
                // Clear shadow for inner elements
                cgContext.setShadow(offset: .zero, blur: 0, color: UIColor.clear.cgColor)
                
                // TRANSPARENT INNER CIRCLE
                let innerRadius = ringRadius - strokeWidth
                let innerRect = CGRect(x: center.x - innerRadius, y: center.y - innerRadius,
                                     width: innerRadius * 2, height: innerRadius * 2)
                
                // Very subtle background for contrast
                cgContext.setFillColor(UIColor.black.withAlphaComponent(0.05).cgColor)
                cgContext.fillEllipse(in: innerRect)
                
                // CATEGORY ICON - always visible, scales with zoom
                let iconSize: CGFloat = max(12, min(24, 8 + (zoomLevel * 1.2))) // Dynamic icon size
                
                // Get icon name based on category
                let iconName = location.category.icon
                
                // Draw the detailed category icon
                if let customIcon = UIImage(named: iconName) {
                    let iconRect = CGRect(
                        x: center.x - iconSize/2,
                        y: center.y - iconSize/2,
                        width: iconSize,
                        height: iconSize
                    )
                    
                    // Use original icon colors - no tinting for maximum clarity
                    customIcon.draw(in: iconRect)
                    
                } else {
                    // Fallback: white dot (minimal and clean)
                    cgContext.setFillColor(UIColor.white.cgColor)
                    let fallbackRadius: CGFloat = iconSize / 4
                    let fallbackRect = CGRect(x: center.x - fallbackRadius, y: center.y - fallbackRadius, 
                                            width: fallbackRadius * 2, height: fallbackRadius * 2)
                    cgContext.fillEllipse(in: fallbackRect)
                }
            }
        }
        
        private func createUserLocationMarker() -> UIImage {
            let size = CGSize(width: 24, height: 24) // Smaller base size for better scaling
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                let cgContext = context.cgContext
                let rect = CGRect(origin: .zero, size: size)
                
                // Create pulsing effect background (larger circle) - more subtle
                let pulseRect = rect
                cgContext.setFillColor(UIColor.systemBlue.withAlphaComponent(0.15).cgColor)
                cgContext.fillEllipse(in: pulseRect)
                
                // Create main blue dot
                let dotRect = rect.insetBy(dx: 4, dy: 4)
                cgContext.setFillColor(UIColor.systemBlue.cgColor)
                cgContext.fillEllipse(in: dotRect)
                
                // Add white border around blue dot (thinner)
                cgContext.setStrokeColor(UIColor.white.cgColor)
                cgContext.setLineWidth(2)
                cgContext.strokeEllipse(in: dotRect)
                
                // Add smaller inner white circle for definition
                let innerDotRect = dotRect.insetBy(dx: 2, dy: 2)
                cgContext.setFillColor(UIColor.white.cgColor)
                cgContext.fillEllipse(in: innerDotRect)
            }
        }
        
        private func colorForCategory(_ category: LocationCategory, dangerLevel: DangerLevel) -> UIColor {
            // Ultra-vibrant colors exactly like Citizen app for maximum visibility
            let baseAlpha: CGFloat = 1.0 // Always full opacity for maximum impact
            
            switch category {
            case .hospital:
                return UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: baseAlpha) // Pure bright red
            case .factory:
                return UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: baseAlpha) // Vibrant orange
            case .school:
                return UIColor(red: 0.0, green: 0.4, blue: 1.0, alpha: baseAlpha) // Bright blue
            case .house:
                return UIColor(red: 0.0, green: 0.9, blue: 0.0, alpha: baseAlpha) // Bright green
            case .mall:
                return UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: baseAlpha) // Bright yellow
            case .church:
                return UIColor(red: 0.8, green: 0.0, blue: 1.0, alpha: baseAlpha) // Bright purple
            case .theater:
                return UIColor(red: 1.0, green: 0.0, blue: 0.6, alpha: baseAlpha) // Bright magenta
            case .other:
                return UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: baseAlpha) // Bright gray
            }
        }
        
        func updateActiveUserMarkers(activeUsers: [ActiveUser], zoomLevel: Double) {
            guard let mapView = mapView else { return }
            
            // Initialize user annotation manager if needed
            if userAnnotationManager == nil {
                userAnnotationManager = mapView.annotations.makePointAnnotationManager()
            }
            
            guard let annotationManager = userAnnotationManager else { return }
            
            // Clear existing user annotations
            annotationManager.annotations = []
            
            // Show user markers at all useful zoom levels - only hide at extreme worldwide zoom
            if zoomLevel < 3.0 {
                print("👥 Hiding user markers at zoom level \(String(format: "%.2f", zoomLevel)) (extreme worldwide view)")
                return
            }
            
            print("👥 Showing user markers at zoom level \(String(format: "%.2f", zoomLevel)) for \(activeUsers.count) users")
            
            // Calculate scale factor for user markers - make them more visible at continental levels
            let userScaleFactor = calculateUserScaleFactor(zoomLevel: zoomLevel)
            
            // Register user profile images with the map style
            registerUserProfileImages(mapView: mapView, activeUsers: activeUsers)
            
            // Add user markers
            for user in activeUsers {
                var annotation = PointAnnotation(coordinate: CLLocationCoordinate2D(
                    latitude: user.location.latitude,
                    longitude: user.location.longitude
                ))
                
                // Use profile picture as marker or fallback to default user icon
                let userImageId = "user_profile_\(user.id)"
                annotation.iconImage = userImageId
                annotation.iconSize = userScaleFactor
                annotation.iconAnchor = .center
                
                // Add subtle glow effect for active users
                if user.activity.status == "very_active" {
                    // Make very active users slightly larger
                    annotation.iconSize = userScaleFactor * 1.2
                }
                
                annotationManager.annotations.append(annotation)
                
                print("👤 Added user marker: \(user.username) (\(user.activity.status)) at (\(user.location.latitude), \(user.location.longitude)) with scale \(String(format: "%.3f", userScaleFactor))")
            }
            
            print("👥 Total user markers added: \(annotationManager.annotations.count)")
        }
        
        private func registerUserProfileImages(mapView: MapboxMaps.MapView, activeUsers: [ActiveUser]) {
            for user in activeUsers {
                let imageId = "user_profile_\(user.id)"
                
                // Try to load user's profile picture, fallback to default user icon
                if let profilePictureUrl = user.profilePictureUrl, !profilePictureUrl.isEmpty, let url = URL(string: profilePictureUrl) {
                    // Load profile picture asynchronously and register with map
                    loadProfilePicture(from: url) { [weak self] profileImage in
                        DispatchQueue.main.async {
                            if let profileImage = profileImage {
                                let circularProfileImage = self?.createCircularProfileImage(from: profileImage, activityStatus: user.activity.status)
                                if let circularImage = circularProfileImage {
                                    try? mapView.mapboxMap.addImage(circularImage, id: imageId)
                                    print("✅ Loaded profile picture for user \(user.username)")
                                }
                            } else {
                                // Fallback to default icon if image loading fails
                                self?.registerDefaultUserIcon(mapView: mapView, imageId: imageId, activityStatus: user.activity.status)
                            }
                        }
                    }
                } else {
                    registerDefaultUserIcon(mapView: mapView, imageId: imageId, activityStatus: user.activity.status)
                }
            }
        }
        
        private func loadProfilePicture(from url: URL, completion: @escaping (UIImage?) -> Void) {
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    print("❌ Failed to load profile picture from \(url): \(error)")
                    completion(nil)
                    return
                }
                
                guard let data = data, let image = UIImage(data: data) else {
                    print("❌ Invalid image data from \(url)")
                    completion(nil)
                    return
                }
                
                completion(image)
            }.resume()
        }
        
        private func createCircularProfileImage(from image: UIImage, activityStatus: String) -> UIImage {
            let size: CGFloat = 32
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
            
            return renderer.image { context in
                let rect = CGRect(x: 0, y: 0, width: size, height: size)
                let cgContext = context.cgContext
                
                // Create circular clipping path
                cgContext.addEllipse(in: rect)
                cgContext.clip()
                
                // Draw the profile image
                image.draw(in: rect)
                
                // Draw activity status border
                cgContext.resetClip()
                let borderColor: UIColor
                let borderWidth: CGFloat = 2.0
                
                switch activityStatus {
                case "very_active":
                    borderColor = .systemGreen
                case "active":
                    borderColor = .systemBlue
                case "recent":
                    borderColor = .systemYellow
                default:
                    borderColor = .systemGray
                }
                
                cgContext.setStrokeColor(borderColor.cgColor)
                cgContext.setLineWidth(borderWidth)
                cgContext.strokeEllipse(in: rect.insetBy(dx: borderWidth/2, dy: borderWidth/2))
            }
        }
        
        private func registerDefaultUserIcon(mapView: MapboxMaps.MapView, imageId: String, activityStatus: String) {
            // Create a circular user icon based on activity status
            let size: CGFloat = 30
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
            
            let userIcon = renderer.image { context in
                let rect = CGRect(x: 0, y: 0, width: size, height: size)
                let cgContext = context.cgContext
                
                // Draw circle background based on activity status
                let backgroundColor: UIColor
                switch activityStatus {
                case "very_active":
                    backgroundColor = .systemGreen
                case "active":
                    backgroundColor = .systemBlue
                case "recent":
                    backgroundColor = .systemYellow
                default:
                    backgroundColor = .systemGray
                }
                
                cgContext.setFillColor(backgroundColor.cgColor)
                cgContext.fillEllipse(in: rect)
                
                // Draw white border
                cgContext.setStrokeColor(UIColor.white.cgColor)
                cgContext.setLineWidth(2.0)
                cgContext.strokeEllipse(in: rect)
                
                // Draw user icon symbol (simplified person icon)
                cgContext.setFillColor(UIColor.white.cgColor)
                
                // Head
                let headRect = CGRect(x: size * 0.35, y: size * 0.2, width: size * 0.3, height: size * 0.3)
                cgContext.fillEllipse(in: headRect)
                
                // Body (simplified)
                let bodyRect = CGRect(x: size * 0.25, y: size * 0.5, width: size * 0.5, height: size * 0.35)
                cgContext.fillEllipse(in: bodyRect)
            }
            
            // Register the icon with the map
            try? mapView.mapboxMap.addImage(userIcon, id: imageId)
        }
    }
}

// Helper extension for distance calculation
extension CLLocationCoordinate2D {
    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
}

// MARK: - Map Header View
struct MapHeaderView: View {
    @Binding var selectedCategory: String
    @Binding var showingSelector: Bool
    @Binding var showingProfile: Bool
    let nearbyUserCount: Int
    let isGlobalView: Bool
    let currentLocationName: String
    let geocodingService: GeocodingService
    let currentZoomLevel: Double
    let onRefreshUsers: (() -> Void)? // Add callback for refreshing users
    
    var body: some View {
        VStack(spacing: 0) {
            // Top header with title and buttons
            HStack {
                // Location selector button with Citizen-style diamond icon
                Button(action: {
                    showingSelector = true
                }) {
                    HStack(spacing: 8) {
                        // Diamond/incidents icon like Citizen
                        Image(systemName: "diamond.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                        
                        Text(selectedCategory)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Search button in gray circle
                    Button(action: {
                        // Search action
                    }) {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                            )
                    }
                    
                    // Notifications button in gray circle with red badge
                    Button(action: {
                        // Notifications action
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white)
                                )
                            
                            // Red notification badge with count
                            Circle()
                                .fill(Color.red)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Text("283")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 12, y: -12)
                        }
                    }
                    
                    // Profile button in gray circle with green dot (moved from news position)
                    Button(action: {
                        showingProfile = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white)
                                )
                            
                            // Green online indicator
                            Circle()
                                .fill(Color.green)
                                .frame(width: 12, height: 12)
                                .offset(x: 12, y: 12)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
            // User count indicator (centered like in Citizen)
            VStack(spacing: 4) {
                // Always show active users count, regardless of zoom level
                Text("\(formatUserCount(nearbyUserCount)) users")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(geocodingService.getHeaderLocationText(zoomLevel: currentZoomLevel))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.gray)
            }
            .padding(.top, 20)
            .onTapGesture {
                // Allow users to tap the user count to force refresh
                print("👥 User tapped on user count - forcing refresh")
                onRefreshUsers?()
            }
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

// MARK: - Loading Indicator
struct LoadingIndicator: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                .scaleEffect(0.8)
            
            Text("Loading locations...")
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Bottom Location Info
struct BottomLocationInfo: View {
    let locations: [AbandonedLocation]
    let userLocation: CLLocationCoordinate2D?
    let currentZoomLevel: Double
    let currentLocationName: String
    let onKeyAlertsPressed: () -> Void
    
    // Calculate recent alerts (last 24 hours)
    private var recentAlertsCount: Int {
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return locations.filter { location in
            location.submissionDate > oneDayAgo
        }.count
    }
    
    // Calculate key alerts (dangerous locations)
    private var keyAlertsCount: Int {
        return locations.filter { location in
            location.danger == .dangerous
        }.count
    }
    
    // Get alert text based on recent activity
    private var alertText: String {
        let count = recentAlertsCount
        if count == 0 {
            return "0 alerts past 1d"
        } else if count == 1 {
            return "1 alert past 1d"
        } else {
            return "\(count) alerts past 1d"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentLocationName)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(alertText)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Only show key alerts button if there are any
                if keyAlertsCount > 0 {
                    Button(action: {
                        onKeyAlertsPressed()
                    }) {
                        HStack(spacing: 8) {
                            Text("Key Alerts")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("\(keyAlertsCount) new")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.black)
        }
    }
}

// MARK: - Location Category Selector
struct LocationCategorySelector: View {
    @Binding var selectedCategory: String
    @Environment(\.dismiss) private var dismiss
    
    private let feedOptions = [
        ("Abandoned", "🏚️", "Explore abandoned buildings and locations"),
        ("Live Feed", "📡", "Real-time incidents and reports"),
        ("Family Alerts", "👥", "Track family members and safety zones"),
        ("Emergency", "🚨", "Emergency incidents and alerts"),
        ("Community", "🏘️", "Local community reports and updates"),
        ("Safety Zones", "🛡️", "Designated safe areas and shelters"),
        ("Historical", "📚", "Historical incidents and locations"),
        ("Weather Alerts", "🌪️", "Weather-related safety information")
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(feedOptions, id: \.0) { option in
                    Button(action: {
                        selectedCategory = option.0
                        dismiss()
                    }) {
                        HStack(spacing: 16) {
                            // Icon circle
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text(option.1)
                                        .font(.title2)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.0)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text(option.2)
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            
                            if selectedCategory == option.0 {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.title2)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.gray.opacity(0.05))
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(PlainListStyle())
            .background(Color.black)
            .navigationTitle("Select Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Error Message View
struct ErrorMessageView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Dismiss") {
                onDismiss()
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                )
        )
        .padding(.horizontal, 40)
    }
}

#Preview {
    MapView()
        .environmentObject(DataManager())
        .environmentObject(LocationManager())
}
