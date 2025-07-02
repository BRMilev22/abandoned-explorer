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
    @State private var keyboardHeight: CGFloat = 0
    @State private var cancellables = Set<AnyCancellable>()
    @State private var isViewVisible = false
    @State private var messageAppearDelay: Double = 0
    
    // Group management state variables
    @State private var selectedMemberForAction: GroupMember?
    @State private var showingMemberActionSheet = false
    @State private var showingBannedUsers = false
    @State private var showingDeleteGroupAlert = false
    @State private var showingKickConfirmation = false
    @State private var showingBanConfirmation = false
    @State private var showingPromoteConfirmation = false
    @State private var reasonText = ""
    @State private var showingReasonDialog = false
    @State private var pendingAction: (() -> Void)?
    
    let accentColor = Color(hex: "#7289da")
    
    private let tabs = ["Group", "Members", "Chat", "Locations", "Settings"]
    
    var body: some View {
        VStack(spacing: 0) {
            if dataManager.userGroups.isEmpty {
                emptyGroupState
                    .opacity(isViewVisible ? 1 : 0)
                    .scaleEffect(isViewVisible ? 1 : 0.95)
                    .animation(.easeInOut(duration: 0.6).delay(0.2), value: isViewVisible)
            } else {
                // Content for when groups exist
                groupContent
                    .opacity(isViewVisible ? 1 : 0)
                    .offset(y: isViewVisible ? 0 : 30)
                    .animation(.spring(response: 0.8, dampingFraction: 0.8, blendDuration: 0), value: isViewVisible)
            }
        }
        .background(
            Color.black
                .opacity(isViewVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.4), value: isViewVisible)
        )
        .sheet(isPresented: $showingCreateGroup) {
            CreateGroupView()
                .environmentObject(dataManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingJoinGroup) {
            JoinGroupView()
                .environmentObject(dataManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.1)) {
                isViewVisible = true
            }
            
            dataManager.loadUserGroups()
            // Load members for the first group if available
            if let firstGroup = dataManager.userGroups.first {
                dataManager.loadGroupMembers(firstGroup.id)
                dataManager.updateMemberActivity(firstGroup.id)
            }
            // Setup keyboard observers
            setupKeyboardObservers()
        }
        .onDisappear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isViewVisible = false
            }
            // Clean up keyboard observers
            cancellables.removeAll()
            // Clear group selection to stop monitoring
            dataManager.clearGroupSelection()
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
        .actionSheet(isPresented: $showingMemberActionSheet) {
            memberActionSheet
        }
        .sheet(isPresented: $showingBannedUsers) {
            bannedUsersView
        }
        .alert("Delete Group", isPresented: $showingDeleteGroupAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let group = dataManager.selectedGroup ?? dataManager.userGroups.first {
                    dataManager.deleteGroup(group.id)
                }
            }
            .disabled(dataManager.isPerformingAdminAction)
        } message: {
            Text("This action cannot be undone. All messages and data will be lost.")
        }
        .alert("Kick Member", isPresented: $showingKickConfirmation) {
            Button("Cancel", role: .cancel) { 
                resetActionState()
            }
            Button("Kick", role: .destructive) {
                if let member = selectedMemberForAction,
                   let group = dataManager.selectedGroup ?? dataManager.userGroups.first {
                    dataManager.kickMember(group.id, userId: member.id, reason: reasonText.isEmpty ? nil : reasonText)
                }
                resetActionState()
            }
            .disabled(dataManager.isPerformingAdminAction)
        } message: {
            if let member = selectedMemberForAction {
                Text("Remove \(member.username) from the group? They can rejoin with an invite code.")
            }
        }
        .alert("Ban Member", isPresented: $showingBanConfirmation) {
            Button("Cancel", role: .cancel) { 
                resetActionState()
            }
            Button("Ban", role: .destructive) {
                if let member = selectedMemberForAction,
                   let group = dataManager.selectedGroup ?? dataManager.userGroups.first {
                    dataManager.banMember(group.id, userId: member.id, reason: reasonText.isEmpty ? nil : reasonText)
                }
                resetActionState()
            }
            .disabled(dataManager.isPerformingAdminAction)
        } message: {
            if let member = selectedMemberForAction {
                Text("Ban \(member.username) from the group? They will not be able to rejoin.")
            }
        }
        .alert("Change Role", isPresented: $showingPromoteConfirmation) {
            Button("Cancel", role: .cancel) { 
                resetActionState()
            }
            Button("Confirm") {
                pendingAction?()
                resetActionState()
            }
            .disabled(dataManager.isPerformingAdminAction)
        } message: {
            if let member = selectedMemberForAction {
                Text("Change \(member.username)'s role?")
            }
        }
        .alert("Removed from Group", isPresented: $dataManager.wasRemovedFromGroup) {
            Button("OK") {
                // Alert will automatically dismiss and flag will be reset
            }
        } message: {
            Text(dataManager.removalReason ?? "You have been removed from this group")
        }
    }
    
    private var groupContent: some View {
        VStack(spacing: 0) {
            // Top section with user profile and tabs
            topSection
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .onTapGesture {
                    // Dismiss keyboard when tapping on top section
                    dismissKeyboard()
                }
            
            // Tab content with smooth transitions
            if selectedTab == 2 { // Chat tab - special handling for keyboard
                if let firstGroup = dataManager.userGroups.first {
                    chatTabView(for: firstGroup)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        if let firstGroup = dataManager.userGroups.first {
                            tabContentView(for: firstGroup)
                                .opacity(isViewVisible ? 1 : 0)
                                .offset(y: isViewVisible ? 0 : 20)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8)
                                          .delay(0.1), value: isViewVisible)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
                .onTapGesture {
                    // Dismiss keyboard when tapping on other tabs
                    dismissKeyboard()
                }
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
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
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
                                            .scaleEffect(selectedTab == index ? 1.0 : 0.95)
                                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .scaleEffect(selectedTab == index ? 1.05 : 1.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: selectedTab)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxWidth: .infinity)
                .clipped()
            }
        }
    }
    
    private func horizontalInfoSection(for group: Group) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Region Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Region")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 14))
                            .foregroundColor(accentColor)
                        
                        Text(group.region)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(accentColor.opacity(0.3), lineWidth: 1)
                        )
                )
                
                // Points Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Points")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.yellow)
                        
                        Text("\(group.points)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                )
                
                // Team Code Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Team Code")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 8) {
                        Text(group.inviteCode)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .tracking(1)
                        
                        Button(action: {
                            UIPasteboard.general.string = group.inviteCode
                            // Add haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12))
                                .foregroundColor(accentColor)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
                
                // Active Time Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Time")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                        
                        Text(activeTimeString(for: group))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 20)
        }
        .scrollTargetBehavior(.viewAligned)
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
                                case 0: // Group
            activityTabView(for: group)
        case 1: // Members
            membersTabView(for: group)
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
            // Horizontal info section
            horizontalInfoSection(for: group)
            
            // My Teammates section
            teammatesSection(for: group)
        }
    }
    
    private func membersTabView(for group: Group) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Members")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(dataManager.groupMembers.count)/\(group.memberLimit)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            // Admin hint for owners/admins
            if let myRole = group.myRole, myRole.canManageGroup {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(accentColor)
                    
                    Text("Tap 'Manage' next to members to kick, ban, or promote them")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accentColor.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(accentColor.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            if dataManager.isLoadingGroupMembers {
                // Loading state
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                    
                    Text("Loading members...")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(dataManager.groupMembers.sorted(by: { 
                        if $0.role == .owner && $1.role != .owner { return true }
                        if $1.role == .owner && $0.role != .owner { return false }
                        if $0.role == .admin && $1.role == .member { return true }
                        if $1.role == .admin && $0.role == .member { return false }
                        return $0.username < $1.username
                    })) { member in
                        memberRowView(member: member)
                    }
                }
            }
        }
    }
    
    private func memberRowView(member: GroupMember) -> some View {
        HStack(spacing: 12) {
            // Avatar
            AsyncImage(url: URL(string: member.profileImageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [accentColor.opacity(0.6), accentColor.opacity(0.3)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        Text(String(member.username.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(member.username)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    roleBadgeView(for: member.role)
                    
                    if member.isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(member.isOnline ? "Online" : "\(member.minutesSinceActive)m ago")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Admin actions button (only for admins/owners and not for themselves)
            if let currentGroup = dataManager.selectedGroup ?? dataManager.userGroups.first,
               let myRole = currentGroup.myRole,
               myRole.canManageGroup,
               member.id != dataManager.currentUser?.id {
                
                Button(action: {
                    selectedMemberForAction = member
                    showingMemberActionSheet = true
                }) {
                    HStack(spacing: 6) {
                        if dataManager.isPerformingAdminAction {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
                        Text(dataManager.isPerformingAdminAction ? "Processing..." : "Manage")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(accentColor.opacity(dataManager.isPerformingAdminAction ? 0.6 : 0.8))
                    )
                }
                .disabled(dataManager.isPerformingAdminAction)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    @State private var replyingToMessage: GroupMessage?
    
    private func chatTabView(for group: Group) -> some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Compact messages area - fixed height that leaves room for everything
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if dataManager.isLoadingGroupMessages {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                                    Spacer()
                                }
                                .padding(.vertical, 20)
                            } else if dataManager.groupMessages.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "message.circle")
                                        .font(.system(size: 30))
                                        .foregroundColor(.gray)
                                    
                                    Text("No messages yet")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Text("Start the conversation!")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                            } else {
                                ForEach(Array(dataManager.groupMessages.enumerated()), id: \.element.id) { index, message in
                                    compactMessageRowView(message: message)
                                        .id(message.id)
                                        .opacity(isViewVisible ? 1 : 0)
                                        .offset(x: isViewVisible ? 0 : -30)
                                        .animation(.spring(response: 0.6, dampingFraction: 0.8)
                                                  .delay(Double(index) * 0.1), value: isViewVisible)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .frame(height: keyboardHeight > 0 ? 
                           max(120, geometry.size.height - keyboardHeight - 240) : // When keyboard visible: leave room for input + keyboard + bottom nav
                           geometry.size.height - 200) // When keyboard hidden: leave room for input + bottom nav
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.02))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 16)
                    .onTapGesture {
                        dismissKeyboard()
                    }
                    .onChange(of: dataManager.groupMessages.count) { _ in
                        if let lastMessage = dataManager.groupMessages.last {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: keyboardHeight) { _ in
                        if let lastMessage = dataManager.groupMessages.last {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Spacer(minLength: 8)
                
                // Input field - always visible at bottom
                ChatInputView(groupId: group.id, replyingTo: $replyingToMessage)
                    .environmentObject(dataManager)
                    .background(
                        Rectangle()
                            .fill(Color.black)
                            .overlay(
                                Rectangle()
                                    .fill(Color.white.opacity(keyboardHeight > 0 ? 0.12 : 0.08))
                                    .animation(.easeInOut(duration: 0.3), value: keyboardHeight)
                            )
                            .shadow(color: .black.opacity(keyboardHeight > 0 ? 0.3 : 0.1), 
                                   radius: keyboardHeight > 0 ? 8 : 4, x: 0, y: -2)
                            .animation(.easeInOut(duration: 0.3), value: keyboardHeight)
                    )
                    .scaleEffect(keyboardHeight > 0 ? 1.02 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: keyboardHeight)
                    .padding(.bottom, keyboardHeight + 100) // Move up with keyboard + space for bottom nav
            }
            .background(Color.black)
        }
    }
    
    private func compactMessageRowView(message: GroupMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                // Smaller avatar
                Circle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(message.username.prefix(1).uppercased()))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    // Compact header
                    HStack(spacing: 6) {
                        Text(message.username)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(message.createdAt, style: .time)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    
                    // Message content
                    if let content = message.content, !content.isEmpty {
                        Text(content)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Compact action buttons
                    HStack(spacing: 12) {
                        Button(action: { likeMessage(message) }) {
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.red.opacity(0.7))
                                Text("0")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { replyToMessage(message) }) {
                            HStack(spacing: 2) {
                                Image(systemName: "arrowshape.turn.up.left")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                Text("Reply")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                    }
                    .padding(.top, 2)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.02))
        )
    }
    
    private func messageRowView(message: GroupMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Avatar
                Circle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(message.username.prefix(1).uppercased()))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    // Header
                    HStack(spacing: 8) {
                        Text(message.username)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(message.createdAt, style: .time)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    
                    // Reply indicator if this is a reply
                    if message.replyToId != nil {
                        HStack(spacing: 6) {
                            Image(systemName: "arrowshape.turn.up.left.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                            
                            Text("Reply")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(.bottom, 2)
                    }
                    
                    // Message content
                    if let content = message.content, !content.isEmpty {
                        Text(content)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Location content if present
                    if let locationTitle = message.locationTitle {
                        locationMessageView(title: locationTitle, latitude: message.locationLatitude, longitude: message.locationLongitude)
                    }
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        // Like button
                        Button(action: {
                            likeMessage(message)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill") // In real app, this would be conditional
                                    .font(.system(size: 14))
                                    .foregroundColor(.red.opacity(0.7))
                                
                                Text("0") // In real app, this would show actual like count
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Reply button
                        Button(action: {
                            replyToMessage(message)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrowshape.turn.up.left")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                Text("Reply")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
    }
    
    private func locationMessageView(title: String, latitude: Double?, longitude: Double?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "location.fill")
                .font(.system(size: 16))
                .foregroundColor(accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                if let lat = latitude, let lng = longitude {
                    Text("\(lat, specifier: "%.4f"), \(lng, specifier: "%.4f")")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Button(action: {
                // Open location on map
            }) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14))
                    .foregroundColor(accentColor)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func likeMessage(_ message: GroupMessage) {
        if let firstGroup = dataManager.userGroups.first {
            dataManager.likeGroupMessage(firstGroup.id, messageId: message.id)
        }
    }
    
    private func replyToMessage(_ message: GroupMessage) {
        // Set the reply state - this will be passed to ChatInputView
        replyingToMessage = message
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
                
                // Admin sections (only for owners/admins)
                if let myRole = group.myRole, myRole.canViewBannedUsers {
                    adminActionsSection(for: group)
                }
                
                // Actions
                VStack(spacing: 12) {
                    copyInviteCodeButton(for: group)
                    
                    if let myRole = group.myRole, myRole.canDeleteGroup {
                        deleteGroupButton(for: group)
                    } else {
                        leaveGroupButton(for: group)
                    }
                }
                
                // Add extra bottom padding to account for tab bar
                Spacer()
                    .frame(height: 120)
            }
        }
    }
    
    private func adminActionsSection(for group: Group) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Admin Actions")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                Button(action: {
                    showingBannedUsers = true
                    dataManager.loadBannedUsers(group.id)
                }) {
                    HStack {
                        Image(systemName: "person.slash.fill")
                            .foregroundColor(.orange)
                        
                        Text("Manage Banned Users")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if !dataManager.bannedUsers.isEmpty {
                            Text("\(dataManager.bannedUsers.filter(\.isActive).count)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.orange.opacity(0.2))
                                )
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(16)
                    .background(cardBackground)
                }
            }
        }
    }
    
    private func deleteGroupButton(for group: Group) -> some View {
        Button(action: {
            showingDeleteGroupAlert = true
        }) {
            HStack {
                Image(systemName: "trash.fill")
                    .foregroundColor(.red)
                
                Text("Delete Group")
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
        VStack(spacing: 20) {
            // Modern animated Create Group button with moving border
            ModernAnimatedButton(title: "Create Group") {
                showingCreateGroup = true
            }
            .scaleEffect(isViewVisible ? 1 : 0.8)
            .opacity(isViewVisible ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: isViewVisible)
            
            // Modern animated Join Group button with moving border
            ModernAnimatedButton(title: "Join with Code") {
                showingJoinGroup = true
            }
            .scaleEffect(isViewVisible ? 1 : 0.8)
            .opacity(isViewVisible ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: isViewVisible)
        }
        .padding(.horizontal, 40)
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
    
    // MARK: - Keyboard Handling
    
    private func setupKeyboardObservers() {
        // Observe keyboard will show
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { notification in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height
            }
            .receive(on: DispatchQueue.main)
            .sink { height in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                    keyboardHeight = height
                }
                // Add subtle haptic feedback when keyboard appears
                let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                impactFeedback.impactOccurred()
            }
            .store(in: &cancellables)
        
        // Observe keyboard will hide
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.9, blendDuration: 0)) {
                    keyboardHeight = 0
                }
                // Add subtle haptic feedback when keyboard disappears
                let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                impactFeedback.impactOccurred()
            }
            .store(in: &cancellables)
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - Group Management UI Components
    
    private var memberActionSheet: ActionSheet {
        guard let member = selectedMemberForAction,
              let group = dataManager.selectedGroup ?? dataManager.userGroups.first,
              let myRole = group.myRole else {
            return ActionSheet(title: Text("Error"), buttons: [.cancel()])
        }
        
        var buttons: [ActionSheet.Button] = []
        
        // Kick option
        if myRole.canKick(member.role) {
            buttons.append(.destructive(Text("Kick from Group")) {
                showingKickConfirmation = true
            })
        }
        
        // Ban option
        if myRole.canBan(member.role) {
            buttons.append(.destructive(Text("Ban from Group")) {
                showingBanConfirmation = true
            })
        }
        
        // Promote/Demote options (only for owners)
        if myRole.canPromote(member.role) {
            if member.role == .member {
                buttons.append(.default(Text("Promote to Admin")) {
                    pendingAction = {
                        dataManager.promoteMember(group.id, userId: member.id, newRole: .admin)
                    }
                    showingPromoteConfirmation = true
                })
            } else if member.role == .admin {
                buttons.append(.default(Text("Demote to Member")) {
                    pendingAction = {
                        dataManager.demoteMember(group.id, userId: member.id)
                    }
                    showingPromoteConfirmation = true
                })
            }
        }
        
        buttons.append(.cancel())
        
        return ActionSheet(
            title: Text(member.username),
            message: Text("Choose an action"),
            buttons: buttons
        )
    }
    
    private var bannedUsersView: some View {
        NavigationView {
            VStack(spacing: 0) {
                if dataManager.isLoadingBannedUsers {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                        
                        Text("Loading banned users...")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                } else if dataManager.bannedUsers.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No Banned Users")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Users who are banned from the group will appear here.")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                } else {
                    List {
                        ForEach(dataManager.bannedUsers) { bannedUser in
                            bannedUserRowView(bannedUser)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.black)
                }
            }
            .navigationTitle("Banned Users")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingBannedUsers = false
                    }
                }
            }
        }
    }
    
    private func bannedUserRowView(_ bannedUser: BannedUser) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Avatar
                AsyncImage(url: URL(string: bannedUser.profileImageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.red.opacity(0.6), Color.red.opacity(0.3)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .overlay(
                            Text(String(bannedUser.username.prefix(1)).uppercased())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(bannedUser.username)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        if bannedUser.isActive {
                            Text("BANNED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.red.opacity(0.2))
                                )
                        } else {
                            Text("UNBANNED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green.opacity(0.2))
                                )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Banned by \(bannedUser.bannedByUsername)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        if let reason = bannedUser.banReason {
                            Text("Reason: \(reason)")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        
                        Text("Banned \(formatDate(bannedUser.createdAt))")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Unban button (only for active bans and if user has permission)
                if bannedUser.isActive,
                   let group = dataManager.selectedGroup ?? dataManager.userGroups.first,
                   let myRole = group.myRole,
                   myRole.canBanMembers {
                    
                    Button("Unban") {
                        dataManager.unbanMember(group.id, userId: bannedUser.userId)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    private func resetActionState() {
        selectedMemberForAction = nil
        reasonText = ""
        pendingAction = nil
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Chat Input View

struct ChatInputView: View {
    let groupId: Int
    @Binding var replyingTo: GroupMessage?
    @EnvironmentObject var dataManager: DataManager
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var hasAppeared = false
    
    let accentColor = Color(hex: "#7289da")
    
    var body: some View {
        VStack(spacing: 0) {
            // Reply indicator
            if let replyMessage = replyingTo {
                replyIndicatorView(message: replyMessage)
            }
            
            // Input area with better visibility - tap anywhere to focus
            HStack(spacing: 12) {
                // Text input with enhanced visibility
                HStack(spacing: 8) {
                    TextField("Tap here to type a message...", text: $messageText, axis: .vertical)
                        .focused($isTextFieldFocused)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .lineLimit(1...4)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(isTextFieldFocused ? accentColor : Color.white.opacity(0.3), lineWidth: 2)
                                )
                        )
                        .onSubmit {
                            sendMessage()
                        }
                    
                    // Attachment button
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        // TODO: Open attachment options
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(accentColor)
                            .scaleEffect(1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: messageText)
                    }
                }
                .onTapGesture {
                    // Make entire input area tappable to focus
                    isTextFieldFocused = true
                }
                
                // Send button with better visibility and animations
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    sendMessage()
                }) {
                    Image(systemName: messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "arrow.up.circle" : "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : accentColor)
                        .scaleEffect(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1.0 : 1.1)
                        .rotationEffect(.degrees(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 360))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                    )
            )
        }
        .onAppear {
            // Remove auto-focus, let user tap to focus
            hasAppeared = true
        }
    }
    
    private func replyIndicatorView(message: GroupMessage) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to \(message.username)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(accentColor)
                
                if let content = message.content {
                    Text(content)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button(action: {
                replyingTo = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
    }
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        let replyToId = replyingTo?.id
        
        // Send the message
        dataManager.sendGroupMessage(
            groupId,
            content: trimmedMessage,
            messageType: .text,
            locationId: nil,
            replyToId: replyToId
        )
        
        // Clear input and reply state
        messageText = ""
        replyingTo = nil
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

 