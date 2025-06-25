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
    
    var category: LocationCategory {
        LocationCategory(rawValue: categoryName) ?? .other
    }
    
    var danger: DangerLevel {
        DangerLevel(rawValue: dangerLevel) ?? .safe
    }
    
    // Custom coding keys to match API response
    enum CodingKeys: String, CodingKey {
        case id, title, description, latitude, longitude, address, tags, images
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
    init(id: Int, title: String, description: String, latitude: Double, longitude: Double, address: String, tags: [String] = [], images: [String] = [], submittedBy: Int? = nil, submittedByUsername: String? = nil, submissionDate: Date = Date(), likeCount: Int = 0, bookmarkCount: Int = 0, isBookmarked: Bool = false, isLiked: Bool = false, isApproved: Bool = false, categoryName: String, dangerLevel: String) {
        self.id = id
        self.title = title
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.tags = tags
        self.images = images
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
