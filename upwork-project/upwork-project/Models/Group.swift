//
//  Group.swift
//  upwork-project
//
//  Created by Boris Milev on 30.06.25.
//

import Foundation
import SwiftUI

// MARK: - Group Models

struct Group: Identifiable, Codable, Equatable {
    let id: Int
    let uuid: String?
    let name: String
    let description: String?
    let inviteCode: String
    let createdBy: Int
    let isPrivate: Bool
    let memberLimit: Int
    let avatarColor: String
    let emoji: String
    let region: String
    let points: Int
    let createdAt: Date
    let updatedAt: Date
    let creatorUsername: String?
    let memberCount: Int
    let myRole: GroupRole?
    let myJoinedAt: Date?
    let lastActivity: Date?
    let activeMembers: Int
    
    enum CodingKeys: String, CodingKey {
        case id, uuid, name, description
        case inviteCode = "invite_code"
        case createdBy = "created_by"
        case isPrivate = "is_private"
        case memberLimit = "member_limit"
        case avatarColor = "avatar_color"
        case emoji, region, points
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case creatorUsername = "creator_username"
        case memberCount = "member_count"
        case myRole = "my_role"
        case myJoinedAt = "my_joined_at"
        case lastActivity = "last_activity"
        case activeMembers = "active_members"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        inviteCode = try container.decode(String.self, forKey: .inviteCode)
        createdBy = try container.decode(Int.self, forKey: .createdBy)
        
        // Handle isPrivate - can be Bool or Int (MySQL TINYINT)
        if let boolValue = try? container.decode(Bool.self, forKey: .isPrivate) {
            isPrivate = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isPrivate) {
            isPrivate = intValue != 0
        } else {
            isPrivate = false
        }
        
        memberLimit = try container.decode(Int.self, forKey: .memberLimit)
        avatarColor = try container.decode(String.self, forKey: .avatarColor)
        emoji = try container.decode(String.self, forKey: .emoji)
        region = try container.decodeIfPresent(String.self, forKey: .region) ?? "Unknown"
        
        // Handle points - can be Int or String
        if let intValue = try? container.decode(Int.self, forKey: .points) {
            points = intValue
        } else if let stringValue = try? container.decode(String.self, forKey: .points),
                  let intValue = Int(stringValue) {
            points = intValue
        } else {
            points = 0
        }
        
        // Handle memberCount - can be Int or String
        if let intValue = try? container.decode(Int.self, forKey: .memberCount) {
            memberCount = intValue
        } else if let stringValue = try? container.decode(String.self, forKey: .memberCount),
                  let intValue = Int(stringValue) {
            memberCount = intValue
        } else {
            memberCount = 0
        }
        
        creatorUsername = try container.decodeIfPresent(String.self, forKey: .creatorUsername)
        
        // Handle role
        if let roleString = try container.decodeIfPresent(String.self, forKey: .myRole) {
            myRole = GroupRole(rawValue: roleString)
        } else {
            myRole = nil
        }
        
        // Handle dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        createdAt = dateFormatter.date(from: createdAtString) ?? Date()
        
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        updatedAt = dateFormatter.date(from: updatedAtString) ?? Date()
        
        if let joinedAtString = try container.decodeIfPresent(String.self, forKey: .myJoinedAt) {
            myJoinedAt = dateFormatter.date(from: joinedAtString)
        } else {
            myJoinedAt = nil
        }
        
        if let lastActivityString = try container.decodeIfPresent(String.self, forKey: .lastActivity) {
            lastActivity = dateFormatter.date(from: lastActivityString)
        } else {
            lastActivity = nil
        }
        
        // Handle activeMembers - can be Int or String
        if let intValue = try? container.decode(Int.self, forKey: .activeMembers) {
            activeMembers = intValue
        } else if let stringValue = try? container.decode(String.self, forKey: .activeMembers),
                  let intValue = Int(stringValue) {
            activeMembers = intValue
        } else {
            activeMembers = 0
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(uuid, forKey: .uuid)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(inviteCode, forKey: .inviteCode)
        try container.encode(createdBy, forKey: .createdBy)
        try container.encode(isPrivate, forKey: .isPrivate)
        try container.encode(memberLimit, forKey: .memberLimit)
        try container.encode(avatarColor, forKey: .avatarColor)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(region, forKey: .region)
        try container.encode(points, forKey: .points)
        try container.encode(memberCount, forKey: .memberCount)
        try container.encodeIfPresent(creatorUsername, forKey: .creatorUsername)
        try container.encodeIfPresent(myRole?.rawValue, forKey: .myRole)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        try container.encode(dateFormatter.string(from: createdAt), forKey: .createdAt)
        try container.encode(dateFormatter.string(from: updatedAt), forKey: .updatedAt)
        
        if let joinedAt = myJoinedAt {
            try container.encode(dateFormatter.string(from: joinedAt), forKey: .myJoinedAt)
        }
        
        if let lastActivity = lastActivity {
            try container.encode(dateFormatter.string(from: lastActivity), forKey: .lastActivity)
        }
        
        try container.encode(activeMembers, forKey: .activeMembers)
    }
}

enum GroupRole: String, CaseIterable, Codable {
    case owner = "owner"
    case admin = "admin"
    case member = "member"
    
    var displayName: String {
        switch self {
        case .owner:
            return "Owner"
        case .admin:
            return "Admin"
        case .member:
            return "Member"
        }
    }
    
    var canManageGroup: Bool {
        return self == .owner || self == .admin
    }
    
    var canInviteMembers: Bool {
        return self != .member
    }
    
    var canKickMembers: Bool {
        return self == .owner || self == .admin
    }
    
    var canBanMembers: Bool {
        return self == .owner || self == .admin
    }
    
    var canDeleteGroup: Bool {
        return self == .owner
    }
    
    var canPromoteMembers: Bool {
        return self == .owner
    }
    
    var canViewBannedUsers: Bool {
        return self == .owner || self == .admin
    }
    
    func canKick(_ targetRole: GroupRole) -> Bool {
        switch self {
        case .owner:
            return targetRole != .owner
        case .admin:
            return targetRole == .member
        case .member:
            return false
        }
    }
    
    func canBan(_ targetRole: GroupRole) -> Bool {
        switch self {
        case .owner:
            return targetRole != .owner
        case .admin:
            return targetRole == .member
        case .member:
            return false
        }
    }
    
    func canPromote(_ targetRole: GroupRole) -> Bool {
        return self == .owner && targetRole != .owner
    }
}

struct GroupMember: Identifiable, Codable {
    let id: Int
    let role: GroupRole
    let nickname: String?
    let joinedAt: Date
    let lastActiveAt: Date?
    let username: String
    let profileImageUrl: String?
    let isOnline: Bool
    let minutesSinceActive: Int
    
    enum CodingKeys: String, CodingKey {
        case id, role, nickname, username
        case joinedAt = "joined_at"
        case lastActiveAt = "last_active_at"
        case profileImageUrl = "profile_image_url"
        case isOnline = "is_online"
        case minutesSinceActive = "minutes_since_active"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        
        let roleString = try container.decode(String.self, forKey: .role)
        role = GroupRole(rawValue: roleString) ?? .member
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let joinedAtString = try container.decode(String.self, forKey: .joinedAt)
        joinedAt = dateFormatter.date(from: joinedAtString) ?? Date()
        
        if let lastActiveString = try container.decodeIfPresent(String.self, forKey: .lastActiveAt) {
            lastActiveAt = dateFormatter.date(from: lastActiveString)
        } else {
            lastActiveAt = nil
        }
        
        // Handle isOnline - can be Bool or Int
        if let boolValue = try? container.decode(Bool.self, forKey: .isOnline) {
            isOnline = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isOnline) {
            isOnline = intValue != 0
        } else {
            isOnline = false
        }
        
        // Handle minutesSinceActive - can be Int or String
        if let intValue = try? container.decode(Int.self, forKey: .minutesSinceActive) {
            minutesSinceActive = intValue
        } else if let stringValue = try? container.decode(String.self, forKey: .minutesSinceActive),
                  let intValue = Int(stringValue) {
            minutesSinceActive = intValue
        } else {
            minutesSinceActive = 999
        }
    }
}

struct GroupMessage: Identifiable, Codable {
    let id: Int
    let uuid: String?
    let groupId: Int
    let userId: Int
    let messageType: MessageType
    let content: String?
    let locationId: Int?
    let imageUrl: String?
    let replyToId: Int?
    let createdAt: Date
    let updatedAt: Date
    let username: String
    let profileImageUrl: String?
    let locationTitle: String?
    let locationLatitude: Double?
    let locationLongitude: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, uuid, content, username
        case groupId = "group_id"
        case userId = "user_id"
        case messageType = "message_type"
        case locationId = "location_id"
        case imageUrl = "image_url"
        case replyToId = "reply_to_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case profileImageUrl = "profile_image_url"
        case locationTitle = "location_title"
        case locationLatitude = "latitude"
        case locationLongitude = "longitude"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid)
        groupId = try container.decode(Int.self, forKey: .groupId)
        userId = try container.decode(Int.self, forKey: .userId)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        locationId = try container.decodeIfPresent(Int.self, forKey: .locationId)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        replyToId = try container.decodeIfPresent(Int.self, forKey: .replyToId)
        username = try container.decode(String.self, forKey: .username)
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        locationTitle = try container.decodeIfPresent(String.self, forKey: .locationTitle)
        locationLatitude = try container.decodeIfPresent(Double.self, forKey: .locationLatitude)
        locationLongitude = try container.decodeIfPresent(Double.self, forKey: .locationLongitude)
        
        let messageTypeString = try container.decode(String.self, forKey: .messageType)
        messageType = MessageType(rawValue: messageTypeString) ?? .text
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        createdAt = dateFormatter.date(from: createdAtString) ?? Date()
        
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        updatedAt = dateFormatter.date(from: updatedAtString) ?? Date()
    }
}

enum MessageType: String, CaseIterable, Codable {
    case text = "text"
    case location = "location"
    case image = "image"
    case system = "system"
}

// MARK: - API Request/Response Models

struct CreateGroupRequest: Codable {
    let name: String
    let description: String?
    let isPrivate: Bool
    let memberLimit: Int
    let avatarColor: String
    let emoji: String
    let region: String
    
    enum CodingKeys: String, CodingKey {
        case name, description, emoji, region
        case isPrivate = "is_private"
        case memberLimit = "member_limit"
        case avatarColor = "avatar_color"
    }
}

struct JoinGroupRequest: Codable {
    let inviteCode: String
    
    enum CodingKeys: String, CodingKey {
        case inviteCode = "invite_code"
    }
}

struct SendMessageRequest: Codable {
    let messageType: String
    let content: String
    let locationId: Int?
    let replyToId: Int?
    
    enum CodingKeys: String, CodingKey {
        case content
        case messageType = "message_type"
        case locationId = "location_id"
        case replyToId = "reply_to_id"
    }
}

struct ShareLocationRequest: Codable {
    let locationId: Int
    let notes: String?
    let isPinned: Bool
    
    enum CodingKeys: String, CodingKey {
        case notes
        case locationId = "location_id"
        case isPinned = "is_pinned"
    }
}

// MARK: - Response Models

struct GroupResponse: Codable {
    let success: Bool
    let group: Group
}

struct GroupsResponse: Codable {
    let success: Bool
    let groups: [Group]
}

struct GroupMembersResponse: Codable {
    let success: Bool
    let members: [GroupMember]
}

struct GroupMessagesResponse: Codable {
    let success: Bool
    let messages: [GroupMessage]
}

struct MessageResponse: Codable {
    let success: Bool
    let message: GroupMessage
}

// MARK: - Group Management Models

struct BannedUser: Identifiable, Codable {
    let id: Int
    let uuid: String?
    let groupId: Int
    let userId: Int
    let bannedBy: Int
    let banReason: String?
    let banType: String
    let isPermanent: Bool
    let expiresAt: Date?
    let createdAt: Date
    let unbannedAt: Date?
    let unbannedBy: Int?
    let username: String
    let profileImageUrl: String?
    let bannedByUsername: String
    let unbannedByUsername: String?
    
    enum CodingKeys: String, CodingKey {
        case id, uuid, username
        case groupId = "group_id"
        case userId = "user_id"
        case bannedBy = "banned_by"
        case banReason = "ban_reason"
        case banType = "ban_type"
        case isPermanent = "is_permanent"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case unbannedAt = "unbanned_at"
        case unbannedBy = "unbanned_by"
        case profileImageUrl = "profile_image_url"
        case bannedByUsername = "banned_by_username"
        case unbannedByUsername = "unbanned_by_username"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid)
        groupId = try container.decode(Int.self, forKey: .groupId)
        userId = try container.decode(Int.self, forKey: .userId)
        bannedBy = try container.decode(Int.self, forKey: .bannedBy)
        banReason = try container.decodeIfPresent(String.self, forKey: .banReason)
        banType = try container.decode(String.self, forKey: .banType)
        username = try container.decode(String.self, forKey: .username)
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        bannedByUsername = try container.decode(String.self, forKey: .bannedByUsername)
        unbannedByUsername = try container.decodeIfPresent(String.self, forKey: .unbannedByUsername)
        
        // Handle isPermanent - can be Bool or Int
        if let boolValue = try? container.decode(Bool.self, forKey: .isPermanent) {
            isPermanent = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isPermanent) {
            isPermanent = intValue != 0
        } else {
            isPermanent = false
        }
        
        unbannedBy = try container.decodeIfPresent(Int.self, forKey: .unbannedBy)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        createdAt = dateFormatter.date(from: createdAtString) ?? Date()
        
        if let expiresAtString = try container.decodeIfPresent(String.self, forKey: .expiresAt) {
            expiresAt = dateFormatter.date(from: expiresAtString)
        } else {
            expiresAt = nil
        }
        
        if let unbannedAtString = try container.decodeIfPresent(String.self, forKey: .unbannedAt) {
            unbannedAt = dateFormatter.date(from: unbannedAtString)
        } else {
            unbannedAt = nil
        }
    }
    
    var isActive: Bool {
        return unbannedAt == nil && (expiresAt == nil || expiresAt! > Date())
    }
}

struct AdminAction: Identifiable, Codable {
    let id: Int
    let uuid: String?
    let groupId: Int
    let adminId: Int
    let targetUserId: Int?
    let actionType: String
    let reason: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, uuid, reason
        case groupId = "group_id"
        case adminId = "admin_id"
        case targetUserId = "target_user_id"
        case actionType = "action_type"
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid)
        groupId = try container.decode(Int.self, forKey: .groupId)
        adminId = try container.decode(Int.self, forKey: .adminId)
        targetUserId = try container.decodeIfPresent(Int.self, forKey: .targetUserId)
        actionType = try container.decode(String.self, forKey: .actionType)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        createdAt = dateFormatter.date(from: createdAtString) ?? Date()
    }
}

// MARK: - Group Management Request Models

struct KickMemberRequest: Codable {
    let userId: Int
    let reason: String?
    
    enum CodingKeys: String, CodingKey {
        case reason
        case userId = "user_id"
    }
}

struct BanMemberRequest: Codable {
    let userId: Int
    let reason: String?
    let isPermanent: Bool
    
    enum CodingKeys: String, CodingKey {
        case reason
        case userId = "user_id"
        case isPermanent = "is_permanent"
    }
}

struct UnbanMemberRequest: Codable {
    let userId: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

struct PromoteMemberRequest: Codable {
    let userId: Int
    let newRole: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case newRole = "new_role"
    }
}

struct CheckBanRequest: Codable {
    let inviteCode: String
    
    enum CodingKeys: String, CodingKey {
        case inviteCode = "invite_code"
    }
}

// MARK: - Group Management Response Models

struct BannedUsersResponse: Codable {
    let success: Bool
    let bannedUsers: [BannedUser]
    
    enum CodingKeys: String, CodingKey {
        case success
        case bannedUsers = "banned_users"
    }
}

struct CheckBanResponse: Codable {
    let success: Bool
    let canJoin: Bool?
    let error: String?
    let banReason: String?
    let bannedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case success, error
        case canJoin = "can_join"
        case banReason = "ban_reason"
        case bannedAt = "banned_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        success = try container.decode(Bool.self, forKey: .success)
        canJoin = try container.decodeIfPresent(Bool.self, forKey: .canJoin)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        banReason = try container.decodeIfPresent(String.self, forKey: .banReason)
        
        if let bannedAtString = try container.decodeIfPresent(String.self, forKey: .bannedAt) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            bannedAt = dateFormatter.date(from: bannedAtString)
        } else {
            bannedAt = nil
        }
    }
}

 