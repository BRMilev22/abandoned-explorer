//
//  APIService.swift
//  upwork-project
//
//  Created by Boris Milev on 23.06.25.
//

import Foundation
import Combine
import UIKit
import CoreLocation

class APIService: ObservableObject {
    static let shared = APIService()
    private let baseURL = APIConfiguration.shared.baseURL
    private var cancellables = Set<AnyCancellable>()
    
    @Published var authToken: String? {
        didSet {
            if let token = authToken {
                UserDefaults.standard.set(token, forKey: "authToken")
                print("APIService: Token saved to UserDefaults: \(token.prefix(20))...")
            } else {
                UserDefaults.standard.removeObject(forKey: "authToken")
                print("APIService: Token removed from UserDefaults")
            }
        }
    }
    
    private init() {
        // Load stored token on initialization
        self.authToken = UserDefaults.standard.string(forKey: "authToken")
        if let token = authToken {
            print("APIService: Loaded token from UserDefaults: \(token.prefix(20))...")
        } else {
            print("APIService: No token found in UserDefaults")
        }
    }
    
    // MARK: - Generic Request Method
    private func makeRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        responseType: T.Type
    ) -> AnyPublisher<T, APIError> {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Disable caching to always get fresh data
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("APIService: Adding Authorization header for \(endpoint)")
        } else {
            print("APIService: No token available for \(endpoint)")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        let decoder = JSONDecoder()
        
        // Custom date decoding to handle MySQL datetime format with milliseconds
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try MySQL datetime format first (2024-12-22 16:30:45)
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            if let date = dateFormatter.date(from: dateString) {
                print("Decoded MySQL date: \(dateString) -> \(date)")
                return date
            }
            
            // Try ISO8601 with milliseconds
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            if let date = dateFormatter.date(from: dateString) {
                print("Decoded ISO8601 with ms: \(dateString) -> \(date)")
                return date
            }
            
            // Try ISO8601 without milliseconds
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            if let date = dateFormatter.date(from: dateString) {
                print("Decoded ISO8601: \(dateString) -> \(date)")
                return date
            }
            
            // Last fallback to ISO8601 decoder
            let iso8601Formatter = ISO8601DateFormatter()
            if let date = iso8601Formatter.date(from: dateString) {
                print("Decoded ISO8601 formatter: \(dateString) -> \(date)")
                return date
            }
            
            print("Failed to decode date: \(dateString)")
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateString)")
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                // Check for HTTP error status codes
                if let httpResponse = output.response as? HTTPURLResponse {
                    print("APIService: HTTP \(httpResponse.statusCode) for \(endpoint)")
                    
                    if httpResponse.statusCode == 304 {
                        // Handle 304 Not Modified - this means content hasn't changed
                        // For now, treat as an error to force fresh request
                        print("APIService: Received 304 Not Modified for \(endpoint) - requesting fresh data")
                        throw APIError.networkError("Content not modified - requesting fresh data")
                    }
                    
                    if httpResponse.statusCode >= 400 {
                        // Try to parse error response
                        if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: output.data) {
                            throw APIError.serverError(errorResponse.error, errorResponse.message)
                        } else {
                            throw APIError.networkError("HTTP \(httpResponse.statusCode)")
                        }
                    }
                }
                return output.data
            }
            .handleEvents(receiveOutput: { data in
                // Log the raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("API Response: \(responseString)")
                }
            })
            .decode(type: T.self, decoder: decoder)
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                } else if let decodingError = error as? DecodingError {
                    print("Decoding error: \(decodingError)")
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("Key '\(key)' not found: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("Type '\(type)' mismatch: \(context.debugDescription)")
                    case .valueNotFound(let value, let context):
                        print("Value '\(value)' not found: \(context.debugDescription)")
                    case .dataCorrupted(let context):
                        print("Data corrupted: \(context.debugDescription)")
                    @unknown default:
                        print("Unknown decoding error")
                    }
                    return APIError.decodingError
                } else {
                    print("Network error: \(error.localizedDescription)")
                    return APIError.networkError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Authentication Methods
    func register(username: String, email: String, password: String, age: Int) -> AnyPublisher<AuthResponse, APIError> {
        let body = RegisterRequest(username: username, email: email, password: password, age: age)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(body) else {
            return Fail(error: APIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return makeRequest(endpoint: "/auth/register", method: .POST, body: data, responseType: AuthResponse.self)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    print("APIService: Registration successful, setting token: \(response.token.prefix(20))...")
                    DispatchQueue.main.async {
                        self?.authToken = response.token
                    }
                },
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("APIService: Registration failed: \(error)")
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    func login(email: String, password: String) -> AnyPublisher<AuthResponse, APIError> {
        let body = LoginRequest(email: email, password: password)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(body) else {
            return Fail(error: APIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return makeRequest(endpoint: "/auth/login", method: .POST, body: data, responseType: AuthResponse.self)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    print("APIService: Login successful, setting token: \(response.token.prefix(20))...")
                    DispatchQueue.main.async {
                        self?.authToken = response.token
                    }
                },
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("APIService: Login failed: \(error)")
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    func logout() {
        DispatchQueue.main.async {
            self.authToken = nil
        }
    }
    
    // MARK: - Location Methods
    func getNearbyLocations(latitude: Double, longitude: Double, radius: Int = 50) -> AnyPublisher<LocationsResponse, APIError> {
        let endpoint = "/locations/nearby?lat=\(latitude)&lng=\(longitude)&radius=\(radius)"
        return makeRequest(endpoint: endpoint, responseType: LocationsResponse.self)
    }
    
    func getAllLocations(limit: Int = 50, offset: Int = 0, userLocation: CLLocationCoordinate2D? = nil) -> AnyPublisher<LocationsResponse, APIError> {
        var endpoint = "/locations/feed?limit=\(limit)&offset=\(offset)"
        
        // Add user location for geographic prioritization
        if let location = userLocation {
            endpoint += "&lat=\(location.latitude)&lng=\(location.longitude)&priority_radius=100"
        }
        
        return makeRequest(endpoint: endpoint, responseType: LocationsResponse.self)
    }
    
    func getLocationById(_ id: String) -> AnyPublisher<AbandonedLocation, APIError> {
        return makeRequest(endpoint: "/locations/\(id)", responseType: AbandonedLocation.self)
    }
    
    func getLocationByIdFromAPI(_ id: Int) -> AnyPublisher<LocationDetailsResponse, APIError> {
        return makeRequest(endpoint: "/locations/\(id)/details", responseType: LocationDetailsResponse.self)
    }
    
    func getLocationByCommentId(_ commentId: Int) -> AnyPublisher<LocationByCommentResponse, APIError> {
        return makeRequest(endpoint: "/locations/by-comment/\(commentId)", responseType: LocationByCommentResponse.self)
    }
    
    func submitLocation(_ location: LocationSubmission) -> AnyPublisher<LocationSubmissionResponse, APIError> {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(location) else {
            return Fail(error: APIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return makeRequest(endpoint: "/locations", method: .POST, body: data, responseType: LocationSubmissionResponse.self)
    }
    
    func likeLocation(_ locationId: Int) -> AnyPublisher<LikeResponse, APIError> {
        return makeRequest(endpoint: "/locations/\(locationId)/like", method: .POST, responseType: LikeResponse.self)
    }
    
    func bookmarkLocation(_ locationId: Int) -> AnyPublisher<BookmarkResponse, APIError> {
        return makeRequest(endpoint: "/locations/\(locationId)/bookmark", method: .POST, responseType: BookmarkResponse.self)
    }
    
    // MARK: - Admin Methods
    
    func getPendingLocations() -> AnyPublisher<LocationsResponse, APIError> {
        return makeRequest(endpoint: "/admin/locations/pending", method: .GET, responseType: PendingLocationsResponse.self)
            .map { response in
                LocationsResponse(locations: response.pendingLocations, hasMore: response.hasMore)
            }
            .eraseToAnyPublisher()
    }
    
    func approveLocation(_ locationId: Int) -> AnyPublisher<AdminActionResponse, APIError> {
        return makeRequest(endpoint: "/admin/locations/\(locationId)/approve", method: .POST, responseType: AdminActionResponse.self)
    }
    
    func rejectLocation(_ locationId: Int) -> AnyPublisher<AdminActionResponse, APIError> {
        return makeRequest(endpoint: "/admin/locations/\(locationId)/reject", method: .POST, responseType: AdminActionResponse.self)
    }
    
    func checkAdminStatus() -> AnyPublisher<AdminStatusResponse, APIError> {
        return makeRequest(endpoint: "/users/admin-status", method: .GET, responseType: AdminStatusResponse.self)
    }
    
    // MARK: - User Methods
    func getCurrentUser() -> AnyPublisher<User, APIError> {
        return makeRequest(endpoint: "/users/profile", responseType: UserProfileResponse.self)
            .map(\.user)
            .eraseToAnyPublisher()
    }
    
    func getUserBookmarks() -> AnyPublisher<LocationsResponse, APIError> {
        return makeRequest(endpoint: "/users/bookmarks", responseType: BookmarksResponse.self)
            .map { response in
                LocationsResponse(locations: response.bookmarks, hasMore: response.hasMore)
            }
            .eraseToAnyPublisher()
    }
    
    func getUserSubmissions() -> AnyPublisher<LocationsResponse, APIError> {
        return makeRequest(endpoint: "/users/submissions", responseType: SubmissionsResponse.self)
            .map { response in
                LocationsResponse(locations: response.submissions, hasMore: response.hasMore)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Dynamic Data Methods
    
    func getCategories() -> AnyPublisher<[DynamicCategory], APIError> {
        return makeRequest(endpoint: "/locations/categories", responseType: CategoriesResponse.self)
            .map(\.categories)
            .eraseToAnyPublisher()
    }
    
    func getDangerLevels() -> AnyPublisher<[DynamicDangerLevel], APIError> {
        return makeRequest(endpoint: "/locations/danger-levels", responseType: DangerLevelsResponse.self)
            .map(\.dangerLevels)
            .eraseToAnyPublisher()
    }
    
    func getTags(popular: Bool = false, limit: Int = 50) -> AnyPublisher<[DynamicTag], APIError> {
        let endpoint = "/locations/tags?popular=\(popular)&limit=\(limit)"
        return makeRequest(endpoint: endpoint, responseType: TagsResponse.self)
            .map(\.tags)
            .eraseToAnyPublisher()
    }
    
    func getLocationStats() -> AnyPublisher<LocationStats, APIError> {
        return makeRequest(endpoint: "/locations/stats", responseType: StatsResponse.self)
            .map(\.stats)
            .eraseToAnyPublisher()
    }
    

    
    // MARK: - Notifications Methods
    
    func getNotifications(unreadOnly: Bool = false, limit: Int = 20, offset: Int = 0) -> AnyPublisher<NotificationsResponse, APIError> {
        let endpoint = "/users/notifications?unread_only=\(unreadOnly)&limit=\(limit)&offset=\(offset)"
        return makeRequest(endpoint: endpoint, responseType: NotificationsResponse.self)
    }
    
    func markNotificationAsRead(_ notificationId: Int) -> AnyPublisher<APISuccessResponse, APIError> {
        return makeRequest(endpoint: "/users/notifications/\(notificationId)/read", method: .POST, responseType: APISuccessResponse.self)
    }
    
    func markAllNotificationsAsRead() -> AnyPublisher<APISuccessResponse, APIError> {
        return makeRequest(endpoint: "/users/notifications/read-all", method: .POST, responseType: APISuccessResponse.self)
    }
    
    // MARK: - User Preferences Methods
    
    func getUserPreferences() -> AnyPublisher<UserPreferences, APIError> {
        return makeRequest(endpoint: "/users/preferences", responseType: PreferencesResponse.self)
            .map(\.preferences)
            .eraseToAnyPublisher()
    }
    
    func updateUserPreferences(_ preferences: UserPreferences) -> AnyPublisher<APISuccessResponse, APIError> {
        let body = try? JSONEncoder().encode(["preferences": preferences])
        return makeRequest(endpoint: "/users/preferences", method: .POST, body: body, responseType: APISuccessResponse.self)
    }
    
    func getVisitedLocations(limit: Int = 20, offset: Int = 0) -> AnyPublisher<VisitedLocationsResponse, APIError> {
        let endpoint = "/users/visited-locations?limit=\(limit)&offset=\(offset)"
        return makeRequest(endpoint: endpoint, responseType: VisitedLocationsResponse.self)
    }
    
    // MARK: - Image Upload Methods
    func uploadImages(for locationId: Int, images: [UIImage]) -> AnyPublisher<ImageUploadResponse, APIError> {
        guard let url = URL(string: "\(baseURL)/upload/images") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set auth header
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add location_id field
        body.append(contentsOf: "--\(boundary)\r\n".data(using: .utf8)!)
        body.append(contentsOf: "Content-Disposition: form-data; name=\"location_id\"\r\n\r\n".data(using: .utf8)!)
        body.append(contentsOf: "\(locationId)\r\n".data(using: .utf8)!)
        
        // Add images
        for (index, image) in images.enumerated() {
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                body.append(contentsOf: "--\(boundary)\r\n".data(using: .utf8)!)
                body.append(contentsOf: "Content-Disposition: form-data; name=\"images\"; filename=\"image_\(index).jpg\"\r\n".data(using: .utf8)!)
                body.append(contentsOf: "Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                body.append(contentsOf: imageData)
                body.append(contentsOf: "\r\n".data(using: .utf8)!)
            }
        }
        
        body.append(contentsOf: "--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                if let response = output.response as? HTTPURLResponse {
                    if response.statusCode == 401 {
                        self.logout()
                        throw APIError.unauthorized
                    }
                    if response.statusCode >= 400 {
                        if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: output.data) {
                            throw APIError.serverError(errorData.error, errorData.message)
                        }
                        throw APIError.serverError("Image upload failed", nil)
                    }
                }
                return output.data
            }
            .decode(type: ImageUploadResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if error is APIError {
                    return error as! APIError
                }
                return APIError.decodingError
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Video Upload Methods
    func uploadVideos(for locationId: Int, videos: [URL]) -> AnyPublisher<VideoUploadResponse, APIError> {
        guard let url = URL(string: "\(baseURL)/upload/videos") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set auth header
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add location_id field
        body.append(contentsOf: "--\(boundary)\r\n".data(using: .utf8)!)
        body.append(contentsOf: "Content-Disposition: form-data; name=\"location_id\"\r\n\r\n".data(using: .utf8)!)
        body.append(contentsOf: "\(locationId)\r\n".data(using: .utf8)!)
        
        // Add videos
        for (index, videoURL) in videos.enumerated() {
            do {
                let videoData = try Data(contentsOf: videoURL)
                let filename = videoURL.lastPathComponent.isEmpty ? "video_\(index).mp4" : videoURL.lastPathComponent
                
                body.append(contentsOf: "--\(boundary)\r\n".data(using: .utf8)!)
                body.append(contentsOf: "Content-Disposition: form-data; name=\"videos\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
                body.append(contentsOf: "Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
                body.append(contentsOf: videoData)
                body.append(contentsOf: "\r\n".data(using: .utf8)!)
            } catch {
                print("❌ Failed to read video data from URL: \(videoURL)")
                // Continue with other videos
            }
        }
        
        body.append(contentsOf: "--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                if let response = output.response as? HTTPURLResponse {
                    if response.statusCode == 401 {
                        self.logout()
                        throw APIError.unauthorized
                    }
                    if response.statusCode >= 400 {
                        if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: output.data) {
                            throw APIError.serverError(errorData.error, errorData.message)
                        }
                        throw APIError.serverError("Video upload failed", nil)
                    }
                }
                return output.data
            }
            .decode(type: VideoUploadResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if error is APIError {
                    return error as! APIError
                }
                return APIError.decodingError
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Active Users Methods
    func getActiveUsers(latitude: Double, longitude: Double, radius: Double = 50.0, activityThreshold: Int = 2) -> AnyPublisher<ActiveUsersResponse, APIError> {
        let endpoint = "/active-users/active-nearby"
        let queryItems = [
            URLQueryItem(name: "latitude", value: "\(latitude)"),
            URLQueryItem(name: "longitude", value: "\(longitude)"),
            URLQueryItem(name: "radius", value: "\(radius)"),
            URLQueryItem(name: "activity_threshold", value: "\(activityThreshold)")
        ]
        
        var urlComponents = URLComponents(string: "\(baseURL)\(endpoint)")
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                if let response = output.response as? HTTPURLResponse {
                    if response.statusCode == 401 {
                        self.logout()
                        throw APIError.unauthorized
                    }
                    if response.statusCode >= 400 {
                        if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: output.data) {
                            throw APIError.serverError(errorData.error, errorData.message)
                        }
                        throw APIError.serverError("Failed to fetch active users", nil)
                    }
                }
                return output.data
            }
            .handleEvents(receiveOutput: { data in
                // Debug: Print the raw JSON response
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("🔍 Active Users Raw JSON Response:")
                    print(jsonString)
                }
            })
            .decode(type: ActiveUsersResponse.self, decoder: JSONDecoder())
            .mapError { error in
                print("🚨 Active Users Decoding Error: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("Key '\(key)' not found: \(context.debugDescription)")
                        print("Available keys: \(context.codingPath)")
                    case .typeMismatch(let type, let context):
                        print("Type '\(type)' mismatch: \(context.debugDescription)")
                        print("Coding path: \(context.codingPath)")
                    case .valueNotFound(let value, let context):
                        print("Value '\(value)' not found: \(context.debugDescription)")
                    case .dataCorrupted(let context):
                        print("Data corrupted: \(context.debugDescription)")
                    @unknown default:
                        print("Unknown decoding error: \(decodingError)")
                    }
                }
                if error is APIError {
                    return error as! APIError
                }
                return APIError.decodingError
            }
            .eraseToAnyPublisher()
    }
    
    func getActiveUsersStats(latitude: Double, longitude: Double, radius: Double = 50.0) -> AnyPublisher<ActiveUsersStatsResponse, APIError> {
        let endpoint = "/active-users/active-stats"
        let queryItems = [
            URLQueryItem(name: "latitude", value: "\(latitude)"),
            URLQueryItem(name: "longitude", value: "\(longitude)"),
            URLQueryItem(name: "radius", value: "\(radius)")
        ]
        
        var urlComponents = URLComponents(string: "\(baseURL)\(endpoint)")
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                if let response = output.response as? HTTPURLResponse {
                    if response.statusCode == 401 {
                        self.logout()
                        throw APIError.unauthorized
                    }
                    if response.statusCode >= 400 {
                        if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: output.data) {
                            throw APIError.serverError(errorData.error, errorData.message)
                        }
                        throw APIError.serverError("Failed to fetch active users stats", nil)
                    }
                }
                return output.data
            }
            .decode(type: ActiveUsersStatsResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if error is APIError {
                    return error as! APIError
                }
                return APIError.decodingError
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Location Update Methods
    func updateUserLocation(latitude: Double, longitude: Double, locationName: String? = nil, accuracyMeters: Int = 1000) -> AnyPublisher<UpdateLocationResponse, APIError> {
        let body = UpdateLocationRequest(
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            accuracyMeters: accuracyMeters
        )
        
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(body) else {
            return Fail(error: APIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return makeRequest(endpoint: "/active-users/update-location", method: .POST, body: data, responseType: UpdateLocationResponse.self)
            .handleEvents(
                receiveOutput: { response in
                    print("APIService: Location updated successfully: \(response.location.latitude), \(response.location.longitude)")
                },
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("APIService: Location update failed: \(error)")
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    // MARK: - Location Details and Comments
    
    func getLocationDetails(locationId: Int) -> AnyPublisher<LocationDetailsResponse, APIError> {
        return makeRequest(endpoint: "/locations/\(locationId)/details", responseType: LocationDetailsResponse.self)
    }
    
    func getLocationComments(locationId: Int, limit: Int = 20, offset: Int = 0) -> AnyPublisher<CommentsResponse, APIError> {
        let endpoint = "/locations/\(locationId)/comments?limit=\(limit)&offset=\(offset)"
        return makeRequest(endpoint: endpoint, responseType: CommentsResponse.self)
    }
    
    func addComment(locationId: Int, commentText: String, parentCommentId: Int? = nil) -> AnyPublisher<AddCommentResponse, APIError> {
        let requestBody = AddCommentRequest(commentText: commentText, parentCommentId: parentCommentId)
        let encoder = JSONEncoder()
        
        guard let data = try? encoder.encode(requestBody) else {
            return Fail(error: APIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return makeRequest(
            endpoint: "/locations/\(locationId)/comments",
            method: .POST,
            body: data,
            responseType: AddCommentResponse.self
        )
    }
    
    func toggleLike(locationId: Int) -> AnyPublisher<ToggleLikeResponse, APIError> {
        return makeRequest(
            endpoint: "/locations/\(locationId)/toggle-like",
            method: .POST,
            responseType: ToggleLikeResponse.self
        )
    }
    
    func toggleBookmark(locationId: Int) -> AnyPublisher<ToggleBookmarkResponse, APIError> {
        return makeRequest(
            endpoint: "/locations/\(locationId)/toggle-bookmark",
            method: .POST,
            responseType: ToggleBookmarkResponse.self
        )
    }
    
    func trackLocationVisit(locationId: Int) -> AnyPublisher<VisitResponse, APIError> {
        return makeRequest(
            endpoint: "/locations/\(locationId)/visit",
            method: .POST,
            responseType: VisitResponse.self
        )
    }
    
    // MARK: - Groups API Methods
    
    func getUserGroups() -> AnyPublisher<GroupsResponse, APIError> {
        return makeRequest(endpoint: "/groups/my-groups", responseType: GroupsResponse.self)
    }
    
    func createGroup(_ request: CreateGroupRequest) -> AnyPublisher<GroupResponse, APIError> {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(request) else {
            return Fail(error: APIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return makeRequest(endpoint: "/groups", method: .POST, body: data, responseType: GroupResponse.self)
    }
    
    func joinGroup(_ request: JoinGroupRequest) -> AnyPublisher<GroupResponse, APIError> {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(request) else {
            return Fail(error: APIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return makeRequest(endpoint: "/groups/join", method: .POST, body: data, responseType: GroupResponse.self)
    }
    
    func getGroupMessages(_ groupId: Int, before: Date? = nil, limit: Int = 50) -> AnyPublisher<GroupMessagesResponse, APIError> {
        var endpoint = "/groups/\(groupId)/messages?limit=\(limit)"
        
        if let before = before {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            endpoint += "&before=\(formatter.string(from: before))"
        }
        
        return makeRequest(endpoint: endpoint, responseType: GroupMessagesResponse.self)
    }
    
    func sendGroupMessage(_ groupId: Int, _ request: SendMessageRequest) -> AnyPublisher<MessageResponse, APIError> {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(request) else {
            return Fail(error: APIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return makeRequest(endpoint: "/groups/\(groupId)/messages", method: .POST, body: data, responseType: MessageResponse.self)
    }
    
    func leaveGroup(_ groupId: Int) -> AnyPublisher<APISuccessResponse, APIError> {
        return makeRequest(endpoint: "/groups/\(groupId)/leave", method: .DELETE, responseType: APISuccessResponse.self)
    }
    
    func shareLocationToGroup(_ groupId: Int, _ request: ShareLocationRequest) -> AnyPublisher<APISuccessResponse, APIError> {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(request) else {
            return Fail(error: APIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return makeRequest(endpoint: "/groups/\(groupId)/share-location", method: .POST, body: data, responseType: APISuccessResponse.self)
    }
    
    func getGroupMembers(_ groupId: Int) -> AnyPublisher<GroupMembersResponse, APIError> {
        return makeRequest(endpoint: "/groups/\(groupId)/members", responseType: GroupMembersResponse.self)
    }
    
    func updateMemberActivity(_ groupId: Int) -> AnyPublisher<APISuccessResponse, APIError> {
        return makeRequest(endpoint: "/groups/\(groupId)/activity", method: .POST, responseType: APISuccessResponse.self)
    }
    
    func likeGroupMessage(_ groupId: Int, messageId: Int) -> AnyPublisher<APISuccessResponse, APIError> {
        return makeRequest(endpoint: "/groups/\(groupId)/messages/\(messageId)/like", method: .POST, responseType: APISuccessResponse.self)
    }
}

// MARK: - HTTP Methods
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// MARK: - API Error Types
enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(String)
    case decodingError
    case encodingError
    case unauthorized
    case serverError(String, String?) // error, message
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError:
            return "Failed to decode response"
        case .encodingError:
            return "Failed to encode request"
        case .unauthorized:
            return "Unauthorized access"
        case .serverError(let error, let message):
            return message ?? error
        }
    }
}

// MARK: - Request/Response Models
struct APIErrorResponse: Codable {
    let error: String
    let message: String?
}

struct RegisterRequest: Codable {
    let username: String
    let email: String
    let password: String
    let age: Int
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct AuthResponse: Codable {
    let message: String?
    let token: String
    let user: User
}

struct LocationsResponse: Codable {
    let locations: [AbandonedLocation]
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case locations
        case hasMore = "has_more"
    }
}

struct LocationSubmission: Codable {
    let title: String
    let description: String
    let latitude: Double
    let longitude: Double
    let address: String
    let categoryId: Int
    let dangerLevelId: Int
    let tags: [String]
    
    enum CodingKeys: String, CodingKey {
        case title, description, latitude, longitude, address, tags
        case categoryId = "category_id"
        case dangerLevelId = "danger_level_id"
    }
}

struct LocationSubmissionResponse: Codable {
    let message: String
    let locationId: Int
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case message
        case locationId = "location_id"
        case status
    }
}

struct LikeResponse: Codable {
    let success: Bool
    let isLiked: Bool
    let likeCount: Int
}

struct BookmarkResponse: Codable {
    let success: Bool
    let isBookmarked: Bool
    let bookmarkCount: Int
}

struct AdminActionResponse: Codable {
    let success: Bool
    let message: String
}

struct AdminStatusResponse: Codable {
    let isAdmin: Bool
    let role: String?
    
    enum CodingKeys: String, CodingKey {
        case isAdmin = "is_admin"
        case role
    }
}

struct UserProfileResponse: Codable {
    let user: User
}

struct BookmarksResponse: Codable {
    let bookmarks: [AbandonedLocation]
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case bookmarks
        case hasMore = "has_more"
    }
}

struct SubmissionsResponse: Codable {
    let submissions: [AbandonedLocation]
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case submissions
        case hasMore = "has_more"
    }
}

struct PendingLocationsResponse: Codable {
    let pendingLocations: [AbandonedLocation]
    let total: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case pendingLocations = "pending_locations"
        case total
        case hasMore = "has_more"
    }
}

struct ImageUploadResponse: Codable {
    let message: String
    let images: [UploadedImage]
    let totalUploaded: Int
    
    enum CodingKeys: String, CodingKey {
        case message, images
        case totalUploaded = "total_uploaded"
    }
}

struct UploadedImage: Codable {
    let url: String
    let thumbnail: String
    let order: Int
}

struct VideoUploadResponse: Codable {
    let message: String
    let videos: [UploadedVideo]
    let totalUploaded: Int
    
    enum CodingKeys: String, CodingKey {
        case message, videos
        case totalUploaded = "total_uploaded"
    }
}

struct UploadedVideo: Codable {
    let url: String
    let thumbnail: String
    let order: Int
}

// MARK: - Active Users Models
struct ActiveUsersResponse: Codable {
    let success: Bool
    let query: ActiveUsersQuery
    let totalCount: Int
    let users: [ActiveUser]
    
    enum CodingKeys: String, CodingKey {
        case success, query, users
        case totalCount = "total_count"
    }
}

struct ActiveUsersQuery: Codable {
    let center: LocationCoordinate
    let radiusKm: Double
    let activityThresholdHours: Int
    
    enum CodingKeys: String, CodingKey {
        case center
        case radiusKm = "radius_km"
        case activityThresholdHours = "activity_threshold_hours"
    }
}

struct LocationCoordinate: Codable {
    let latitude: Double
    let longitude: Double
}

struct ActiveUser: Codable, Identifiable {
    let id: Int
    let username: String
    let isPremium: Bool
    let lastLogin: String
    let profilePictureUrl: String?
    let location: UserLocation
    let activity: UserActivity
    let distanceKm: Double
    
    enum CodingKeys: String, CodingKey {
        case id, username, location, activity
        case isPremium = "is_premium"
        case lastLogin = "last_login"
        case profilePictureUrl = "profile_picture_url"
        case distanceKm = "distance_km"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(Int.self, forKey: .id)
        self.username = try container.decode(String.self, forKey: .username)
        
        // Handle is_premium which might come as number (0/1) or bool
        if let premiumBool = try? container.decode(Bool.self, forKey: .isPremium) {
            self.isPremium = premiumBool
        } else if let premiumInt = try? container.decode(Int.self, forKey: .isPremium) {
            self.isPremium = premiumInt != 0
        } else {
            self.isPremium = false
        }
        
        self.lastLogin = try container.decode(String.self, forKey: .lastLogin)
        self.profilePictureUrl = try container.decodeIfPresent(String.self, forKey: .profilePictureUrl)
        self.location = try container.decode(UserLocation.self, forKey: .location)
        self.activity = try container.decode(UserActivity.self, forKey: .activity)
        
        // Handle distance_km which might come as string or double
        if let distanceDouble = try? container.decode(Double.self, forKey: .distanceKm) {
            self.distanceKm = distanceDouble
        } else if let distanceString = try? container.decode(String.self, forKey: .distanceKm) {
            self.distanceKm = Double(distanceString) ?? 0.0
        } else {
            self.distanceKm = 0.0
        }
    }
}

struct UserLocation: Codable {
    let latitude: Double
    let longitude: Double
    let name: String?
    let accuracyMeters: Int
    
    enum CodingKeys: String, CodingKey {
        case latitude, longitude, name
        case accuracyMeters = "accuracy_meters"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle latitude which might come as string or double
        if let latDouble = try? container.decode(Double.self, forKey: .latitude) {
            self.latitude = latDouble
        } else if let latString = try? container.decode(String.self, forKey: .latitude) {
            self.latitude = Double(latString) ?? 0.0
        } else {
            self.latitude = 0.0
        }
        
        // Handle longitude which might come as string or double
        if let lngDouble = try? container.decode(Double.self, forKey: .longitude) {
            self.longitude = lngDouble
        } else if let lngString = try? container.decode(String.self, forKey: .longitude) {
            self.longitude = Double(lngString) ?? 0.0
        } else {
            self.longitude = 0.0
        }
        
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        
        // Handle accuracy_meters which might come as string or int
        if let accuracyInt = try? container.decode(Int.self, forKey: .accuracyMeters) {
            self.accuracyMeters = accuracyInt
        } else if let accuracyString = try? container.decode(String.self, forKey: .accuracyMeters) {
            self.accuracyMeters = Int(accuracyString) ?? 1000
        } else {
            self.accuracyMeters = 1000
        }
    }
}

struct UserActivity: Codable {
    let minutesSinceLogin: Int
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case minutesSinceLogin = "minutes_since_login"
        case status
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle minutes_since_login which might come as string or int
        if let minutesInt = try? container.decode(Int.self, forKey: .minutesSinceLogin) {
            self.minutesSinceLogin = minutesInt
        } else if let minutesString = try? container.decode(String.self, forKey: .minutesSinceLogin) {
            self.minutesSinceLogin = Int(minutesString) ?? 0
        } else {
            self.minutesSinceLogin = 0
        }
        
        self.status = try container.decode(String.self, forKey: .status)
    }
}

struct UpdateLocationRequest: Codable {
    let latitude: Double
    let longitude: Double
    let locationName: String?
    let accuracyMeters: Int
    
    enum CodingKeys: String, CodingKey {
        case latitude, longitude
        case locationName = "location_name"
        case accuracyMeters = "accuracy_meters"
    }
}

struct UpdateLocationResponse: Codable {
    let success: Bool
    let message: String
    let location: UserLocation
}

struct ActiveUsersStatsResponse: Codable {
    let success: Bool
    let query: ActiveUsersStatsQuery
    let statistics: ActiveUsersStatistics
}

struct ActiveUsersStatsQuery: Codable {
    let center: LocationCoordinate
    let radiusKm: Double
    
    enum CodingKeys: String, CodingKey {
        case center
        case radiusKm = "radius_km"
    }
}

struct ActiveUsersStatistics: Codable {
    let totalUsers: Int
    let veryActive: Int
    let active: Int
    let recent: Int
    let premiumUsers: Int
    
    enum CodingKeys: String, CodingKey {
        case totalUsers = "total_users"
        case veryActive = "very_active"
        case active
        case recent
        case premiumUsers = "premium_users"
    }
}

// MARK: - Location Details and Comments Models

struct LocationDetailsResponse: Codable {
    let success: Bool
    let location: LocationDetails
}

struct LocationDetails: Codable {
    let id: Int
    let title: String
    let description: String?
    let latitude: Double
    let longitude: Double
    let address: String?
    let viewsCount: Int
    let likesCount: Int
    let bookmarksCount: Int
    let commentsCount: Int
    let submissionDate: String
    let featured: Bool
    let categoryName: String?
    let categoryIcon: String?
    let categoryColor: String?
    let dangerLevel: String?
    let dangerColor: String?
    let dangerDescription: String?
    let riskLevel: Int?
    let submittedByUsername: String?
    let submittedByAvatar: String?
    let images: [LocationImage]
    let videos: [LocationVideo]
    let tags: [String]
    let timeline: [TimelineEvent]
    let userInteractions: UserInteractions
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, latitude, longitude, address, featured, tags, timeline, images, videos
        case viewsCount = "views_count"
        case likesCount = "likes_count"
        case bookmarksCount = "bookmarks_count"
        case commentsCount = "comments_count"
        case submissionDate = "submission_date"
        case categoryName = "category_name"
        case categoryIcon = "category_icon"
        case categoryColor = "category_color"
        case dangerLevel = "danger_level"
        case dangerColor = "danger_color"
        case dangerDescription = "danger_description"
        case riskLevel = "risk_level"
        case submittedByUsername = "submitted_by_username"
        case submittedByAvatar = "submitted_by_avatar"
        case userInteractions = "userInteractions"
    }
    
    // Memberwise initializer for direct instantiation
    init(id: Int, title: String, description: String?, latitude: Double, longitude: Double, address: String?, viewsCount: Int, likesCount: Int, bookmarksCount: Int, commentsCount: Int, submissionDate: String, featured: Bool, categoryName: String?, categoryIcon: String?, categoryColor: String?, dangerLevel: String?, dangerColor: String?, dangerDescription: String?, riskLevel: Int?, submittedByUsername: String?, submittedByAvatar: String?, images: [LocationImage], videos: [LocationVideo], tags: [String], timeline: [TimelineEvent], userInteractions: UserInteractions) {
        self.id = id
        self.title = title
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.viewsCount = viewsCount
        self.likesCount = likesCount
        self.bookmarksCount = bookmarksCount
        self.commentsCount = commentsCount
        self.submissionDate = submissionDate
        self.featured = featured
        self.categoryName = categoryName
        self.categoryIcon = categoryIcon
        self.categoryColor = categoryColor
        self.dangerLevel = dangerLevel
        self.dangerColor = dangerColor
        self.dangerDescription = dangerDescription
        self.riskLevel = riskLevel
        self.submittedByUsername = submittedByUsername
        self.submittedByAvatar = submittedByAvatar
        self.images = images
        self.videos = videos
        self.tags = tags
        self.timeline = timeline
        self.userInteractions = userInteractions
    }
    
    // Custom initializer to handle latitude/longitude as strings
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        
        // Handle latitude - try string first, then double
        if let latString = try? container.decode(String.self, forKey: .latitude) {
            latitude = Double(latString) ?? 0.0
        } else {
            latitude = try container.decode(Double.self, forKey: .latitude)
        }
        
        // Handle longitude - try string first, then double
        if let lngString = try? container.decode(String.self, forKey: .longitude) {
            longitude = Double(lngString) ?? 0.0
        } else {
            longitude = try container.decode(Double.self, forKey: .longitude)
        }
        
        address = try container.decodeIfPresent(String.self, forKey: .address)
        viewsCount = try container.decode(Int.self, forKey: .viewsCount)
        likesCount = try container.decode(Int.self, forKey: .likesCount)
        bookmarksCount = try container.decode(Int.self, forKey: .bookmarksCount)
        commentsCount = try container.decode(Int.self, forKey: .commentsCount)
        submissionDate = try container.decode(String.self, forKey: .submissionDate)
        
        // Handle featured as either Bool or Int
        if let featuredBool = try? container.decode(Bool.self, forKey: .featured) {
            featured = featuredBool
        } else if let featuredInt = try? container.decode(Int.self, forKey: .featured) {
            featured = featuredInt == 1
        } else {
            featured = false
        }
        
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
        categoryIcon = try container.decodeIfPresent(String.self, forKey: .categoryIcon)
        categoryColor = try container.decodeIfPresent(String.self, forKey: .categoryColor)
        dangerLevel = try container.decodeIfPresent(String.self, forKey: .dangerLevel)
        dangerColor = try container.decodeIfPresent(String.self, forKey: .dangerColor)
        dangerDescription = try container.decodeIfPresent(String.self, forKey: .dangerDescription)
        riskLevel = try container.decodeIfPresent(Int.self, forKey: .riskLevel)
        submittedByUsername = try container.decodeIfPresent(String.self, forKey: .submittedByUsername)
        submittedByAvatar = try container.decodeIfPresent(String.self, forKey: .submittedByAvatar)
        images = try container.decode([LocationImage].self, forKey: .images)
        videos = try container.decodeIfPresent([LocationVideo].self, forKey: .videos) ?? []
        tags = try container.decode([String].self, forKey: .tags)
        timeline = try container.decode([TimelineEvent].self, forKey: .timeline)
        userInteractions = try container.decode(UserInteractions.self, forKey: .userInteractions)
    }
}

struct LocationImage: Codable, Hashable {
    let imageUrl: String
    let thumbnailUrl: String?
    let caption: String?
    
    enum CodingKeys: String, CodingKey {
        case imageUrl = "image_url"
        case thumbnailUrl = "thumbnail_url"
        case caption
    }
}

struct LocationVideo: Codable, Hashable {
    let videoUrl: String
    let thumbnailUrl: String?
    let caption: String?
    
    enum CodingKeys: String, CodingKey {
        case videoUrl = "video_url"
        case thumbnailUrl = "thumbnail_url"
        case caption
    }
}

struct TimelineEvent: Codable {
    let eventType: String
    let timestamp: String
    let description: String
    let username: String?
    let avatar: String?
    
    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case timestamp, description, username, avatar
    }
}

struct UserInteractions: Codable {
    let isLiked: Bool
    let isBookmarked: Bool
    let hasVisited: Bool
    
    enum CodingKeys: String, CodingKey {
        case isLiked, isBookmarked, hasVisited
    }
}

struct CommentsResponse: Codable {
    let success: Bool
    let comments: [Comment]
    let pagination: CommentPagination
}

struct Comment: Codable, Identifiable {
    let id: Int
    let commentText: String
    let likesCount: Int
    let createdAt: String
    let updatedAt: String
    let parentCommentId: Int?
    let userId: Int
    let username: String
    let avatar: String?
    let replyCount: Int?
    let replies: [Comment]?
    
    enum CodingKeys: String, CodingKey {
        case id, username, avatar, replies
        case commentText = "comment_text"
        case likesCount = "likes_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case parentCommentId = "parent_comment_id"
        case userId = "user_id"
        case replyCount = "reply_count"
    }
}

struct CommentPagination: Codable {
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case total, limit, offset
        case hasMore = "hasMore"
    }
}

struct AddCommentRequest: Codable {
    let commentText: String
    let parentCommentId: Int?
    
    enum CodingKeys: String, CodingKey {
        case commentText = "comment_text"
        case parentCommentId = "parent_comment_id"
    }
}

struct AddCommentResponse: Codable {
    let success: Bool
    let message: String
    let comment: Comment
}

struct ToggleLikeResponse: Codable {
    let success: Bool
    let message: String
    let isLiked: Bool
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case isLiked = "isLiked"
    }
}

struct ToggleBookmarkResponse: Codable {
    let success: Bool
    let message: String
    let isBookmarked: Bool
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case isBookmarked = "isBookmarked"
    }
}

struct LocationByCommentResponse: Codable {
    let success: Bool
    let location: AbandonedLocation
    let commentId: Int
    
    enum CodingKeys: String, CodingKey {
        case success, location
        case commentId = "comment_id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        success = try container.decode(Bool.self, forKey: .success)
        location = try container.decode(AbandonedLocation.self, forKey: .location)
        
        // Handle commentId which might come as string or int
        if let commentIdInt = try? container.decode(Int.self, forKey: .commentId) {
            commentId = commentIdInt
        } else if let commentIdString = try? container.decode(String.self, forKey: .commentId) {
            commentId = Int(commentIdString) ?? 0
        } else {
            commentId = 0
        }
    }
}
