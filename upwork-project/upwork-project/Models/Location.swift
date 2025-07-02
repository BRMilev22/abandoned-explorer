//
//  Location.swift
//  upwork-project
//
//  Created by Boris Milev on 22.06.25.
//

import Foundation
import CoreLocation

struct AbandonedLocation: Identifiable, Codable, Equatable {
    var id: Int
    var title: String
    var description: String
    var latitude: Double
    var longitude: Double
    var address: String
    var tags: [String]
    var images: [String] // URLs or local image names
    var videos: [String] // Video URLs
    var submittedBy: Int?
    var submittedByUsername: String?
    var submissionDate: Date
    var likeCount: Int
    var bookmarkCount: Int
    var isBookmarked: Bool
    var isLiked: Bool
    var isApproved: Bool
    var categoryName: String
    var dangerLevel: String
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // Computed property to get images with corrected URLs for iOS simulator
    var displayImages: [String] {
        return images.map { imageUrl in
            // Replace localhost with machine IP for iOS simulator
            if imageUrl.contains("localhost:3000") {
                return imageUrl.replacingOccurrences(of: "localhost:3000", with: "192.168.0.116:3000")
            }
            return imageUrl
        }
    }
    
    // Computed property to get videos with corrected URLs for iOS simulator
    var displayVideos: [String] {
        return videos.map { videoUrl in
            // Replace localhost with machine IP for iOS simulator
            if videoUrl.contains("localhost:3000") {
                return videoUrl.replacingOccurrences(of: "localhost:3000", with: "192.168.0.116:3000")
            }
            return videoUrl
        }
    }
    
    var category: LocationCategory {
        LocationCategory(rawValue: categoryName) ?? .other
    }
    
    var danger: DangerLevel {
        DangerLevel(rawValue: dangerLevel) ?? .safe
    }
    
    // Custom coding keys to match API response
    enum CodingKeys: String, CodingKey {
        case id, title, description, latitude, longitude, address, tags, images, videos
        case submittedBy = "submitted_by"
        case submittedByUsername = "submitted_by_username"
        case submissionDate = "created_at"
        case bookmarkedAt = "bookmarked_at"
        case likeCount = "like_count"
        case bookmarkCount = "bookmark_count"
        case isBookmarked = "is_bookmarked"
        case isLiked = "is_liked"
        case isApproved = "is_approved"
        case categoryName = "category_name"
        case dangerLevel = "danger_level"
    }
    
    // Custom initializer to handle type conversions
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        
        // Handle latitude and longitude as strings that need to be converted to Double
        if let latString = try? container.decode(String.self, forKey: .latitude) {
            latitude = Double(latString) ?? 0.0
        } else {
            latitude = try container.decode(Double.self, forKey: .latitude)
        }
        
        if let lngString = try? container.decode(String.self, forKey: .longitude) {
            longitude = Double(lngString) ?? 0.0
        } else {
            longitude = try container.decode(Double.self, forKey: .longitude)
        }
        
        address = try container.decode(String.self, forKey: .address)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        images = try container.decodeIfPresent([String].self, forKey: .images) ?? []
        videos = try container.decodeIfPresent([String].self, forKey: .videos) ?? []
        
        // Handle submittedBy - could be Int (user ID) or String (username in admin endpoints)
        submittedBy = try? container.decode(Int.self, forKey: .submittedBy)
        submittedByUsername = try? container.decode(String.self, forKey: .submittedByUsername)
        
        // If no username is provided but we have a string in submitted_by, use that
        if submittedByUsername == nil, let usernameFromSubmittedBy = try? container.decode(String.self, forKey: .submittedBy) {
            submittedByUsername = usernameFromSubmittedBy
            submittedBy = nil
        }
        
        // Handle submissionDate - try both created_at and bookmarked_at
        if let createdAt = try? container.decode(Date.self, forKey: .submissionDate) {
            submissionDate = createdAt
        } else if let bookmarkedAt = try? container.decode(Date.self, forKey: .bookmarkedAt) {
            submissionDate = bookmarkedAt
        } else {
            // Fallback to current date if neither is available
            submissionDate = Date()
        }
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        bookmarkCount = try container.decodeIfPresent(Int.self, forKey: .bookmarkCount) ?? 0
        
        // Handle is_bookmarked as either Bool or Int (database returns 0/1)
        if let bookmarkedBool = try? container.decode(Bool.self, forKey: .isBookmarked) {
            isBookmarked = bookmarkedBool
        } else if let bookmarkedInt = try? container.decode(Int.self, forKey: .isBookmarked) {
            isBookmarked = bookmarkedInt == 1
        } else {
            isBookmarked = false
        }
        
        // Handle is_liked as either Bool or Int (database returns 0/1)
        if let likedBool = try? container.decode(Bool.self, forKey: .isLiked) {
            isLiked = likedBool
        } else if let likedInt = try? container.decode(Int.self, forKey: .isLiked) {
            isLiked = likedInt == 1
        } else {
            isLiked = false
        }
        
        // Handle is_approved as either Bool or Int (database returns 0/1)
        // For bookmarks, this field might not be present, so default to true
        if let approvedBool = try? container.decode(Bool.self, forKey: .isApproved) {
            isApproved = approvedBool
        } else if let approvedInt = try? container.decode(Int.self, forKey: .isApproved) {
            isApproved = approvedInt == 1
        } else {
            // Default to true for feed/bookmarks endpoints since they already filter for approved locations
            isApproved = true
        }
        
        categoryName = try container.decode(String.self, forKey: .categoryName)
        dangerLevel = try container.decode(String.self, forKey: .dangerLevel)
    }
    
    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(address, forKey: .address)
        try container.encode(tags, forKey: .tags)
        try container.encode(images, forKey: .images)
        try container.encode(videos, forKey: .videos)
        try container.encodeIfPresent(submittedBy, forKey: .submittedBy)
        try container.encodeIfPresent(submittedByUsername, forKey: .submittedByUsername)
        try container.encode(submissionDate, forKey: .submissionDate)
        try container.encode(likeCount, forKey: .likeCount)
        try container.encode(bookmarkCount, forKey: .bookmarkCount)
        try container.encode(isBookmarked, forKey: .isBookmarked)
        try container.encode(isLiked, forKey: .isLiked)
        try container.encode(isApproved, forKey: .isApproved)
        try container.encode(categoryName, forKey: .categoryName)
        try container.encode(dangerLevel, forKey: .dangerLevel)
    }
    
    // Convenience initializer for testing/previews
    init(id: Int, title: String, description: String, latitude: Double, longitude: Double, address: String, tags: [String] = [], images: [String] = [], videos: [String] = [], submittedBy: Int? = nil, submittedByUsername: String? = nil, submissionDate: Date = Date(), likeCount: Int = 0, bookmarkCount: Int = 0, isBookmarked: Bool = false, isLiked: Bool = false, isApproved: Bool = false, categoryName: String, dangerLevel: String) {
        self.id = id
        self.title = title
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.tags = tags
        self.images = images
        self.videos = videos
        self.submittedBy = submittedBy
        self.submittedByUsername = submittedByUsername
        self.submissionDate = submissionDate
        self.likeCount = likeCount
        self.bookmarkCount = bookmarkCount
        self.isBookmarked = isBookmarked
        self.isLiked = isLiked
        self.isApproved = isApproved
        self.categoryName = categoryName
        self.dangerLevel = dangerLevel
    }
}

enum LocationCategory: String, CaseIterable, Codable {
    case hospital = "Hospital"
    case factory = "Factory"
    case school = "School"
    case house = "House"
    case mall = "Mall"
    case church = "Church"
    case theater = "Theater"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .hospital: return "HospitalIcon" // Custom realistic hospital icon
        case .factory: return "FactoryIcon" // Custom realistic factory icon  
        case .school: return "SchoolIcon" // Custom realistic school icon
        case .house: return "HouseIcon" // Custom realistic house icon
        case .mall: return "MallIcon" // Custom realistic mall icon
        case .church: return "ChurchIcon" // Custom realistic church icon
        case .theater: return "TheaterIcon" // Custom realistic theater icon
        case .other: return "OtherIcon" // Custom realistic other/unknown icon
        }
    }
    
    var id: Int {
        switch self {
        case .hospital: return 1
        case .factory: return 2
        case .school: return 3
        case .house: return 4
        case .mall: return 5
        case .church: return 6
        case .theater: return 7
        case .other: return 8
        }
    }
}

enum DangerLevel: String, CaseIterable, Codable {
    case safe = "Safe"
    case caution = "Caution"
    case dangerous = "Dangerous"
    
    var color: String {
        switch self {
        case .safe: return "green"
        case .caution: return "yellow"
        case .dangerous: return "red"
        }
    }
    
    var id: Int {
        switch self {
        case .safe: return 1
        case .caution: return 2
        case .dangerous: return 3
        }
    }
}

// MARK: - Dynamic Data Models

struct DynamicCategory: Identifiable, Codable, Equatable {
    let id: Int
    let name: String
    let icon: String
    let description: String?
    let color: String
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, icon, description, color
        case isActive = "is_active"
    }
}

struct DynamicDangerLevel: Identifiable, Codable, Equatable {
    let id: Int
    let name: String
    let color: String
    let description: String?
    let riskLevel: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, color, description
        case riskLevel = "risk_level"
    }
}

struct DynamicTag: Identifiable, Codable, Equatable {
    let id: Int
    let name: String
    let usageCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case usageCount = "usage_count"
    }
}

struct LocationNotification: Identifiable, Codable {
    let id: Int
    let title: String
    let message: String
    let type: NotificationType
    let relatedType: String?
    let relatedId: Int?
    let isRead: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, message, type
        case relatedType = "related_type"
        case relatedId = "related_id"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

enum NotificationType: String, Codable, CaseIterable {
    case like = "like"
    case comment = "comment"
    case bookmark = "bookmark"
    case approval = "approval"
    case rejection = "rejection"
    case submission = "submission"
    case reply = "reply"
    case visit = "visit"
    case system = "system"
    case follow = "follow"
    case mention = "mention"
    
    // Group-related notification types
    case groupJoin = "group_join"
    case groupLeave = "group_leave"
    case groupInvite = "group_invite"
    case groupKick = "group_kick"
    case groupBan = "group_ban"
    case groupMessage = "group_message"
    case groupPromotion = "group_promotion"
    case groupDemotion = "group_demotion"
    
    var icon: String {
        switch self {
        case .like: return "heart.fill"
        case .comment: return "message.fill"
        case .bookmark: return "bookmark.fill"
        case .approval: return "checkmark.seal.fill"
        case .rejection: return "xmark.seal.fill"
        case .submission: return "paperplane.fill"
        case .reply: return "arrowshape.turn.up.left.fill"
        case .visit: return "location.fill"
        case .system: return "gear.fill"
        case .follow: return "person.badge.plus.fill"
        case .mention: return "at.badge.plus"
        
        // Group-related icons
        case .groupJoin: return "person.badge.plus"
        case .groupLeave: return "person.badge.minus"
        case .groupInvite: return "envelope.badge"
        case .groupKick: return "person.crop.circle.badge.xmark"
        case .groupBan: return "person.crop.circle.badge.exclamationmark"
        case .groupMessage: return "message.badge"
        case .groupPromotion: return "arrow.up.circle.badge.clock"
        case .groupDemotion: return "arrow.down.circle.badge.clock"
        }
    }
    
    var color: String {
        switch self {
        case .like: return "red"
        case .comment: return "blue"
        case .bookmark: return "orange"
        case .approval: return "green"
        case .rejection: return "red"
        case .submission: return "blue"
        case .reply: return "purple"
        case .visit: return "indigo"
        case .system: return "gray"
        case .follow: return "green"
        case .mention: return "yellow"
        
        // Group-related colors
        case .groupJoin: return "green"
        case .groupLeave: return "orange"
        case .groupInvite: return "blue"
        case .groupKick: return "red"
        case .groupBan: return "red"
        case .groupMessage: return "blue"
        case .groupPromotion: return "green"
        case .groupDemotion: return "orange"
        }
    }
    
    var displayName: String {
        switch self {
        case .like: return "Like"
        case .comment: return "Comment"
        case .bookmark: return "Bookmark"
        case .approval: return "Approved"
        case .rejection: return "Rejected"
        case .submission: return "Submitted"
        case .reply: return "Reply"
        case .visit: return "Visit"
        case .system: return "System"
        case .follow: return "Follow"
        case .mention: return "Mention"
        
        // Group-related display names
        case .groupJoin: return "Joined Group"
        case .groupLeave: return "Left Group"
        case .groupInvite: return "Group Invite"
        case .groupKick: return "Removed from Group"
        case .groupBan: return "Banned from Group"
        case .groupMessage: return "Group Message"
        case .groupPromotion: return "Group Promotion"
        case .groupDemotion: return "Group Demotion"
        }
    }
}

struct UserPreferences: Codable {
    var notificationsEnabled: Bool = true
    var pushNotificationsEnabled: Bool = true
    var locationTrackingEnabled: Bool = true
    var showDangerousLocations: Bool = true
    var preferredCategories: [Int] = []
    var mapStyle: String = "standard"
    var autoPlayVideos: Bool = false
    var shareLocationData: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case notificationsEnabled = "notifications_enabled"
        case pushNotificationsEnabled = "push_notifications_enabled"
        case locationTrackingEnabled = "location_tracking_enabled"
        case showDangerousLocations = "show_dangerous_locations"
        case preferredCategories = "preferred_categories"
        case mapStyle = "map_style"
        case autoPlayVideos = "auto_play_videos"
        case shareLocationData = "share_location_data"
    }
}

struct LocationStats: Codable {
    let totals: TotalStats
    let categories: [CategoryStats]
    let dangerLevels: [DangerLevelStats]
}

struct TotalStats: Codable {
    let totalLocations: Int
    let approvedLocations: Int
    let pendingLocations: Int
    let totalLikes: Int
    let totalBookmarks: Int
    let totalViews: Int
    
    enum CodingKeys: String, CodingKey {
        case totalLocations = "total_locations"
        case approvedLocations = "approved_locations"
        case pendingLocations = "pending_locations"
        case totalLikes = "total_likes"
        case totalBookmarks = "total_bookmarks"
        case totalViews = "total_views"
    }
}

struct CategoryStats: Codable {
    let categoryName: String
    let categoryIcon: String
    let categoryColor: String
    let locationCount: Int
    
    enum CodingKeys: String, CodingKey {
        case categoryName = "category_name"
        case categoryIcon = "category_icon"
        case categoryColor = "category_color"
        case locationCount = "location_count"
    }
}

struct DangerLevelStats: Codable {
    let dangerLevel: String
    let dangerColor: String
    let locationCount: Int
    
    enum CodingKeys: String, CodingKey {
        case dangerLevel = "danger_level"
        case dangerColor = "danger_color"
        case locationCount = "location_count"
    }
}

// MARK: - API Response Models

struct CategoriesResponse: Codable {
    let success: Bool
    let categories: [DynamicCategory]
}

struct DangerLevelsResponse: Codable {
    let success: Bool
    let dangerLevels: [DynamicDangerLevel]
}

struct TagsResponse: Codable {
    let success: Bool
    let tags: [DynamicTag]
}

struct NotificationsResponse: Codable {
    let success: Bool
    let notifications: [LocationNotification]
    let unreadCount: Int
    let hasMore: Bool
}

struct PreferencesResponse: Codable {
    let success: Bool
    let preferences: UserPreferences
}

struct StatsResponse: Codable {
    let success: Bool
    let stats: LocationStats
}

struct VisitedLocationsResponse: Codable {
    let success: Bool
    let visitedLocations: [AbandonedLocation]
    let hasMore: Bool
}

struct VisitResponse: Codable {
    let success: Bool
    let message: String
    let viewCount: Int
}

// Additional API response types
struct APISuccessResponse: Codable {
    let success: Bool
    let message: String?
}
