//
//  GroupsView.swift
//  upwork-project
//
//  Created by Boris Milev on 30.06.25.
//

import SwiftUI
import Combine

struct GroupsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedTab = 0
    @State private var showingCreateGroup = false
    @State private var showingJoinGroup = false
    
    let accentColor = Color(hex: "#7289da")
    
    private let tabs = ["Activity", "Members", "Chat", "Locations", "Settings"]
    
    var body: some View {
        VStack(spacing: 0) {
            if dataManager.userGroups.isEmpty {
                emptyGroupState
            } else {
                // Content for when groups exist
                groupContent
            }
        }
        .background(Color.black)
        .sheet(isPresented: $showingCreateGroup) {
            CreateGroupView()
                .environmentObject(dataManager)
        }
        .sheet(isPresented: $showingJoinGroup) {
            JoinGroupView()
                .environmentObject(dataManager)
        }
        .onAppear {
            dataManager.loadUserGroups()
            // Load members for the first group if available
            if let firstGroup = dataManager.userGroups.first {
                dataManager.loadGroupMembers(firstGroup.id)
                dataManager.updateMemberActivity(firstGroup.id)
            }
        }
        .onChange(of: dataManager.userGroups) { groups in
            // When groups are loaded, load members for the first group
            if let firstGroup = groups.first {
                dataManager.loadGroupMembers(firstGroup.id)
                dataManager.updateMemberActivity(firstGroup.id)
                loadTabData(for: firstGroup)
            }
        }
        .onChange(of: selectedTab) { _ in
            // Load data when tab changes
            if let firstGroup = dataManager.userGroups.first {
                loadTabData(for: firstGroup)
            }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            // Update activity every minute when viewing groups
            if let firstGroup = dataManager.userGroups.first {
                dataManager.updateMemberActivity(firstGroup.id)
            }
        }
    }
    
    private var groupContent: some View {
        VStack(spacing: 0) {
            // Top section with user profile and tabs
            topSection
                .padding(.horizontal, 20)
                .padding(.top, 16)
            
            // Tab content
            ScrollView {
                VStack(spacing: 20) {
                    if let firstGroup = dataManager.userGroups.first {
                        tabContentView(for: firstGroup)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
    }
    
    private var topSection: some View {
        VStack(spacing: 16) {
            // User profile and tabs row
            HStack(spacing: 12) {
                // User profile picture (top left)
                Button(action: {
                    // Profile action
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 44, height: 44)
                        
                        // User avatar placeholder
                        if let username = dataManager.currentUser?.username {
                            Text(String(username.prefix(1).uppercased()))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }
                        
                        // Online indicator for current user
                        Circle()
                            .fill(Color.green)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                            )
                            .offset(x: 16, y: -16)
                    }
                    .overlay(
                        Circle()
                            .stroke(accentColor, lineWidth: 2)
                    )
                }
                .frame(width: 48, height: 48) // Extra space for green indicator
                
                // Tab navigation
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = index
                                }
                            }) {
                                Text(tab)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(selectedTab == index ? .white : .gray)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(selectedTab == index ? accentColor : Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxWidth: .infinity)
                .clipped()
            }
        }
    }
    
    private func infoCardsSection(for group: Group) -> some View {
        VStack(spacing: 16) {
            // First row - Member count and Active time
            HStack(spacing: 20) {
                // Member count
                VStack(alignment: .leading, spacing: 4) {
                    Text("Members")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("\(group.memberCount)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Active time
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Time")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text(activeTimeString(for: group))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Second row - Group code and Team button
            HStack(spacing: 20) {
                // Group code
                VStack(alignment: .leading, spacing: 4) {
                    Text("Group Code")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 8) {
                        Text(group.inviteCode)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .tracking(1)
                        
                        Button(action: {
                            UIPasteboard.general.string = group.inviteCode
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16))
                                .foregroundColor(accentColor)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Team button
                VStack(spacing: 4) {
                    Button(action: {
                        // Team settings action
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                            
                            Text("Team")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .frame(width: 60, height: 60)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func teammatesSection(for group: Group) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section title
            HStack {
                Text("My Teammates")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // Teammates grid (3 columns)
            let colors: [Color] = [accentColor, .orange, .pink, .green, .purple, .blue]
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 24), count: 3), spacing: 24) {
                ForEach(Array(dataManager.groupMembers.prefix(6).enumerated()), id: \.element.id) { index, member in
                    teammateProfile(
                        member: member,
                        avatarColor: colors[index % colors.count]
                    )
                }
            }
        }
    }
    
    private func teammateProfile(member: GroupMember, avatarColor: Color) -> some View {
        VStack(spacing: 8) {
            // Profile circle
            ZStack {
                Circle()
                    .fill(avatarColor.opacity(0.2))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(avatarColor, lineWidth: 2)
                    )
                
                // Avatar placeholder (could be actual image)
                Text(String(member.username.prefix(1).uppercased()))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                
                // Online indicator dot
                if member.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                        )
                        .offset(x: 22, y: -22)
                }
            }
            
            // Name
            Text(member.nickname ?? member.username)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            // Status bar (like battery indicator in original)
            RoundedRectangle(cornerRadius: 3)
                .fill(member.isOnline ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 32, height: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.black.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private var emptyGroupState: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Empty state icon
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 40))
                        .foregroundColor(accentColor)
                }
                
                VStack(spacing: 8) {
                    Text("No Groups Yet")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Create your first group or join one with an invite code")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            // Action buttons
            actionButtonsSection
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func tabContentView(for group: Group) -> some View {
        switch selectedTab {
        case 0: // Activity
            activityTabView(for: group)
        case 1: // Members
            membersTabView(for: group)
        case 2: // Chat
            chatTabView(for: group)
        case 3: // Locations
            locationsTabView(for: group)
        case 4: // Settings
            settingsTabView(for: group)
        default:
            activityTabView(for: group)
        }
    }
    
    private func activityTabView(for group: Group) -> some View {
        VStack(spacing: 20) {
            // Info cards section
            infoCardsSection(for: group)
            
            // My Teammates section
            teammatesSection(for: group)
        }
    }
    
    private func membersTabView(for group: Group) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Group Members")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            if dataManager.isLoadingGroupMembers {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                    Spacer()
                }
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(dataManager.groupMembers) { member in
                        memberRowView(member: member)
                    }
                }
            }
        }
    }
    
    private func memberRowView(member: GroupMember) -> some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(accentColor, lineWidth: 2)
                    )
                
                Text(String(member.username.prefix(1).uppercased()))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                // Online indicator
                if member.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                        )
                        .offset(x: 18, y: -18)
                }
            }
            
            // Member info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(member.nickname ?? member.username)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    // Role badge
                    roleBadgeView(for: member.role)
                }
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(member.isOnline ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    
                    Text(member.isOnline ? "Online" : "Last seen \(member.minutesSinceActive)m ago")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func chatTabView(for group: Group) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Group Chat")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                if dataManager.isLoadingGroupMessages {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                        Spacer()
                    }
                    .padding(.vertical, 40)
                } else if dataManager.groupMessages.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "message.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No messages yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text("Be the first to start the conversation!")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(dataManager.groupMessages.suffix(10)) { message in
                            messageRowView(message: message)
                        }
                    }
                }
                
                // Quick message input
                Button(action: {
                    // TODO: Open chat modal
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "message.fill")
                            .foregroundColor(accentColor)
                        
                        Text("Send a message...")
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(accentColor)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }
    
    private func messageRowView(message: GroupMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Circle()
                .fill(accentColor.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(message.username.prefix(1).uppercased()))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(message.username)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(message.createdAt, style: .time)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                if let content = message.content {
                    Text(content)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
    }
    
    private func locationsTabView(for group: Group) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Shared Locations")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                Image(systemName: "location.circle")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                
                Text("No locations shared yet")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                
                Text("Share interesting locations with your group!")
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.7))
            }
            .padding(.vertical, 40)
        }
    }
    
    private func settingsTabView(for group: Group) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Group Settings")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                // Group info
                groupInfoSection(for: group)
                
                // Actions
                VStack(spacing: 12) {
                    copyInviteCodeButton(for: group)
                    leaveGroupButton(for: group)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func roleBadgeView(for role: GroupRole) -> some View {
        Text(role.displayName)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(roleColor(for: role))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
            )
    }
    
    private func roleColor(for role: GroupRole) -> Color {
        switch role {
        case .owner:
            return .yellow
        case .admin:
            return .orange
        case .member:
            return .gray
        }
    }
    
    private func groupInfoSection(for group: Group) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Group Information")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            groupNameCard(for: group)
            
            if let description = group.description {
                groupDescriptionCard(description: description)
            }
        }
    }
    
    private func groupNameCard(for group: Group) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Group Name")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Text(group.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func groupDescriptionCard(description: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Text(description)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func copyInviteCodeButton(for group: Group) -> some View {
        Button(action: {
            UIPasteboard.general.string = group.inviteCode
        }) {
            HStack {
                Image(systemName: "link.circle.fill")
                    .foregroundColor(accentColor)
                
                Text("Copy Invite Code")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(group.inviteCode)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(cardBackground)
        }
    }
    
    private func leaveGroupButton(for group: Group) -> some View {
        Button(action: {
            dataManager.leaveGroup(group.id)
        }) {
            HStack {
                Image(systemName: "arrow.right.square.fill")
                    .foregroundColor(.red)
                
                Text("Leave Group")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            createGroupButton
            joinGroupButton
        }
        .padding(.horizontal, 40)
    }
    
    private var createGroupButton: some View {
        Button(action: { showingCreateGroup = true }) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                
                Text("Create Group")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(createGroupButtonBackground)
            .cornerRadius(16)
            .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    private var createGroupButtonBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [accentColor, accentColor.opacity(0.8)]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var joinGroupButton: some View {
        Button(action: { showingJoinGroup = true }) {
            HStack(spacing: 12) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 18))
                
                Text("Join with Code")
                    .font(.system(size: 18, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.08))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadTabData(for group: Group) {
        switch selectedTab {
        case 1: // Members
            dataManager.loadGroupMembers(group.id)
        case 2: // Chat
            dataManager.loadGroupMessages(group.id)
        default:
            break
        }
    }
    
    private func activeTimeString(for group: Group) -> String {
        guard let lastActivity = group.lastActivity else {
            return "Unknown"
        }
        
        let now = Date()
        let timeDifference = now.timeIntervalSince(lastActivity)
        
        let hours = Int(timeDifference) / 3600
        let minutes = Int(timeDifference.truncatingRemainder(dividingBy: 3600)) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

 