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

class DataManager: ObservableObject {
    @Published var locations: [AbandonedLocation] = []
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
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Prevent duplicate API calls
    private var isLoadingUser = false
    private var isCheckingAdminStatus = false
    private var isLoadingPendingLocations = false
    
    // Rate limiting for location requests
    private var lastLocationRequest = Date()
    private let locationRequestThreshold: TimeInterval = 1.0 // Minimum 1 second between requests
    private var isLoadingLocations = false
    
    init() {
        setupBindings()
        checkAuthenticationStatus()
        // Always load public locations on app start
        loadAllLocations()
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
                    } else {
                        // Clear user data on logout
                        self?.currentUser = nil
                        self?.isAdmin = false
                        self?.userBookmarks = []
                        self?.userSubmissions = []
                        self?.pendingLocations = []
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
    
    func loadAllLocations() {
        // Prevent duplicate requests and rate limiting
        let now = Date()
        guard !isLoadingLocations && now.timeIntervalSince(lastLocationRequest) >= locationRequestThreshold else {
            print("⏸️ Throttling location request - too soon or already loading")
            return
        }
        
        isLoadingLocations = true
        isLoading = true
        errorMessage = nil
        lastLocationRequest = now
        
        apiService.getAllLocations()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    self?.isLoadingLocations = false
                    if case .failure(let error) = completion {
                        // Handle rate limiting specifically
                        if error.localizedDescription.contains("429") {
                            self?.errorMessage = "Too many requests. Please wait a moment and try again."
                            print("🚫 Rate limited - backing off for 5 seconds")
                            // Automatically retry after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                self?.errorMessage = nil
                            }
                        } else {
                            self?.errorMessage = error.localizedDescription
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    self?.locations = response.locations
                    self?.errorMessage = nil // Clear any previous errors on success
                    // Preload images for the loaded locations
                    self?.preloadImages(for: response.locations)
                }
            )
            .store(in: &cancellables)
    }
    
    func loadNearbyLocations(latitude: Double, longitude: Double, radius: Int = 50) {
        // Prevent duplicate requests and rate limiting
        let now = Date()
        guard !isLoadingLocations && now.timeIntervalSince(lastLocationRequest) >= locationRequestThreshold else {
            print("⏸️ Throttling nearby location request - too soon or already loading")
            return
        }
        
        isLoadingLocations = true
        isLoading = true
        errorMessage = nil
        lastLocationRequest = now
        
        apiService.getNearbyLocations(latitude: latitude, longitude: longitude, radius: radius)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    self?.isLoadingLocations = false
                    if case .failure(let error) = completion {
                        // Handle rate limiting specifically
                        if error.localizedDescription.contains("429") {
                            self?.errorMessage = "Too many requests. Please wait a moment and try again."
                            print("🚫 Rate limited - backing off for 5 seconds")
                            // Automatically retry after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                self?.errorMessage = nil
                            }
                        } else {
                            self?.errorMessage = error.localizedDescription
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    self?.locations = response.locations
                    self?.errorMessage = nil // Clear any previous errors on success
                    // Preload images for the loaded locations
                    self?.preloadImages(for: response.locations)
                }
            )
            .store(in: &cancellables)
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
        images: [UIImage] = []
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
                    
                    // If we have images, upload them
                    if !images.isEmpty {
                        self?.uploadImages(for: response.locationId, images: images)
                    } else {
                        // No images to upload, we're done
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
        
        apiService.bookmarkLocation(locationId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    // Update the local location data
                    if let index = self?.locations.firstIndex(where: { $0.id == locationId }) {
                        self?.locations[index].isBookmarked = response.isBookmarked
                        self?.locations[index].bookmarkCount = response.bookmarkCount
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
        
        apiService.likeLocation(locationId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    // Update the local location data
                    if let index = self?.locations.firstIndex(where: { $0.id == locationId }) {
                        self?.locations[index].isLiked = response.isLiked
                        self?.locations[index].likeCount = response.likeCount
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
}
