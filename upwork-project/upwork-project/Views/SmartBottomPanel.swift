import SwiftUI

struct SmartBottomPanel: View {
    @EnvironmentObject var dataManager: DataManager
    let currentLocationName: String
    let currentZoomLevel: Double
    let onGroupsPressed: () -> Void
    let onCreateGroupPressed: () -> Void
    let onJoinGroupPressed: () -> Void
    
    @State private var isExpanded = true
    @State private var dragOffset: CGFloat = 0
    
    // Zoom thresholds for panel visibility
    private let expandedZoomThreshold: Double = 14.0
    private let hiddenZoomThreshold: Double = 13.0
    
    // Check if user has any groups
    private var hasGroups: Bool {
        !dataManager.userGroups.isEmpty
    }
    
    // Get the primary group (first one or selected one)
    private var primaryGroup: Group? {
        if let selectedGroup = dataManager.selectedGroup {
            return selectedGroup
        }
        return dataManager.userGroups.first
    }
    
    // Determine if panel should be expanded based on zoom level
    private var shouldExpand: Bool {
        currentZoomLevel >= expandedZoomThreshold
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Pull indicator when collapsed
            if !isExpanded {
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        isExpanded = true
                    }
                }) {
                    VStack(spacing: 4) {
                        // Pull up indicator
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.6))
                            .frame(width: 40, height: 4)
                        
                        // Chevron up icon
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.8), Color.black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            
            // Main panel content
            if isExpanded {
                if hasGroups {
                    // Show group preview when user has groups
                    groupPreviewContent
                } else {
                    // Show group options when user has no groups
                    groupOptionsContent
                }
            }
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow downward dragging when expanded
                    if isExpanded && value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        if value.translation.height > 50 && isExpanded {
                            // Hide panel if dragged down significantly
                            isExpanded = false
                        }
                        dragOffset = 0
                    }
                }
        )
        .onChange(of: currentZoomLevel) { _, newZoomLevel in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                if newZoomLevel >= expandedZoomThreshold && !isExpanded {
                    // Show panel when zooming in to street level
                    isExpanded = true
                } else if newZoomLevel <= hiddenZoomThreshold && isExpanded {
                    // Hide panel when zooming out to state/country level
                    isExpanded = false
                }
            }
        }
        .onAppear {
            // Set initial state based on zoom level
            isExpanded = shouldExpand
        }
    }
    
    // MARK: - Group Options Content (when user has no groups)
    @ViewBuilder
    private var groupOptionsContent: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentLocationName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Join explorers in your area")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Create Group Button
                Button(action: onCreateGroupPressed) {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(Color(hex: "7289da"))
                        
                        Text("Create\nGroup")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 60, height: 50)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Join Group Button  
                Button(action: onJoinGroupPressed) {
                    VStack(spacing: 4) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(Color(hex: "7289da"))
                        
                        Text("Invite\nCode")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 60, height: 50)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Group Preview Content (when user has groups)
    @ViewBuilder
    private var groupPreviewContent: some View {
        Button(action: onGroupsPressed) {
            HStack(spacing: 16) {
                // Group Avatar
                if let group = primaryGroup {
                    Circle()
                        .fill(Color(hex: group.avatarColor))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(group.emoji)
                                .font(.system(size: 24))
                        )
                        .shadow(color: Color(hex: group.avatarColor).opacity(0.3), radius: 4, x: 0, y: 2)
                }
                
                // Group Info
                VStack(alignment: .leading, spacing: 4) {
                    if let group = primaryGroup {
                        Text(group.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            // Member count
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Text("\(group.memberCount)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            
                            // Active members
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("\(group.activeMembers) active")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        }
                    } else {
                        Text(currentLocationName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Tap to view groups")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Chevron indicating it's tappable
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.black)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            
            SmartBottomPanel(
                currentLocationName: "Sofia, Bulgaria",
                currentZoomLevel: 15.0,
                onGroupsPressed: {},
                onCreateGroupPressed: {},
                onJoinGroupPressed: {}
            )
            .environmentObject({
                let dm = DataManager()
                // Simulate no groups for preview
                dm.userGroups = []
                return dm
            }())
        }
    }
} 