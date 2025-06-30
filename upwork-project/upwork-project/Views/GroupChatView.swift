//
//  GroupChatView.swift
//  upwork-project
//
//  Created by Boris Milev on 30.06.25.
//

import SwiftUI

struct GroupChatView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    let group: Group
    @State private var messageText = ""
    @State private var showingGroupInfo = false
    @State private var showingMembers = false
    
    let accentColor = Color(hex: "#7289da")
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Header
                    headerView
                    
                    // Messages
                    messagesView
                    
                    // Message Input
                    messageInputView
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingGroupInfo) {
            GroupInfoView(group: group)
                .environmentObject(dataManager)
        }
        .sheet(isPresented: $showingMembers) {
            GroupMembersView(group: group)
                .environmentObject(dataManager)
        }
        .onAppear {
            dataManager.selectGroup(group)
        }
        .onDisappear {
            dataManager.clearGroupSelection()
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 12) {
            // Back Button
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            // Group Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: group.avatarColor).opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text(group.emoji)
                    .font(.system(size: 18))
            }
            .overlay(
                Circle()
                    .stroke(Color(hex: group.avatarColor), lineWidth: 1.5)
            )
            
            // Group Info
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(group.memberCount) members")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                Button(action: { showingMembers = true }) {
                    Image(systemName: "person.2")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Button(action: { showingGroupInfo = true }) {
                    Image(systemName: "info")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
    }
    
    private var messagesView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if dataManager.isLoadingGroupMessages {
                    loadingMessagesView
                } else if dataManager.groupMessages.isEmpty {
                    emptyMessagesView
                } else {
                    ForEach(dataManager.groupMessages) { message in
                        MessageBubble(message: message, currentUserId: dataManager.currentUser?.id ?? 0)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .refreshable {
            dataManager.loadGroupMessages(group.id)
        }
    }
    
    private var loadingMessagesView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                .scaleEffect(1.2)
            
            Text("Loading messages...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
    }
    
    private var emptyMessagesView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "message")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(accentColor)
            }
            
            VStack(spacing: 8) {
                Text("No messages yet")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Start the conversation!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
    
    private var messageInputView: some View {
        HStack(spacing: 12) {
            // Message TextField
            HStack {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .lineLimit(1...4)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !messageText.isEmpty {
                    Button(action: { messageText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            // Send Button
            Button(action: sendMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [Color.gray.opacity(0.3), Color.gray.opacity(0.2)] : [accentColor, accentColor.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.clear : accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || dataManager.isSendingMessage)
            .scaleEffect(dataManager.isSendingMessage ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: dataManager.isSendingMessage)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
    }
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        dataManager.sendGroupMessage(group.id, content: trimmedMessage)
        messageText = ""
    }
}

struct MessageBubble: View {
    let message: GroupMessage
    let currentUserId: Int
    
    private var isCurrentUser: Bool {
        message.userId == currentUserId
    }
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.username)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#7289da"))
                }
                
                Text(message.content ?? "")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isCurrentUser ? .black : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(isCurrentUser ? Color(hex: "#7289da") : Color.white.opacity(0.1))
                    )
                
                Text(formatTime(message.createdAt))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            if !isCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct GroupInfoView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    let group: Group
    @State private var showingInviteCode = false
    @State private var showingLeaveConfirmation = false
    
    let accentColor = Color(hex: "#7289da")
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Group Header
                        groupHeader
                        
                        // Actions
                        groupActions
                        
                        // Group Details
                        groupDetails
                        
                        // Danger Zone
                        if group.myRole == .owner || group.myRole == .admin {
                            dangerZone
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
        .alert("Leave Group", isPresented: $showingLeaveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) {
                dataManager.leaveGroup(group.id)
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Are you sure you want to leave this group?")
        }
    }
    
    private var groupHeader: some View {
        VStack(spacing: 20) {
            // Close Button
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Spacer()
            }
            .padding(.top, 10)
            
            // Group Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: group.avatarColor).opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Text(group.emoji)
                    .font(.system(size: 44))
            }
            .overlay(
                Circle()
                    .stroke(Color(hex: group.avatarColor), lineWidth: 3)
            )
            .shadow(color: Color(hex: group.avatarColor).opacity(0.3), radius: 20, x: 0, y: 10)
            
            // Group Name and Description
            VStack(spacing: 8) {
                Text(group.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                if let description = group.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    private var groupActions: some View {
        VStack(spacing: 12) {
            if group.myRole?.canInviteMembers == true {
                Button(action: { showingInviteCode = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("Invite Members")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Spacer()
                        
                        Text(group.inviteCode)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(accentColor)
                    }
                    .foregroundColor(.white)
                    .padding(20)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
            }
        }
        .sheet(isPresented: $showingInviteCode) {
            InviteCodeView(group: group)
        }
    }
    
    private var groupDetails: some View {
        VStack(spacing: 16) {
            // Group Stats
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(group.memberCount)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Members")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Divider()
                    .frame(height: 30)
                    .background(Color.white.opacity(0.2))
                
                VStack(spacing: 4) {
                    Text(group.isPrivate ? "Private" : "Public")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Group")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Divider()
                    .frame(height: 30)
                    .background(Color.white.opacity(0.2))
                
                VStack(spacing: 4) {
                    Text("\(group.memberLimit)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Limit")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
    
    private var dangerZone: some View {
        VStack(spacing: 12) {
            Text("Danger Zone")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.red)
            
            Button(action: { showingLeaveConfirmation = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "door.right.hand.open")
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("Leave Group")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red.opacity(0.1))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}

struct InviteCodeView: View {
    let group: Group
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Text("Invite Code")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 16) {
                        Text(group.inviteCode)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#7289da"))
                            .padding(24)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                        
                        Text("Share this code with friends to invite them")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: {
                        UIPasteboard.general.string = group.inviteCode
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 16))
                            
                            Text("Copy Code")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#7289da"))
                        .cornerRadius(16)
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
        }
    }
}

struct GroupMembersView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    let group: Group
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(dataManager.groupMembers) { member in
                            MemberRow(member: member)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Members")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
        }
        .onAppear {
            dataManager.loadGroupMembers(group.id)
        }
    }
}

struct MemberRow: View {
    let member: GroupMember
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(Color(hex: "#7289da").opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(member.username.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#7289da"))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(member.username)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(member.role.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Role Badge
            Text(member.role.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(roleColor(for: member.role))
                .cornerRadius(8)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func roleColor(for role: GroupRole) -> Color {
        switch role {
        case .owner:
            return Color.orange
        case .admin:
            return Color(hex: "#7289da")
        case .member:
            return Color.gray
        }
    }
} 