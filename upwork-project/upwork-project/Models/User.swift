//
//  User.swift
//  upwork-project
//
//  Created by Boris Milev on 22.06.25.
//

import Foundation

struct User: Identifiable, Codable {
    var id: Int
    var username: String
    var email: String
    var age: Int?
    var preferences: [String]? // Category names as strings
    var isPremium: Bool
    var joinDate: Date
    var profileImageURL: String?
    var submittedLocations: Int?
    var approvedLocations: Int?
    var bookmarkedLocations: Int?
    var likedLocations: Int?
    
    // Custom coding keys to match API response
    enum CodingKeys: String, CodingKey {
        case id, username, email, age, preferences
        case isPremium = "is_premium"
        case joinDate = "created_at"
        case profileImageURL = "profile_image_url"
        case submittedLocations = "submitted_locations"
        case approvedLocations = "approved_locations"
        case bookmarkedLocations = "bookmarked_locations"
        case likedLocations = "liked_locations"
    }
    
    // Custom initializer to handle missing fields and type conversions
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        email = try container.decode(String.self, forKey: .email)
        age = try container.decodeIfPresent(Int.self, forKey: .age)
        preferences = try container.decodeIfPresent([String].self, forKey: .preferences) ?? []
        
        // Handle is_premium as either Bool or Int (database returns 0/1)
        if let premiumBool = try? container.decode(Bool.self, forKey: .isPremium) {
            isPremium = premiumBool
        } else if let premiumInt = try? container.decode(Int.self, forKey: .isPremium) {
            isPremium = premiumInt == 1
        } else {
            isPremium = false
        }
        
        joinDate = try container.decode(Date.self, forKey: .joinDate)
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        
        // Handle count fields that come as strings from the API
        if let submittedString = try? container.decode(String.self, forKey: .submittedLocations) {
            submittedLocations = Int(submittedString) ?? 0
        } else {
            submittedLocations = try container.decodeIfPresent(Int.self, forKey: .submittedLocations) ?? 0
        }
        
        if let approvedString = try? container.decode(String.self, forKey: .approvedLocations) {
            approvedLocations = Int(approvedString) ?? 0
        } else {
            approvedLocations = try container.decodeIfPresent(Int.self, forKey: .approvedLocations) ?? 0
        }
        
        if let bookmarkedString = try? container.decode(String.self, forKey: .bookmarkedLocations) {
            bookmarkedLocations = Int(bookmarkedString) ?? 0
        } else {
            bookmarkedLocations = try container.decodeIfPresent(Int.self, forKey: .bookmarkedLocations) ?? 0
        }
        
        if let likedString = try? container.decode(String.self, forKey: .likedLocations) {
            likedLocations = Int(likedString) ?? 0
        } else {
            likedLocations = try container.decodeIfPresent(Int.self, forKey: .likedLocations) ?? 0
        }
    }
    
    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(age, forKey: .age)
        try container.encodeIfPresent(preferences, forKey: .preferences)
        try container.encode(isPremium, forKey: .isPremium)
        try container.encode(joinDate, forKey: .joinDate)
        try container.encodeIfPresent(profileImageURL, forKey: .profileImageURL)
        try container.encodeIfPresent(submittedLocations, forKey: .submittedLocations)
        try container.encodeIfPresent(approvedLocations, forKey: .approvedLocations)
        try container.encodeIfPresent(bookmarkedLocations, forKey: .bookmarkedLocations)
        try container.encodeIfPresent(likedLocations, forKey: .likedLocations)
    }
    
    // Convenience initializer for testing/previews
    init(id: Int, username: String, email: String, age: Int? = nil, preferences: [String]? = nil, isPremium: Bool = false, joinDate: Date = Date(), profileImageURL: String? = nil, submittedLocations: Int? = 0, approvedLocations: Int? = 0, bookmarkedLocations: Int? = 0, likedLocations: Int? = 0) {
        self.id = id
        self.username = username
        self.email = email
        self.age = age
        self.preferences = preferences
        self.isPremium = isPremium
        self.joinDate = joinDate
        self.profileImageURL = profileImageURL
        self.submittedLocations = submittedLocations
        self.approvedLocations = approvedLocations
        self.bookmarkedLocations = bookmarkedLocations
        self.likedLocations = likedLocations
    }
}
